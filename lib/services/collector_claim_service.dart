import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/addon.dart';
import 'addon_service.dart';

class CollectorBackendException implements Exception {
  const CollectorBackendException(this.type);

  final ClaimCodeResultType type;
}

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

  Future<List<AddOn>> fetchCollectors({required String facilityId}) async {
    final baseUri = _baseUri;
    if (baseUri == null || facilityId.trim().isEmpty) {
      throw const CollectorBackendException(ClaimCodeResultType.unavailable);
    }
    final headers = await _authenticatedHeaders();
    try {
      final response = await _client
          .get(
            baseUri.resolve(
              '/admin/v1/sites/${Uri.encodeComponent(facilityId)}/collectors',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));
      final result = _resultFor(response);
      if (!result.isSuccess) throw CollectorBackendException(result.type);
      final data = jsonDecode(response.body);
      if (data is! List) throw const FormatException();
      return data.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        final id = item['collectorId'];
        final state = switch (item['state']) {
          'PAIRED' => AddOnStatus.connected,
          'REVOKED' => AddOnStatus.revoked,
          'UNPAIRED' => AddOnStatus.notConnected,
          _ => throw const FormatException(),
        };
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException();
        }
        DateTime? date(String key) =>
            item[key] is String ? DateTime.tryParse(item[key] as String) : null;
        return AddOn(
          id: id,
          type: AddOnType.collector,
          name: 'Fjellfisk Collector',
          description: '',
          status: state,
          connectedDeviceId: state == AddOnStatus.connected ? id : null,
          connectedAt: date('pairedAt'),
          lastSeenAt: date('lastSeenAt'),
          version: item['collectorVersion'] is String
              ? item['collectorVersion'] as String
              : null,
        );
      }).toList(growable: false);
    } on FormatException {
      throw const CollectorBackendException(ClaimCodeResultType.unavailable);
    } on TimeoutException {
      throw const CollectorBackendException(ClaimCodeResultType.unavailable);
    } on http.ClientException {
      throw const CollectorBackendException(ClaimCodeResultType.unavailable);
    }
  }

  Future<Map<String, String>> _authenticatedHeaders() async {
    String? token;
    try {
      token = await _tokenProvider
          .getIdToken()
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const CollectorBackendException(ClaimCodeResultType.unauthorized);
    }
    if (token == null || token.isEmpty) {
      throw const CollectorBackendException(ClaimCodeResultType.unauthorized);
    }
    return {
      'authorization': 'Bearer $token',
      'content-type': 'application/json; charset=utf-8',
    };
  }

  Future<ClaimCodeResult> revokeCollector({
    required String facilityId,
    required String collectorId,
  }) async {
    final baseUri = _baseUri;
    if (baseUri == null || facilityId.trim().isEmpty || collectorId.isEmpty) {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    }
    try {
      final headers = await _authenticatedHeaders();
      final response = await _client
          .post(
            baseUri.resolve(
              '/admin/v1/collectors/${Uri.encodeComponent(collectorId)}/revoke',
            ),
            headers: headers,
            body: jsonEncode({'siteId': facilityId}),
          )
          .timeout(const Duration(seconds: 12));
      return _resultFor(response);
    } on CollectorBackendException catch (error) {
      return ClaimCodeResult(error.type);
    } on TimeoutException {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    } on http.ClientException {
      return const ClaimCodeResult(ClaimCodeResultType.unavailable);
    }
  }

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
