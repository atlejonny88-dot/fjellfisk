import 'package:flutter/foundation.dart';

import '../models/vacon_control.dart';

/// Boundary for a future trusted gateway-backed implementation.
///
/// The V4 implementation intentionally exposes only an in-memory simulator.
/// It has no Firebase, VPN, TCP, Modbus or production hardware dependency.
abstract class VaconControlService extends ChangeNotifier {
  List<VaconSite> sitesForFacility(String facilityId);

  List<VaconDevice> devicesForFacility(String facilityId);

  VaconEntitlement entitlementForFacility(String facilityId);

  List<VaconCommandResult> resultsForFacility(String facilityId);

  Future<VaconCommandResult> requestSimulation({
    required VaconAccessContext access,
    required String deviceId,
    required VaconCommandType command,
    double? frequencyHz,
    String? requestId,
  });
}

class MockVaconControlService extends VaconControlService {
  MockVaconControlService({
    DateTime Function()? clock,
    List<VaconSite>? sites,
    List<VaconDevice>? devices,
    List<VaconEntitlement>? entitlements,
  })  : _clock = clock ?? DateTime.now,
        _sites = List<VaconSite>.from(sites ?? _defaultSites),
        _devices = List<VaconDevice>.from(devices ?? _defaultDevices),
        _entitlements = {
          for (final entitlement in entitlements ?? _defaultEntitlements)
            entitlement.facilityId: entitlement,
        };

  static const defaultFacilityId = 'default_facility';
  static final MockVaconControlService shared = MockVaconControlService();

  static const documentedSimulationProfile = VaconModelProfile(
    id: 'simulation-profile-v1',
    name: 'Simulert testprofil',
    isDocumented: true,
    supportsRemoteControl: true,
  );

  static const unknownProfile = VaconModelProfile(
    id: 'unknown-vacon',
    name: 'Ukjent VACON-modell',
    isDocumented: false,
    supportsRemoteControl: false,
  );

  final DateTime Function() _clock;
  final List<VaconSite> _sites;
  final List<VaconDevice> _devices;
  final Map<String, VaconEntitlement> _entitlements;
  final List<_StoredResult> _results = [];
  final Set<String> _processedRequestIds = <String>{};
  int _requestSequence = 0;

  static final List<VaconSite> _defaultSites = [
    const VaconSite(
      id: 'simulated-site-north',
      facilityId: defaultFacilityId,
      name: 'Simulert teknisk rom',
      gatewayLabel: 'Simulert gateway',
      connection: VaconConnectionState.online,
    ),
  ];

  static final List<VaconEntitlement> _defaultEntitlements = [
    const VaconEntitlement(facilityId: defaultFacilityId, enabled: true),
  ];

  static List<VaconDevice> get _defaultDevices {
    final now = DateTime.now();
    return [
      VaconDevice(
        id: 'simulation-pump-01',
        facilityId: defaultFacilityId,
        siteId: 'simulated-site-north',
        name: 'Simulert sirkulasjonspumpe',
        modelProfile: documentedSimulationProfile,
        endpointLabel: 'simulated-gateway.invalid',
        port: 502,
        unitId: 1,
        minHz: 20,
        maxHz: 50,
        pollingInterval: const Duration(seconds: 15),
        connection: VaconConnectionState.online,
        controlMode: VaconControlMode.simulationOnly,
        localInterlockSatisfied: true,
        telemetry: VaconTelemetry(
          measuredAt: now.subtract(const Duration(seconds: 8)),
          quality: 'simulated',
          running: true,
          actualHz: 35,
          referenceHz: 35,
          currentA: 4.2,
          powerKw: 1.9,
          statusText: 'Simulert normal drift',
        ),
      ),
      VaconDevice(
        id: 'uncommissioned-pump-02',
        facilityId: defaultFacilityId,
        siteId: 'simulated-site-north',
        name: 'Ny VACON-enhet',
        modelProfile: unknownProfile,
        endpointLabel: 'ikke konfigurert',
        port: 502,
        unitId: 2,
        minHz: 0,
        maxHz: 0,
        pollingInterval: const Duration(seconds: 15),
        connection: VaconConnectionState.offline,
        controlMode: VaconControlMode.disabled,
        localInterlockSatisfied: false,
        telemetry: VaconTelemetry(
          measuredAt: now.subtract(const Duration(minutes: 10)),
          quality: 'unavailable',
          running: false,
          statusText: 'Venter på idriftsettelse',
        ),
      ),
    ];
  }

  @override
  List<VaconSite> sitesForFacility(String facilityId) => List.unmodifiable(
        _sites.where((site) => site.facilityId == facilityId),
      );

  @override
  List<VaconDevice> devicesForFacility(String facilityId) => List.unmodifiable(
        _devices.where((device) => device.facilityId == facilityId),
      );

  @override
  VaconEntitlement entitlementForFacility(String facilityId) =>
      _entitlements[facilityId] ??
      VaconEntitlement(facilityId: facilityId, enabled: false);

  @override
  List<VaconCommandResult> resultsForFacility(String facilityId) =>
      List.unmodifiable(
        _results
            .where((item) => item.facilityId == facilityId)
            .map((item) => item.result),
      );

  @override
  Future<VaconCommandResult> requestSimulation({
    required VaconAccessContext access,
    required String deviceId,
    required VaconCommandType command,
    double? frequencyHz,
    String? requestId,
  }) async {
    final id = requestId ?? 'simulation-${++_requestSequence}';
    VaconCommandResult rejected(String reason) {
      final result = VaconCommandResult.rejected(requestId: id, reason: reason);
      _results.add(_StoredResult(access.facilityId, result));
      notifyListeners();
      return result;
    }

    if (!access.canRead || !access.canControl) {
      return rejected('missing-pump-control-permission');
    }
    if (!access.hasEntitlement ||
        !entitlementForFacility(access.facilityId).enabled) {
      return rejected('vacon-control-not-entitled');
    }
    if (!_processedRequestIds.add(id)) return rejected('duplicate-request');

    final index = _devices.indexWhere(
      (device) =>
          device.id == deviceId && device.facilityId == access.facilityId,
    );
    if (index < 0) return rejected('device-not-found-in-facility');
    final device = _devices[index];
    final now = _clock();
    if (device.controlMode != VaconControlMode.simulationOnly) {
      return rejected('physical-control-disabled');
    }
    if (!device.modelProfile.isDocumented ||
        !device.modelProfile.supportsRemoteControl) {
      return rejected('model-profile-not-approved');
    }
    if (device.connection != VaconConnectionState.online) {
      return rejected('gateway-not-connected');
    }
    if (!device.localInterlockSatisfied) {
      return rejected('local-interlock-blocked');
    }
    if (!device.telemetry.isFreshAt(now)) return rejected('telemetry-stale');
    if (command == VaconCommandType.setFrequency &&
        (frequencyHz == null ||
            !frequencyHz.isFinite ||
            frequencyHz < device.minHz ||
            frequencyHz > device.maxHz)) {
      return rejected('frequency-out-of-range');
    }
    if (command != VaconCommandType.setFrequency && frequencyHz != null) {
      return rejected('unexpected-frequency-value');
    }

    // This is in-memory readback from a test double. It has no transport and
    // therefore cannot emit a Modbus command or touch a physical drive.
    final previous = device.telemetry;
    final nextRunning = switch (command) {
      VaconCommandType.start => true,
      VaconCommandType.stop => false,
      _ => previous.running,
    };
    final nextHz = switch (command) {
      VaconCommandType.stop => 0.0,
      VaconCommandType.setFrequency => frequencyHz!,
      VaconCommandType.start => previous.referenceHz ?? device.minHz,
      VaconCommandType.faultReset => previous.referenceHz ?? 0,
    };
    final nextTelemetry = previous.copyWith(
      measuredAt: now,
      quality: 'simulated',
      running: nextRunning,
      actualHz: nextRunning ? nextHz : 0,
      referenceHz: nextHz,
      statusText: 'Simulert readback verifisert',
      faultCode:
          command == VaconCommandType.faultReset ? null : previous.faultCode,
    );
    _devices[index] = device.copyWith(telemetry: nextTelemetry);
    final result = VaconCommandResult.verified(
      requestId: id,
      telemetry: nextTelemetry,
    );
    _results.add(_StoredResult(access.facilityId, result));
    notifyListeners();
    return result;
  }
}

class _StoredResult {
  const _StoredResult(this.facilityId, this.result);

  final String facilityId;
  final VaconCommandResult result;
}
