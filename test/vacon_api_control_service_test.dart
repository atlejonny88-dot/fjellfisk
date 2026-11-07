import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fjellfisk/models/vacon_control.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';
import 'package:fjellfisk/services/vacon_api_control_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenProvider implements FirebaseIdTokenProvider {
  const _TokenProvider(this.token);

  final String? token;

  @override
  Future<String?> getIdToken() async => token;
}

void main() {
  test('loads a facility-scoped VACON device through authenticated HTTPS',
      () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'devices': [
            {
              'deviceId': 'vacon-a',
              'facilityId': 'facility-a',
              'displayName': 'Pumpe 1',
              'manufacturer': 'Danfoss',
              'model': 'VACON 100 FLOW',
              'ipAddress': '192.168.30.50',
              'subnetMask': '255.255.255.0',
              'gateway': '192.168.30.1',
              'dns': '192.168.30.1',
              'modbusTcpPort': 502,
              'modbusUnitId': 255,
              'minFrequencyHz': 0,
              'maxFrequencyHz': 50,
              'edgeServerId': 'edge-1',
              'monitoringEnabled': true,
              'connection': 'ONLINE',
              'telemetry': {
                'measuredAt': '2026-11-07T10:00:00Z',
                'receivedAt': '2026-11-07T10:00:01Z',
                'quality': 'LIVE',
                'actualFrequencyHz': 13,
                'motorSpeedRpm': 1300,
                'motorSpeedVerified': false,
                'motorCurrentRaw': 17,
                'motorCurrentA': null,
                'motorCurrentVerified': false,
                'ready': true,
                'running': true,
                'fault': false,
                'alarm': false,
                'atReference': true,
                'activeFaultCode': null,
              },
            },
          ],
        }),
        200,
      );
    });
    final service = VaconApiControlService(
      backendUrl: 'https://api.example.test',
      tokenProvider: const _TokenProvider('verified-token'),
      client: client,
    );

    await service.refreshFacility('facility-a');

    expect(request.url.path, '/admin/v1/sites/facility-a/vacon-devices');
    expect(request.headers['authorization'], 'Bearer verified-token');
    expect(service.isSimulator, isFalse);
    expect(service.entitlementForFacility('facility-a').enabled, isTrue);
    final device = service.devicesForFacility('facility-a').single;
    expect(device.connection, VaconConnectionState.online);
    expect(device.telemetry.actualHz, 13);
    expect(device.telemetry.motorSpeedVerified, isFalse);
    expect(device.canSimulateControlAt(DateTime.now()), isFalse);
  });

  test('does not use a non-HTTPS or missing backend configuration', () async {
    final service = VaconApiControlService(
      backendUrl: 'http://localhost:8080',
      tokenProvider: const _TokenProvider('verified-token'),
      client: MockClient((_) => throw StateError('must not send request')),
    );

    await service.refreshFacility('facility-a');

    expect(service.devicesForFacility('facility-a'), isEmpty);
    expect(service.errorForFacility('facility-a'), 'unavailable');
  });
}
