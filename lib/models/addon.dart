enum AddOnType {
  collector,
  camera,
  sensor,
  externalService,
}

enum AddOnStatus {
  notConnected,
  pending,
  connected,
  offline,
  revoked,
  error,
}

class AddOn {
  const AddOn({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.status,
    this.connectedDeviceId,
    this.connectedAt,
    this.lastSeenAt,
    this.version,
    this.deviceName,
    this.readerType,
    this.sensorCount,
    this.latestMeasurementAt,
  });

  final String id;
  final AddOnType type;
  final String name;
  final String description;
  final AddOnStatus status;
  final String? connectedDeviceId;
  final DateTime? connectedAt;
  final DateTime? lastSeenAt;
  final String? version;
  final String? deviceName;
  final String? readerType;
  final int? sensorCount;
  final DateTime? latestMeasurementAt;

  bool get isConnected => status == AddOnStatus.connected;

  AddOn copyWith({
    AddOnStatus? status,
    String? connectedDeviceId,
    DateTime? connectedAt,
    DateTime? lastSeenAt,
    String? version,
    String? deviceName,
    String? readerType,
    int? sensorCount,
    DateTime? latestMeasurementAt,
    bool clearConnection = false,
    bool clearLastSeen = false,
    bool clearLatestMeasurement = false,
  }) {
    return AddOn(
      id: id,
      type: type,
      name: name,
      description: description,
      status: status ?? this.status,
      connectedDeviceId:
          clearConnection ? null : connectedDeviceId ?? this.connectedDeviceId,
      connectedAt: clearConnection ? null : connectedAt ?? this.connectedAt,
      lastSeenAt: clearLastSeen ? null : lastSeenAt ?? this.lastSeenAt,
      version: clearConnection ? null : version ?? this.version,
      deviceName: clearConnection ? null : deviceName ?? this.deviceName,
      readerType: clearConnection ? null : readerType ?? this.readerType,
      sensorCount: clearConnection ? null : sensorCount ?? this.sensorCount,
      latestMeasurementAt: clearLatestMeasurement
          ? null
          : latestMeasurementAt ?? this.latestMeasurementAt,
    );
  }
}

enum CollectorSensorStatus {
  live,
  stale,
  offline,
}

/// A safe presentation model. It intentionally carries no VIGO path,
/// credentials, COM information, or collector control surface.
class CollectorSensor {
  const CollectorSensor({
    required this.id,
    required this.collectorId,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.temperatureC,
    this.oxygenMgL,
    this.oxygenSaturationPct,
  });

  final String id;
  final String collectorId;
  final String name;
  final CollectorSensorStatus status;
  final DateTime updatedAt;
  final double? temperatureC;
  final double? oxygenMgL;
  final double? oxygenSaturationPct;
}

/// Local mock state for a sensor-to-tank selection. A future backend can
/// replace persistence without changing the UI model.
class CollectorSensorMapping {
  const CollectorSensorMapping({
    required this.collectorId,
    required this.sensorId,
    this.facilityId,
    this.sectionId,
    this.sectionName,
    this.tankId,
    this.tankName,
  });

  final String collectorId;
  final String sensorId;
  final String? facilityId;
  final String? sectionId;
  final String? sectionName;
  final String? tankId;
  final String? tankName;

  bool get isComplete =>
      sectionId != null &&
      sectionName != null &&
      tankId != null &&
      tankName != null;

  CollectorSensorMapping copyWith({
    String? facilityId,
    String? sectionId,
    String? sectionName,
    String? tankId,
    String? tankName,
    bool clearTank = false,
  }) {
    return CollectorSensorMapping(
      collectorId: collectorId,
      sensorId: sensorId,
      facilityId: facilityId ?? this.facilityId,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      tankId: clearTank ? null : tankId ?? this.tankId,
      tankName: clearTank ? null : tankName ?? this.tankName,
    );
  }

  bool matchesTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  }) {
    if (!isComplete) return false;

    final sectionMatches = this.sectionId == sectionId ||
        _matchesDisplayName(this.sectionName, sectionName);
    final tankMatches =
        this.tankId == tankId || _matchesDisplayName(this.tankName, tankName);
    final facilityMatches = this.facilityId == null ||
        this.facilityId == facilityId ||
        this.facilityId == MockCollectorSetupCatalog.facilityId;
    return facilityMatches && sectionMatches && tankMatches;
  }

  static bool _matchesDisplayName(String? left, String right) =>
      left?.trim().toLowerCase() == right.trim().toLowerCase();
}

class CollectorTankOption {
  const CollectorTankOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class CollectorSectionOption {
  const CollectorSectionOption({
    required this.id,
    required this.name,
    required this.tanks,
  });

  final String id;
  final String name;
  final List<CollectorTankOption> tanks;
}

/// Temporary local catalogue for UI work only. It is deliberately separate
/// from Firestore and will later be replaced by a reviewed facility catalogue.
class MockCollectorSetupCatalog {
  const MockCollectorSetupCatalog._();

  static const facilityId = 'mock-arctic-hardanger';

  static const sections = <CollectorSectionOption>[
    CollectorSectionOption(
      id: 'mock-hovedbygg',
      name: 'Hovedbygg',
      tanks: [
        CollectorTankOption(id: 'mock-k1', name: 'K1'),
        CollectorTankOption(id: 'mock-k2', name: 'K2'),
      ],
    ),
    CollectorSectionOption(
      id: 'mock-tunnel',
      name: 'Tunnel',
      tanks: [
        CollectorTankOption(id: 'mock-t1', name: 'T1'),
        CollectorTankOption(id: 'mock-t2', name: 'T2'),
      ],
    ),
  ];
}
