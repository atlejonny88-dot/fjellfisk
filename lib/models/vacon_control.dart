enum VaconConnectionState { online, stale, offline, disabled }

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
    this.motorSpeedRpm,
    this.motorSpeedVerified = false,
    this.motorCurrentRaw,
    this.motorCurrentVerified = false,
    this.ready,
    this.fault,
    this.alarm,
    this.atReference,
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
  final double? motorSpeedRpm;
  final bool motorSpeedVerified;
  final int? motorCurrentRaw;
  final bool motorCurrentVerified;
  final bool? ready;
  final bool? fault;
  final bool? alarm;
  final bool? atReference;

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
    double? motorSpeedRpm,
    bool? motorSpeedVerified,
    int? motorCurrentRaw,
    bool? motorCurrentVerified,
    bool? ready,
    bool? fault,
    bool? alarm,
    bool? atReference,
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
      motorSpeedRpm: motorSpeedRpm ?? this.motorSpeedRpm,
      motorSpeedVerified: motorSpeedVerified ?? this.motorSpeedVerified,
      motorCurrentRaw: motorCurrentRaw ?? this.motorCurrentRaw,
      motorCurrentVerified: motorCurrentVerified ?? this.motorCurrentVerified,
      ready: ready ?? this.ready,
      fault: fault ?? this.fault,
      alarm: alarm ?? this.alarm,
      atReference: atReference ?? this.atReference,
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
    this.manufacturer = 'Danfoss',
    this.subnetMask = '',
    this.gateway = '',
    this.dns = '',
    this.edgeServerId = '',
    this.monitoringEnabled = true,
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
  final String manufacturer;
  final String subnetMask;
  final String gateway;
  final String dns;
  final String edgeServerId;
  final bool monitoringEnabled;

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
    VaconModelProfile? modelProfile,
    String? name,
    String? endpointLabel,
    int? port,
    int? unitId,
    double? minHz,
    double? maxHz,
    String? manufacturer,
    String? subnetMask,
    String? gateway,
    String? dns,
    String? edgeServerId,
    bool? monitoringEnabled,
  }) {
    return VaconDevice(
      id: id,
      facilityId: facilityId,
      siteId: siteId,
      name: name ?? this.name,
      modelProfile: modelProfile ?? this.modelProfile,
      endpointLabel: endpointLabel ?? this.endpointLabel,
      port: port ?? this.port,
      unitId: unitId ?? this.unitId,
      minHz: minHz ?? this.minHz,
      maxHz: maxHz ?? this.maxHz,
      pollingInterval: pollingInterval,
      connection: connection ?? this.connection,
      controlMode: controlMode ?? this.controlMode,
      localInterlockSatisfied:
          localInterlockSatisfied ?? this.localInterlockSatisfied,
      telemetry: telemetry ?? this.telemetry,
      manufacturer: manufacturer ?? this.manufacturer,
      subnetMask: subnetMask ?? this.subnetMask,
      gateway: gateway ?? this.gateway,
      dns: dns ?? this.dns,
      edgeServerId: edgeServerId ?? this.edgeServerId,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
    );
  }
}

class VaconDeviceConfiguration {
  const VaconDeviceConfiguration({
    required this.displayName,
    required this.manufacturer,
    required this.model,
    required this.ipAddress,
    required this.subnetMask,
    required this.gateway,
    required this.dns,
    required this.modbusTcpPort,
    required this.modbusUnitId,
    required this.minFrequencyHz,
    required this.maxFrequencyHz,
    required this.edgeServerId,
    required this.monitoringEnabled,
  });

  final String displayName;
  final String manufacturer;
  final String model;
  final String ipAddress;
  final String subnetMask;
  final String gateway;
  final String dns;
  final int modbusTcpPort;
  final int modbusUnitId;
  final double minFrequencyHz;
  final double maxFrequencyHz;
  final String edgeServerId;
  final bool monitoringEnabled;

  Map<String, Object> toJson() => {
        'displayName': displayName,
        'manufacturer': manufacturer,
        'model': model,
        'ipAddress': ipAddress,
        'subnetMask': subnetMask,
        'gateway': gateway,
        'dns': dns,
        'modbusTcpPort': modbusTcpPort,
        'modbusUnitId': modbusUnitId,
        'minFrequencyHz': minFrequencyHz,
        'maxFrequencyHz': maxFrequencyHz,
        'edgeServerId': edgeServerId,
        'monitoringEnabled': monitoringEnabled,
      };
}

class VaconConnectionTestResult {
  const VaconConnectionTestResult({
    required this.deviceId,
    required this.state,
    required this.reason,
    required this.testedAt,
  });

  final String deviceId;
  final String state;
  final String reason;
  final DateTime testedAt;
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
