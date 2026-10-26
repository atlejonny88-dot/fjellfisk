enum VaconConnectionState { online, stale, offline }

enum VaconControlMode {
  /// No control path is available for this device.
  disabled,

  /// Used only by the local V4 test harness. It never talks to Modbus.
  simulationOnly,

  /// Reserved for a future, separately approved commissioning process.
  commissioned,
}

enum VaconCommandType { start, stop, setFrequency, faultReset }

enum VaconCommandStatus { verified, rejected }

class VaconEntitlement {
  const VaconEntitlement({
    required this.facilityId,
    required this.enabled,
  });

  final String facilityId;
  final bool enabled;
}

class VaconSite {
  const VaconSite({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.gatewayLabel,
    required this.connection,
  });

  final String id;
  final String facilityId;
  final String name;
  final String gatewayLabel;
  final VaconConnectionState connection;
}

class VaconModelProfile {
  const VaconModelProfile({
    required this.id,
    required this.name,
    required this.isDocumented,
    required this.supportsRemoteControl,
  });

  final String id;
  final String name;

  /// A profile cannot be used for remote control until its exact model,
  /// firmware and register map are independently documented.
  final bool isDocumented;
  final bool supportsRemoteControl;
}

class VaconTelemetry {
  const VaconTelemetry({
    required this.measuredAt,
    required this.quality,
    required this.running,
    this.actualHz,
    this.referenceHz,
    this.currentA,
    this.powerKw,
    this.statusText,
    this.faultCode,
  });

  final DateTime measuredAt;
  final String quality;
  final bool running;
  final double? actualHz;
  final double? referenceHz;
  final double? currentA;
  final double? powerKw;
  final String? statusText;
  final String? faultCode;

  bool isFreshAt(DateTime now) {
    final age = now.difference(measuredAt);
    return age >= Duration.zero && age <= const Duration(seconds: 30);
  }

  VaconTelemetry copyWith({
    DateTime? measuredAt,
    String? quality,
    bool? running,
    double? actualHz,
    double? referenceHz,
    double? currentA,
    double? powerKw,
    String? statusText,
    String? faultCode,
  }) {
    return VaconTelemetry(
      measuredAt: measuredAt ?? this.measuredAt,
      quality: quality ?? this.quality,
      running: running ?? this.running,
      actualHz: actualHz ?? this.actualHz,
      referenceHz: referenceHz ?? this.referenceHz,
      currentA: currentA ?? this.currentA,
      powerKw: powerKw ?? this.powerKw,
      statusText: statusText ?? this.statusText,
      faultCode: faultCode ?? this.faultCode,
    );
  }
}

class VaconDevice {
  const VaconDevice({
    required this.id,
    required this.facilityId,
    required this.siteId,
    required this.name,
    required this.modelProfile,
    required this.endpointLabel,
    required this.port,
    required this.unitId,
    required this.minHz,
    required this.maxHz,
    required this.pollingInterval,
    required this.connection,
    required this.controlMode,
    required this.localInterlockSatisfied,
    required this.telemetry,
  });

  final String id;
  final String facilityId;
  final String siteId;
  final String name;
  final VaconModelProfile modelProfile;

  /// A display-only placeholder in local V4. It is never a real customer IP.
  final String endpointLabel;
  final int port;
  final int unitId;
  final double minHz;
  final double maxHz;
  final Duration pollingInterval;
  final VaconConnectionState connection;
  final VaconControlMode controlMode;
  final bool localInterlockSatisfied;
  final VaconTelemetry telemetry;

  bool canSimulateControlAt(DateTime now) =>
      controlMode == VaconControlMode.simulationOnly &&
      modelProfile.isDocumented &&
      modelProfile.supportsRemoteControl &&
      connection == VaconConnectionState.online &&
      localInterlockSatisfied &&
      telemetry.isFreshAt(now);

  VaconDevice copyWith({
    VaconTelemetry? telemetry,
    VaconConnectionState? connection,
    VaconControlMode? controlMode,
    bool? localInterlockSatisfied,
  }) {
    return VaconDevice(
      id: id,
      facilityId: facilityId,
      siteId: siteId,
      name: name,
      modelProfile: modelProfile,
      endpointLabel: endpointLabel,
      port: port,
      unitId: unitId,
      minHz: minHz,
      maxHz: maxHz,
      pollingInterval: pollingInterval,
      connection: connection ?? this.connection,
      controlMode: controlMode ?? this.controlMode,
      localInterlockSatisfied:
          localInterlockSatisfied ?? this.localInterlockSatisfied,
      telemetry: telemetry ?? this.telemetry,
    );
  }
}

class VaconCommandResult {
  const VaconCommandResult._({
    required this.status,
    required this.requestId,
    this.reason,
    this.telemetry,
  });

  factory VaconCommandResult.verified({
    required String requestId,
    required VaconTelemetry telemetry,
  }) =>
      VaconCommandResult._(
        status: VaconCommandStatus.verified,
        requestId: requestId,
        telemetry: telemetry,
      );

  factory VaconCommandResult.rejected({
    required String requestId,
    required String reason,
  }) =>
      VaconCommandResult._(
        status: VaconCommandStatus.rejected,
        requestId: requestId,
        reason: reason,
      );

  final VaconCommandStatus status;
  final String requestId;
  final String? reason;
  final VaconTelemetry? telemetry;

  bool get isVerified => status == VaconCommandStatus.verified;
}

class VaconAccessContext {
  const VaconAccessContext({
    required this.facilityId,
    required this.canRead,
    required this.canControl,
    required this.hasEntitlement,
  });

  final String facilityId;
  final bool canRead;
  final bool canControl;
  final bool hasEntitlement;
}
