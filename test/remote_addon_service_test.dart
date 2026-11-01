import 'dart:async';
import 'dart:convert';

import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';
import 'package:fjellfisk/services/remote_addon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements FirebaseIdTokenProvider {
  const _Token([this.value = 'test-token']);
  final String? value;
  @override
  Future<String?> getIdToken() async => value;
}

void main() {
  Map<String, Object?> device({String state = 'PAIRED'}) => {
        'collectorId': 'real-device',
        'state': state,
        'pairedAt': '2026-11-01T19:24:27Z',
        'lastSeenAt': '2026-11-01T19:24:37Z',
        'collectorVersion': null,
      };

  CollectorClaimService api(
    Future<http.Response> Function(http.Request) respond, {
    FirebaseIdTokenProvider token = const _Token(),
  }) =>
      CollectorClaimService(
        backendUrl: 'https://collector.example/collector/v1',
        tokenProvider: token,
        client: MockClient(respond),
      );

  test('list is authenticated, facility-scoped and uses actual PAIRED state',
      () async {
    final service = RemoteAddOnService(
      facilityId: 'selected facility',
      api: api((request) async {
        expect(request.method, 'GET');
        expect(request.url.pathSegments,
            ['admin', 'v1', 'sites', 'selected facility', 'collectors']);
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(jsonEncode([device()]), 200);
      }),
    );
    await service.refresh();
    expect(service.addOns.single.isConnected, isTrue);
    expect(service.addOns.single.id, 'real-device');
    expect(service.addOns.single.version, isNull);
    expect(service.addOns.single.sensorCount, isNull);
    expect(service.addOns.single.connectedAt,
        DateTime.utc(2026, 11, 1, 19, 24, 27));
    expect(service.sensorsForCollector('real-device'), isEmpty);
    expect(service.mappingsForCollector('real-device'), isEmpty);
    service.dispose();
  });

  test('claim refreshes real status and a recreated service restores pairing',
      () async {
    var paired = false;
    final backend = api((request) async {
      if (request.method == 'POST') {
        expect(jsonDecode(request.body), {
          'siteId': 'facility-1',
          'pairingCode': 'FJ-REAL-CODE',
        });
        paired = true;
        return http.Response('{}', 200);
      }
      return http.Response(jsonEncode(paired ? [device()] : []), 200);
    });
    final service = RemoteAddOnService(api: backend, facilityId: 'facility-1');
    await service.refresh();
    expect(service.addOns.single.isConnected, isFalse);
    expect((await service.claimCollector('FJ-REAL-CODE')).isSuccess, isTrue);
    expect(service.addOns.single.isConnected, isTrue);
    service.dispose();
    final reopened = RemoteAddOnService(api: backend, facilityId: 'facility-1');
    await reopened.refresh();
    expect(reopened.addOns.single.isConnected, isTrue);
    reopened.dispose();
  });

  test('claim waits for stale in-flight list before fetching paired status',
      () async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((request) async {
        if (request.method == 'POST') return http.Response('{}', 200);
        requests++;
        if (requests == 1) return pending.future;
        return http.Response(jsonEncode([device()]), 200);
      }),
    );
    final refresh = service.refresh();
    await Future<void>.delayed(Duration.zero);
    final claim = service.claimCollector('FJ-REAL-CODE');
    pending.complete(http.Response('[]', 200));
    await refresh;
    await claim;
    expect(requests, 2);
    expect(service.addOns.single.isConnected, isTrue);
    service.dispose();
  });

  for (final state in ['UNPAIRED', 'REVOKED']) {
    test('$state does not enable setup', () async {
      final service = RemoteAddOnService(
        facilityId: 'facility-1',
        api: api((_) async =>
            http.Response(jsonEncode([device(state: state)]), 200)),
      );
      await service.refresh();
      expect(service.addOns.single.isConnected, isFalse);
      service.dispose();
    });
  }

  test(
      'missing login never sends a request and reports safe authorization error',
      () async {
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((_) async => fail('No request without a token'),
          token: const _Token(null)),
    );
    await service.refresh();
    expect(service.loadError, ClaimCodeResultType.unauthorized);
    expect(service.addOns.single.isConnected, isFalse);
    service.dispose();
  });

  test('authorization loss clears previous paired management state', () async {
    var allowed = true;
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((_) async => allowed
          ? http.Response(jsonEncode([device()]), 200)
          : http.Response('{"error":{"code":"FORBIDDEN"}}', 403)),
    );
    await service.refresh();
    allowed = false;
    await service.refresh();
    expect(service.loadError, ClaimCodeResultType.unauthorized);
    expect(service.addOns.single.isConnected, isFalse);
    service.dispose();
  });

  for (final body in [
    'null',
    '{}',
    '[{}]',
    '[{"collectorId":"a","state":"UNKNOWN"}]',
    'not json'
  ]) {
    test('malformed collector payload is not interpreted as connected: $body',
        () async {
      final service = RemoteAddOnService(
        facilityId: 'facility-1',
        api: api((_) async => http.Response(body, 200)),
      );
      await service.refresh();
      expect(service.loadError, ClaimCodeResultType.unavailable);
      expect(service.addOns.single.isConnected, isFalse);
      expect(service.sensorsForCollector('fjellfisk-collector'), isEmpty);
      service.dispose();
    });
  }

  test('disconnect revokes actual device rather than mutating mock state',
      () async {
    var revoked = false;
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/admin/v1/collectors/real-device/revoke');
          expect(jsonDecode(request.body), {'siteId': 'facility-1'});
          revoked = true;
          return http.Response('{}', 200);
        }
        return http.Response(
            jsonEncode([device(state: revoked ? 'REVOKED' : 'PAIRED')]), 200);
      }),
    );
    await service.refresh();
    await service.disconnect('real-device');
    expect(revoked, isTrue);
    expect(service.addOns.single.status, AddOnStatus.revoked);
    service.dispose();
  });

  test('production mappings cannot silently save to local mock storage',
      () async {
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((_) async => http.Response('[]', 200)),
    );
    await expectLater(service.saveCollectorMappings('real-device', []),
        throwsA(isA<CollectorBackendException>()));
    service.dispose();
  });

  test('disposing during a request never notifies a disposed service',
      () async {
    final pending = Completer<http.Response>();
    final service = RemoteAddOnService(
      facilityId: 'facility-1',
      api: api((_) => pending.future),
    );
    final refresh = service.refresh();
    service.dispose();
    pending.complete(http.Response(jsonEncode([device()]), 200));
    await refresh;
  });
}
