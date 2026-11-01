import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'addon_service.dart';

abstract interface class FirebaseIdTokenProvider {
  Future<String?> getIdToken();
}

class FirebaseAuthIdTokenProvider implements FirebaseIdTokenProvider {
  const FirebaseAuthIdTokenProvider(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    return user?.getIdToken();
  }
}

class _UnavailableTokenProvider implements FirebaseIdTokenProvider {
  const _UnavailableTokenProvider();

  @override
  Future<String?> getIdToken() async => null;
}

/// Authenticated, opt-in bridge from the Add-ons pairing dialog to the private
/// Collector backend. A backend URL is supplied only through a build-time
/// define, keeping private infrastructure out of Flutter source and releases.
class CollectorClaimService {
  CollectorClaimService({
    required String backendUrl,
    FirebaseIdTokenProvider? tokenProvider,
    http.Client? client,
  })  : _baseUri = _parseBaseUri(backendUrl),
        _tokenProvider =
            tokenProvider ?? FirebaseAuthIdTokenProvider(FirebaseAuth.instance),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  factory CollectorClaimService.fromEnvironment({
    FirebaseIdTokenProvider? tokenProvider,
    http.Client? client,
  }) {
    const backendUrl = String.fromEnvironment(
      'FJELLFISK_COLLECTOR_BACKEND_URL',
    );
    return CollectorClaimService(
      backendUrl: backendUrl,
      // Do not access FirebaseAuth for the normal mock-only UI path. This
      // keeps both local tests and existing Add-ons behavior independent from
      // Firebase initialization until an operator explicitly configures a URL.
      tokenProvider: tokenProvider ??
          (backendUrl.trim().isEmpty
              ? const _UnavailableTokenProvider()
              : FirebaseAuthIdTokenProvider(FirebaseAuth.instance)),
      client: client,
    );
  }

  final Uri? _baseUri;
  final FirebaseIdTokenProvider _tokenProvider;
  final http.Client _client;
  final bool _ownsClient;

  bool get isConfigured => _baseUri != null;

  Future<ClaimCodeResult> claimCollector({
    required String facilityId,
    required String pairingCode,
  }) async {
    final baseUri = _baseUri;
    if (baseUri == null || facilityId.trim().isEmpty) {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    }

    String? token;
    try {
      token = await _tokenProvider.getIdToken();
    } catch (_) {
      return const ClaimCodeResult(ClaimCodeResultType.unauthorized);
    }
    if (token == null || token.isEmpty) {
      return const ClaimCodeResult(ClaimCodeResultType.unauthorized);
    }

    try {
      final response = await _client
          .post(
            baseUri.resolve('/admin/v1/collectors/claim'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'siteId': facilityId,
              'pairingCode': pairingCode,
            }),
          )
          .timeout(const Duration(seconds: 12));
      return _resultFor(response);
    } on TimeoutException {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    } on http.ClientException {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  static Uri? _parseBaseUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  static ClaimCodeResult _resultFor(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return const ClaimCodeResult(ClaimCodeResultType.success);
    }

    final code = _errorCode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const ClaimCodeResult(ClaimCodeResultType.unauthorized);
    }
    return switch (code) {
      'PAIRING_CODE_EXPIRED' =>
        const ClaimCodeResult(ClaimCodeResultType.expired),
      'PAIRING_CODE_USED' ||
      'PAIRING_CODE_SUPERSEDED' ||
      'COLLECTOR_ALREADY_PAIRED' =>
        const ClaimCodeResult(ClaimCodeResultType.alreadyUsed),
      'PAIRING_CODE_INVALID' =>
        const ClaimCodeResult(ClaimCodeResultType.invalid),
      _ => const ClaimCodeResult(ClaimCodeResultType.unavailable),
    };
  }

  static String? _errorCode(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) return null;
      final error = value['error'];
      if (error is! Map<String, dynamic>) return null;
      final code = error['code'];
      return code is String ? code : null;
    } on FormatException {
      return null;
    }
  }
}
