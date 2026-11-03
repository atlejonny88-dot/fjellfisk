import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/addon.dart';

/// Identifies a tank without relying on operator-entered names.
class DashboardTemperatureTankKey {
  const DashboardTemperatureTankKey({
    required this.sectionId,
    required this.tankId,
  });

  final String sectionId;
  final String tankId;

  factory DashboardTemperatureTankKey.fromMap(Map<Object?, Object?> data) {
    return DashboardTemperatureTankKey(
      sectionId: (data['sectionId'] ?? '').toString(),
      tankId: (data['tankId'] ?? '').toString(),
    );
  }

  bool get isValid => sectionId.isNotEmpty && tankId.isNotEmpty;

  Map<String, String> toMap() => {
        'sectionId': sectionId,
        'tankId': tankId,
      };

  @override
  bool operator ==(Object other) =>
      other is DashboardTemperatureTankKey &&
      other.sectionId == sectionId &&
      other.tankId == tankId;

  @override
  int get hashCode => Object.hash(sectionId, tankId);
}

/// Facility-owned selection of tank temperatures used by the dashboard KPI.
class DashboardTemperatureConfiguration {
  const DashboardTemperatureConfiguration({
    required this.isConfigured,
    required this.selectedTanks,
  });

  const DashboardTemperatureConfiguration.unconfigured()
      : isConfigured = false,
        selectedTanks = const <DashboardTemperatureTankKey>{};

  final bool isConfigured;
  final Set<DashboardTemperatureTankKey> selectedTanks;

  factory DashboardTemperatureConfiguration.fromFacilityData(
    Map<String, dynamic>? facility,
  ) {
    final raw = facility?['dashboardTemperature'];
    if (raw is! Map) {
      return const DashboardTemperatureConfiguration.unconfigured();
    }
    final configured = raw['configured'] == true;
    final sources = raw['sources'];
    final selected = <DashboardTemperatureTankKey>{};
    if (sources is List) {
      for (final source in sources) {
        if (source is! Map) continue;
        final key = DashboardTemperatureTankKey.fromMap(source);
        if (key.isValid) selected.add(key);
      }
    }
    return DashboardTemperatureConfiguration(
      isConfigured: configured,
      selectedTanks: Set.unmodifiable(selected),
    );
  }

  Map<String, Object> toFirestore() => {
        'configured': true,
        'sources':
            selectedTanks.map((tank) => tank.toMap()).toList(growable: false),
      };
}

abstract interface class DashboardTemperatureConfigurationStore {
  Stream<DashboardTemperatureConfiguration> watch(String facilityId);

  Future<DashboardTemperatureConfiguration> load(String facilityId);

  Future<void> save(
    String facilityId,
    DashboardTemperatureConfiguration configuration,
  );
}

/// Persists the selection alongside the existing facility settings.
class FirestoreDashboardTemperatureConfigurationStore
    implements DashboardTemperatureConfigurationStore {
  FirestoreDashboardTemperatureConfigurationStore(
      {FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _facility(String facilityId) =>
      _firestore.collection('facilities').doc(facilityId);

  @override
  Stream<DashboardTemperatureConfiguration> watch(String facilityId) =>
      _facility(facilityId).snapshots().map(
            (snapshot) => DashboardTemperatureConfiguration.fromFacilityData(
              snapshot.data(),
            ),
          );

  @override
  Future<DashboardTemperatureConfiguration> load(String facilityId) async {
    final snapshot = await _facility(facilityId).get();
    return DashboardTemperatureConfiguration.fromFacilityData(snapshot.data());
  }

  @override
  Future<void> save(
    String facilityId,
    DashboardTemperatureConfiguration configuration,
  ) {
    return _facility(facilityId).set(
      {'dashboardTemperature': configuration.toFirestore()},
      SetOptions(merge: true),
    );
  }
}

enum DashboardTemperatureState {
  live,
  notConfigured,
  noData,
}

class DashboardTemperatureSummary {
  const DashboardTemperatureSummary({
    required this.state,
    required this.includedTankCount,
    required this.usesDefaultSelection,
    this.temperatureC,
  });

  final DashboardTemperatureState state;
  final int includedTankCount;
  final bool usesDefaultSelection;
  final double? temperatureC;

  double? get roundedTemperatureC =>
      temperatureC == null ? null : (temperatureC! * 10).roundToDouble() / 10;
}

/// Calculates one temperature per tank from the same resolved sensor that the
/// corresponding tank card uses. It deliberately has no species temperature
/// range, so a valid value above or below a conventional farming range remains
/// valid.
class DashboardTemperatureCalculator {
  const DashboardTemperatureCalculator._();

  static DashboardTemperatureSummary calculate({
    required DashboardTemperatureConfiguration configuration,
    required Iterable<CollectorSensorMapping> mappings,
    required Set<DashboardTemperatureTankKey> activeTanks,
    required CollectorSensor? Function(CollectorSensorMapping mapping)
        sensorForMapping,
  }) {
    if (configuration.isConfigured && configuration.selectedTanks.isEmpty) {
      return const DashboardTemperatureSummary(
        state: DashboardTemperatureState.notConfigured,
        includedTankCount: 0,
        usesDefaultSelection: false,
      );
    }

    final values = <double>[];
    final seenTanks = <DashboardTemperatureTankKey>{};
    var hasCandidate = false;

    for (final mapping in mappings) {
      if (!mapping.isComplete) continue;
      final key = DashboardTemperatureTankKey(
        sectionId: mapping.sectionId!,
        tankId: mapping.tankId!,
      );
      final selected = configuration.isConfigured
          ? configuration.selectedTanks.contains(key)
          : true;
      if (!selected || !activeTanks.contains(key) || !seenTanks.add(key)) {
        continue;
      }
      hasCandidate = true;

      final sensor = sensorForMapping(mapping);
      final value = sensor?.temperatureC;
      if (sensor == null ||
          sensor.status != CollectorSensorStatus.live ||
          value == null ||
          !value.isFinite) {
        continue;
      }
      values.add(value);
    }

    if (values.isEmpty) {
      return DashboardTemperatureSummary(
        state: configuration.isConfigured || hasCandidate
            ? DashboardTemperatureState.noData
            : DashboardTemperatureState.notConfigured,
        includedTankCount: 0,
        usesDefaultSelection: !configuration.isConfigured,
      );
    }

    return DashboardTemperatureSummary(
      state: DashboardTemperatureState.live,
      temperatureC:
          values.reduce((left, right) => left + right) / values.length,
      includedTankCount: values.length,
      usesDefaultSelection: !configuration.isConfigured,
    );
  }
}
