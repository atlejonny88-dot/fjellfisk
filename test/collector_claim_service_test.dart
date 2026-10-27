import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';

class _TokenProvider implements FirebaseIdTokenProvider {
  const _TokenProvider(this.token);

  final String? token;

  @override
  Future<String?> getIdToken() async => token;
}

void main() {
  test('claim sends Firebase ID token, selected facility, and pairing code',
      () async {
    late http.Request request;
    final service = CollectorClaimService(
      backendUrl: 'https://pelasyn.taild05c7.ts.net',
      tokenProvider: const _TokenProvider('firebase-id-token'),
      client: MockClient((received) async {
        request = received;
        return http.Response(
          jsonEncode({'collectorId': 'collector-1', 'state': 'PAIRED'}),
          200,
        );
      }),
    );

    final result = await service.claimCollector(
      facilityId: 'default_facility',
      pairingCode: 'FJ-1234-ABCD-5678',
    );

    expect(result.type, ClaimCodeResultType.success);
    expect(request.url.path, '/admin/v1/collectors/claim');
    expect(request.headers['authorization'], 'Bearer firebase-id-token');
    expect(jsonDecode(request.body), {
      'siteId': 'default_facility',
      'pairingCode': 'FJ-1234-ABCD-5678',
    });
  });

  test(
      'claim maps authorization and pairing errors without exposing server details',
      () async {
    Future<ClaimCodeResultType> resultFor(int status, String code) async {
      final service = CollectorClaimService(
        backendUrl: 'https://pelasyn.taild05c7.ts.net',
        tokenProvider: const _TokenProvider('firebase-id-token'),
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': {'code': code}
              }),
              status,
            )),
      );
      return (await service.claimCollector(
        facilityId: 'default_facility',
        pairingCode: 'FJ-1234-ABCD-5678',
      ))
          .type;
    }

    expect(await resultFor(403, 'FORBIDDEN'), ClaimCodeResultType.unauthorized);
    expect(
      await resultFor(409, 'PAIRING_CODE_EXPIRED'),
      ClaimCodeResultType.expired,
    );
    expect(
      await resultFor(409, 'PAIRING_CODE_SUPERSEDED'),
      ClaimCodeResultType.alreadyUsed,
    );
  });

  test('claim does not call the backend without an authenticated Firebase user',
      () async {
    final service = CollectorClaimService(
      backendUrl: 'https://pelasyn.taild05c7.ts.net',
      tokenProvider: const _TokenProvider(null),
      client: MockClient((_) async {
        fail('The backend must not be called without a Firebase ID token.');
      }),
    );

    final result = await service.claimCollector(
      facilityId: 'default_facility',
      pairingCode: 'FJ-1234-ABCD-5678',
    );

    expect(result.type, ClaimCodeResultType.unauthorized);
  });
}
