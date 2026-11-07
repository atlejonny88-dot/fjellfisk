import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/vacon_control.dart';
import 'collector_claim_service.dart';
import 'vacon_control_service.dart';

/// HTTPS client for the facility-scoped VACON monitoring API.
///
/// It deliberately contains no socket, VPN, Modbus or write-command code.
/// Physical telemetry will be accepted only from a future, separately
/// authenticated facility Edge service.
class VaconApiControlService extends VaconControlService {
  VaconApiControlService({
    required String backendUrl,
    FirebaseIdTokenProvider? tokenProvider,
    http.Client? client,
  })  : _baseUri = _parseBaseUri(backendUrl),
        _tokenProvider = tokenProvider ?? const _UnavailableTokenProvider(),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  factory VaconApiControlService.fromEnvironment({
    FirebaseIdTokenProvider? tokenProvider,
    http.Client? client,
  }) {
    const backendUrl =
        String.fromEnvironment('FJELLFISK_COLLECTOR_BACKEND_URL');
    return VaconApiControlService(
      backendUrl: backendUrl,
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
  final Map<String, List<VaconDevice>> _devices = {};
  final Map<String, bool> _entitlements = {};
  final Map<String, String?> _errors = {};

  bool get isConfigured => _baseUri != null;

  @override
  bool get isSimulator => false;

  @override
  String? errorForFacility(String facilityId) => _errors[facilityId];

  @override
  Future<void> refreshFacility(String facilityId) async {
    try {
      final response =
          await _send('GET', '/admin/v1/sites/$facilityId/vacon-devices');
      final body = _jsonObject(response.body);
      final rows = body['devices'];
      if (rows is! List) throw const VaconApiException('invalid-response');
      _devices[facilityId] = rows
          .whereType<Map>()
          .map((row) => _deviceFromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      _entitlements[facilityId] = true;
      _errors[facilityId] = null;
    } on VaconApiException catch (error) {
      if (error.code == 'VACON_ENTITLEMENT_REQUIRED') {
        _entitlements[facilityId] = false;
      }
      _errors[facilityId] = error.code;
    } on TimeoutException {
      _errors[facilityId] = 'unavailable';
    } on http.ClientException {
      _errors[facilityId] = 'unavailable';
    }
    notifyListeners();
  }

  @override
  List<VaconSite> sitesForFacility(String facilityId) {
    final seen = <String>{};
    return devicesForFacility(facilityId)
        .where((device) => seen.add(device.siteId))
        .map(
          (device) => VaconSite(
            id: device.siteId,
            facilityId: facilityId,
            name: device.edgeServerId.isEmpty
                ? 'Ikke tildelt Edge'
                : device.edgeServerId,
            gatewayLabel: device.gateway,
            connection: device.connection,
          ),
        )
        .toList(growable: false);
  }

  @override
  List<VaconDevice> devicesForFacility(String facilityId) =>
      List.unmodifiable(_devices[facilityId] ?? const []);

  @override
  VaconEntitlement entitlementForFacility(String facilityId) =>
      VaconEntitlement(
        facilityId: facilityId,
        enabled: _entitlements[facilityId] ?? false,
      );

  @override
  List<VaconCommandResult> resultsForFacility(String facilityId) => const [];

  @override
  Future<VaconDevice> saveDevice({
    required String facilityId,
    String? deviceId,
    required VaconDeviceConfiguration configuration,
  }) async {
    final payload = configuration.toJson();
    final response = deviceId == null
        ? await _send(
            'POST',
            '/admin/v1/sites/$facilityId/vacon-devices',
            body: payload,
          )
        : await _send(
            'PATCH',
            '/admin/v1/vacon-devices/$deviceId',
            body: {...payload, 'siteId': facilityId},
          );
    final device = _deviceFromJson(_jsonObject(response.body));
    final items = [...(_devices[facilityId] ?? const <VaconDevice>[])];
    final index = items.indexWhere((item) => item.id == device.id);
    if (index < 0) {
      items.add(device);
    } else {
      items[index] = device;
    }
    _devices[facilityId] = items;
    _entitlements[facilityId] = true;
    _errors[facilityId] = null;
    notifyListeners();
    return device;
  }

  @override
  Future<VaconConnectionTestResult> testConnection({
    required String facilityId,
    required String deviceId,
  }) async {
    final response = await _send(
      'POST',
      '/admin/v1/vacon-devices/$deviceId/test-connection',
      body: {'siteId': facilityId},
    );
    final body = _jsonObject(response.body);
    return VaconConnectionTestResult(
      deviceId: _string(body['deviceId']),
      state: _string(body['state']),
      reason: _string(body['reason']),
      testedAt: _date(body['testedAt']),
    );
  }

  @override
  Future<List<VaconTelemetry>> telemetryHistory({
    required String facilityId,
    required String deviceId,
  }) async {
    final response = await _send(
      'GET',
      '/admin/v1/vacon-devices/$deviceId/history?siteId=$facilityId',
    );
    final readings = _jsonObject(response.body)['readings'];
    if (readings is! List) throw const VaconApiException('invalid-response');
    return readings
        .whereType<Map>()
        .map((row) => _telemetryFromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<VaconCommandResult> requestSimulation({
    required VaconAccessContext access,
    required String deviceId,
    required VaconCommandType command,
    double? frequencyHz,
    String? requestId,
  }) async =>
      VaconCommandResult.rejected(
        requestId: requestId ?? 'physical-command-disabled',
        reason: 'physical-control-disabled',
      );

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object>? body,
  }) async {
    final baseUri = _baseUri;
    if (baseUri == null) throw const VaconApiException('unavailable');
    final token = await _tokenProvider.getIdToken();
    if (token == null || token.isEmpty) {
      throw const VaconApiException('UNAUTHENTICATED');
    }
    final uri = baseUri.resolve(path);
    final headers = {
      'authorization': 'Bearer $token',
      if (body != null) 'content-type': 'application/json; charset=utf-8',
    };
    final request = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
      'PATCH' => _client.patch(uri, headers: headers, body: jsonEncode(body)),
      _ => throw ArgumentError.value(method, 'method'),
    };
    final response = await request.timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VaconApiException(_errorCode(response.body) ?? 'unavailable');
    }
    return response;
  }

  static Uri? _parseBaseUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  static Map<String, dynamic> _jsonObject(String body) {
    final value = jsonDecode(body);
    if (value is! Map) throw const VaconApiException('invalid-response');
    return Map<String, dynamic>.from(value);
  }

  static String _string(Object? value) => value is String ? value : '';

  static bool _bool(Object? value) => value is bool && value;

  static int _int(Object? value) =>
      value is int ? value : (value as num?)?.toInt() ?? 0;

  static double? _doubleOrNull(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime _date(Object? value) => value is String
      ? DateTime.tryParse(value)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
      : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static String? _nullableString(Object? value) =>
      value is String ? value : null;

  static VaconConnectionState _connection(Object? value) => switch (value) {
        'ONLINE' => VaconConnectionState.online,
        'STALE' => VaconConnectionState.stale,
        'DISABLED' => VaconConnectionState.disabled,
        _ => VaconConnectionState.offline,
      };

  static VaconTelemetry _telemetryFromJson(Map<String, dynamic> json) =>
      VaconTelemetry(
        measuredAt: _date(json['measuredAt']),
        quality: _string(json['quality']).toLowerCase(),
        running: _bool(json['running']),
        actualHz: _doubleOrNull(json['actualFrequencyHz']),
        currentA: _doubleOrNull(json['motorCurrentA']),
        statusText: _bool(json['fault'])
            ? 'Fault'
            : _bool(json['running'])
                ? 'Running'
                : 'Stopped',
        faultCode: _nullableString(json['activeFaultCode']),
        motorSpeedRpm: _doubleOrNull(json['motorSpeedRpm']),
        motorSpeedVerified: _bool(json['motorSpeedVerified']),
        motorCurrentRaw: json['motorCurrentRaw'] is num
            ? (json['motorCurrentRaw'] as num).toInt()
            : null,
        motorCurrentVerified: _bool(json['motorCurrentVerified']),
        ready: json['ready'] as bool?,
        fault: json['fault'] as bool?,
        alarm: json['alarm'] as bool?,
        atReference: json['atReference'] as bool?,
      );

  static VaconDevice _deviceFromJson(Map<String, dynamic> json) {
    final telemetryJson = json['telemetry'];
    final telemetry = telemetryJson is Map
        ? _telemetryFromJson(Map<String, dynamic>.from(telemetryJson))
        : VaconTelemetry(
            measuredAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            quality: 'unavailable',
            running: false,
            statusText: 'No telemetry',
          );
    final manufacturer = _string(json['manufacturer']);
    final model = _string(json['model']);
    return VaconDevice(
      id: _string(json['deviceId']),
      facilityId: _string(json['facilityId']),
      siteId: _string(json['edgeServerId']),
      name: _string(json['displayName']),
      modelProfile: VaconModelProfile(
        id: 'live-${_string(json['deviceId'])}',
        name: '$manufacturer $model'.trim(),
        isDocumented: false,
        supportsRemoteControl: false,
      ),
      endpointLabel: _string(json['ipAddress']),
      port: _int(json['modbusTcpPort']),
      unitId: _int(json['modbusUnitId']),
      minHz: _doubleOrNull(json['minFrequencyHz']) ?? 0,
      maxHz: _doubleOrNull(json['maxFrequencyHz']) ?? 0,
      pollingInterval: const Duration(seconds: 5),
      connection: _connection(json['connection']),
      controlMode: VaconControlMode.disabled,
      localInterlockSatisfied: false,
      telemetry: telemetry,
      manufacturer: manufacturer,
      subnetMask: _string(json['subnetMask']),
      gateway: _string(json['gateway']),
      dns: _string(json['dns']),
      edgeServerId: _string(json['edgeServerId']),
      monitoringEnabled: _bool(json['monitoringEnabled']),
    );
  }

  static String? _errorCode(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map || value['error'] is! Map) return null;
      final code = (value['error'] as Map)['code'];
      return code is String ? code : null;
    } on FormatException {
      return null;
    }
  }
}

class VaconApiException implements Exception {
  const VaconApiException(this.code);

  final String code;
}

class _UnavailableTokenProvider implements FirebaseIdTokenProvider {
  const _UnavailableTokenProvider();

  @override
  Future<String?> getIdToken() async => null;
}
