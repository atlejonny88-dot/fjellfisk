import 'package:fjellfisk/models/vacon_control.dart';
import 'package:fjellfisk/services/vacon_control_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 10);

  MockVaconControlService service({
    VaconDevice? device,
    bool entitled = true,
  }) =>
      MockVaconControlService(
        clock: () => now,
        devices: [device ?? _device(now)],
        entitlements: [
          VaconEntitlement(facilityId: 'facility-a', enabled: entitled),
        ],
      );

  const access = VaconAccessContext(
    facilityId: 'facility-a',
    canRead: true,
    canControl: true,
    hasEntitlement: true,
  );

  test('simulation verifies readback only for an entitled controller',
      () async {
    final control = service();

    final result = await control.requestSimulation(
      access: access,
      deviceId: 'device-1',
      command: VaconCommandType.start,
    );

    expect(result.isVerified, isTrue);
    expect(result.telemetry?.running, isTrue);
    expect(result.telemetry?.actualHz, 20);
    expect(control.resultsForFacility('facility-a'), hasLength(1));
  });

  test('rejects missing permission, entitlement and cross-facility access',
      () async {
    final control = service(entitled: false);
    final noPermission = await control.requestSimulation(
      access: const VaconAccessContext(
        facilityId: 'facility-a',
        canRead: true,
        canControl: false,
        hasEntitlement: true,
      ),
      deviceId: 'device-1',
      command: VaconCommandType.start,
    );
    final noEntitlement = await control.requestSimulation(
      access: access,
      deviceId: 'device-1',
      command: VaconCommandType.start,
    );
    final crossFacility = await control.requestSimulation(
      access: const VaconAccessContext(
        facilityId: 'facility-b',
        canRead: true,
        canControl: true,
        hasEntitlement: true,
      ),
      deviceId: 'device-1',
      command: VaconCommandType.start,
    );

    expect(noPermission.reason, 'missing-pump-control-permission');
    expect(noEntitlement.reason, 'vacon-control-not-entitled');
    expect(crossFacility.reason, 'vacon-control-not-entitled');
  });

  test('rejects stale telemetry, local interlocks and unknown models',
      () async {
    final stale = service(
      device: _device(
        now,
        telemetry: VaconTelemetry(
          measuredAt: now.subtract(const Duration(minutes: 1)),
          quality: 'simulated',
          running: false,
        ),
      ),
    );
    final interlocked = service(
      device: _device(now, localInterlockSatisfied: false),
    );
    final unknown = service(
      device: _device(
        now,
        profile: MockVaconControlService.unknownProfile,
      ),
    );

    expect(
      (await stale.requestSimulation(
        access: access,
        deviceId: 'device-1',
        command: VaconCommandType.start,
      ))
          .reason,
      'telemetry-stale',
    );
    expect(
      (await interlocked.requestSimulation(
        access: access,
        deviceId: 'device-1',
        command: VaconCommandType.start,
      ))
          .reason,
      'local-interlock-blocked',
    );
    expect(
      (await unknown.requestSimulation(
        access: access,
        deviceId: 'device-1',
        command: VaconCommandType.start,
      ))
          .reason,
      'model-profile-not-approved',
    );
  });

  test('rejects replay and out-of-range simulation requests', () async {
    final control = service();
    final first = await control.requestSimulation(
      access: access,
      deviceId: 'device-1',
      command: VaconCommandType.setFrequency,
      frequencyHz: 35,
      requestId: 'request-1',
    );
    final replay = await control.requestSimulation(
      access: access,
      deviceId: 'device-1',
      command: VaconCommandType.start,
      requestId: 'request-1',
    );
    final outOfRange = await control.requestSimulation(
      access: access,
      deviceId: 'device-1',
      command: VaconCommandType.setFrequency,
      frequencyHz: 51,
    );

    expect(first.isVerified, isTrue);
    expect(replay.reason, 'duplicate-request');
    expect(outOfRange.reason, 'frequency-out-of-range');
  });
}

VaconDevice _device(
  DateTime now, {
  VaconTelemetry? telemetry,
  VaconModelProfile? profile,
  bool localInterlockSatisfied = true,
}) =>
    VaconDevice(
      id: 'device-1',
      facilityId: 'facility-a',
      siteId: 'site-1',
      name: 'Simulert pumpe',
      modelProfile:
          profile ?? MockVaconControlService.documentedSimulationProfile,
      endpointLabel: 'simulated-gateway.invalid',
      port: 502,
      unitId: 1,
      minHz: 20,
      maxHz: 50,
      pollingInterval: const Duration(seconds: 15),
      connection: VaconConnectionState.online,
      controlMode: VaconControlMode.simulationOnly,
      localInterlockSatisfied: localInterlockSatisfied,
      telemetry: telemetry ??
          VaconTelemetry(
            measuredAt: now.subtract(const Duration(seconds: 5)),
            quality: 'simulated',
            running: false,
            actualHz: 0,
            referenceHz: 20,
          ),
    );
