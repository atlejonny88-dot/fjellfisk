import 'dart:async';

import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);

  MockAddOnService service({
    List<AddOn>? initialAddOns,
    DateTime? expiresAt,
    Future<void> Function()? claimDelay,
  }) {
    return MockAddOnService(
      initialAddOns: initialAddOns,
      clock: () => now,
      claimCodeExpiresAt: expiresAt ?? now.add(const Duration(minutes: 15)),
      claimDelay: claimDelay ?? () async {},
    );
  }

  test('claim accepts normalized valid code and connects collector', () async {
    final mock = service();

    final result = await mock.claimCollector(' fj-8k4p 2xq7 ');

    expect(result.type, ClaimCodeResultType.success);
    final collector = mock.addOns.single;
    expect(collector.status, AddOnStatus.connected);
    expect(collector.connectedDeviceId, 'mock-collector-vigo-pc');
    expect(collector.readerType, 'OxyGuard / VIGO');
    expect(collector.sensorCount, 4);
    expect(collector.lastSeenAt, now);
  });

  test('a saved mapping exposes the matching sensor only while connected',
      () async {
    final mock = service();
    const mapping = CollectorSensorMapping(
      collectorId: 'fjellfisk-collector',
      sensorId: 'pacific-01',
      facilityId: MockCollectorSetupCatalog.facilityId,
      sectionId: 'mock-hovedbygg',
      sectionName: 'Hovedbygg',
      tankId: 'mock-k1',
      tankName: 'K1',
    );

    await mock.saveCollectorMappings('fjellfisk-collector', [mapping]);
    expect(
      mock.sensorForTank(
        facilityId: 'facility-1',
        sectionId: 'section-1',
        sectionName: 'Hovedbygg',
        tankId: 'tank-1',
        tankName: 'K1',
      ),
      isNull,
    );

    await mock.claimCollector(MockAddOnService.mockClaimCode);
    final sensor = mock.sensorForTank(
      facilityId: 'facility-1',
      sectionId: 'section-1',
      sectionName: 'Hovedbygg',
      tankId: 'tank-1',
      tankName: 'K1',
    );

    expect(sensor?.name, 'Pacific 01');
    expect(sensor?.temperatureC, 8.60);
    expect(sensor?.oxygenMgL, 13.10);
    expect(sensor?.oxygenSaturationPct, 113);
  });

  test('claim rejects invalid, expired and already-used codes', () async {
    final mock = service();
    expect(
      (await mock.claimCollector('FJ-NOT-A-CODE')).type,
      ClaimCodeResultType.invalid,
    );

    final expired =
        service(expiresAt: now.subtract(const Duration(seconds: 1)));
    expect(
      (await expired.claimCollector(MockAddOnService.mockClaimCode)).type,
      ClaimCodeResultType.expired,
    );

    expect(
      (await mock.claimCollector(MockAddOnService.mockClaimCode)).type,
      ClaimCodeResultType.success,
    );
    expect(
      (await mock.claimCollector(MockAddOnService.mockClaimCode)).type,
      ClaimCodeResultType.alreadyUsed,
    );
  });

  test('claim prevents double submit while a request is pending', () async {
    final gate = Completer<void>();
    final mock = service(claimDelay: () => gate.future);

    final first = mock.claimCollector(MockAddOnService.mockClaimCode);
    final second = await mock.claimCollector(MockAddOnService.mockClaimCode);
    expect(second.type, ClaimCodeResultType.busy);

    gate.complete();
    expect((await first).type, ClaimCodeResultType.success);
  });

  test('disconnect revokes a collector without removing its add-on record',
      () async {
    final mock = service();
    await mock.claimCollector(MockAddOnService.mockClaimCode);

    await mock.disconnect('fjellfisk-collector');

    expect(mock.addOns, hasLength(1));
    expect(mock.addOns.single.status, AddOnStatus.revoked);
    expect(mock.addOns.single.connectedDeviceId, isNull);
  });

  test('model supports multiple collectors and non-connected states', () {
    final mock = service(initialAddOns: const [
      AddOn(
        id: 'main',
        type: AddOnType.collector,
        name: 'Main collector',
        description: 'Main building',
        status: AddOnStatus.offline,
      ),
      AddOn(
        id: 'hatchery',
        type: AddOnType.collector,
        name: 'Hatchery collector',
        description: 'Hatchery',
        status: AddOnStatus.revoked,
      ),
      AddOn(
        id: 'camera',
        type: AddOnType.camera,
        name: 'Camera gateway',
        description: 'Future integration',
        status: AddOnStatus.notConnected,
      ),
    ]);

    expect(mock.addOns.where((item) => item.type == AddOnType.collector),
        hasLength(2));
    expect(mock.addOns[0].status, AddOnStatus.offline);
    expect(mock.addOns[1].status, AddOnStatus.revoked);
  });
}
