import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/addon.dart';
import 'addon_service.dart';
import 'collector_claim_service.dart';

/// Uses the existing authenticated API. Pairing never supplies mock sensors.
class RemoteAddOnService extends AddOnService {
  RemoteAddOnService(
      {required this.api,
      required this.facilityId,
      Future<List<CollectorSectionOption>> Function()? sectionLoader})
      : _sectionLoader = sectionLoader;

  final CollectorClaimService api;
  final String facilityId;
  List<AddOn> _addOns = const [_unconnected];
  bool _refreshing = false;
  bool _disposed = false;
  ClaimCodeResultType? _loadError;
  Future<void>? _refreshFuture;
  final Future<List<CollectorSectionOption>> Function()? _sectionLoader;
  final Map<String, CollectorSensorSnapshot> _snapshots = {};
  List<CollectorSectionOption> _sections = const [];
  bool _sectionsLoaded = false;
  bool _sectionsUnavailable = false;

  @override
  String get mappingFacilityId => facilityId;
  @override
  List<CollectorSectionOption> get sections => List.unmodifiable(_sections);
  @override
  bool get sectionsUnavailable => _sectionsUnavailable;

  @override
  Future<void> loadSections() async {
    if (_sectionsLoaded || _disposed) return;
    try {
      final loader = _sectionLoader;
      final List<CollectorSectionOption> sections;
      if (loader != null) {
        sections = await loader();
      } else {
        final result = await FirebaseFirestore.instance
            .collection('facilities')
            .doc(facilityId)
            .collection('sections')
            .get()
            .timeout(const Duration(seconds: 12));
        sections = [];
        for (final section in result.docs) {
          final tanks = await section.reference
              .collection('tanks')
              .get()
              .timeout(const Duration(seconds: 12));
          sections.add(CollectorSectionOption(
              id: section.id,
              name: section.data()['name'] is String
                  ? section.data()['name']
                  : section.id,
              tanks: [
                for (final tank in tanks.docs)
                  CollectorTankOption(
                      id: tank.id,
                      name: tank.data()['name'] is String
                          ? tank.data()['name']
                          : tank.id)
              ]));
        }
      }
      if (!_disposed) {
        _sections = sections;
        _sectionsLoaded = true;
        _sectionsUnavailable = false;
      }
    } catch (_) {
      if (!_disposed) _sectionsUnavailable = true;
    }
    if (!_disposed) notifyListeners();
  }

  static const _unconnected = AddOn(
    id: 'fjellfisk-collector',
    type: AddOnType.collector,
    name: 'Fjellfisk Collector',
    description: '',
    status: AddOnStatus.notConnected,
  );

  @override
  List<AddOn> get addOns => List.unmodifiable(_addOns);

  @override
  bool get isRefreshing => _refreshing;

  @override
  ClaimCodeResultType? get loadError => _loadError;

  @override
  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _refreshFuture ??= _refresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<void> _refresh() async {
    _refreshing = true;
    _loadError = null;
    notifyListeners();
    try {
      final collectors = await api.fetchCollectors(facilityId: facilityId);
      final snapshots = <String, CollectorSensorSnapshot>{};
      final resolved = <AddOn>[];
      for (final collector in collectors) {
        if (collector.status == AddOnStatus.connected ||
            collector.status == AddOnStatus.offline) {
          final snapshot = await api.fetchSensors(
              facilityId: facilityId, collectorId: collector.id);
          snapshots[collector.id] = snapshot;
          final dates = snapshot.sensors
              .map((sensor) => sensor.updatedAt)
              .toList()
            ..sort();
          resolved.add(collector.copyWith(
              sensorCount: snapshot.sensors.length,
              latestMeasurementAt: dates.isEmpty ? null : dates.last,
              clearLatestMeasurement: dates.isEmpty));
        } else {
          resolved.add(collector);
        }
      }
      if (!_disposed) {
        _snapshots
          ..clear()
          ..addAll(snapshots);
        _addOns = resolved.isEmpty ? const [_unconnected] : resolved;
      }
    } on CollectorBackendException catch (error) {
      if (!_disposed) {
        _loadError = error.type;
        // Never retain enabled management controls after authorization fails.
        if (error.type == ClaimCodeResultType.unauthorized) {
          _addOns = const [_unconnected];
          _snapshots.clear();
        }
      }
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  Future<ClaimCodeResult> claimCollector(String claimCode) async {
    final result = await api.claimCollector(
      facilityId: facilityId,
      pairingCode: claimCode,
    );
    if (result.isSuccess) {
      // A request started before claim may still contain UNPAIRED state.
      await _refreshFuture;
      await refresh();
    }
    return result;
  }

  @override
  Future<void> disconnect(String addOnId) async {
    if (!_addOns.any((addOn) => addOn.id == addOnId)) return;
    final result = await api.revokeCollector(
      facilityId: facilityId,
      collectorId: addOnId,
    );
    if (!result.isSuccess) throw CollectorBackendException(result.type);
    if (_disposed) return;
    _addOns = [
      for (final addOn in _addOns)
        if (addOn.id == addOnId)
          addOn.copyWith(status: AddOnStatus.revoked, clearConnection: true)
        else
          addOn,
    ];
    notifyListeners();
    await _refreshFuture;
    await refresh();
  }

  @override
  List<CollectorSensor> sensorsForCollector(String collectorId) => [
        for (final sensor
            in _snapshots[collectorId]?.sensors ?? <CollectorSensor>[])
          CollectorSensor(
              id: sensor.id,
              collectorId: sensor.collectorId,
              name: sensor.name,
              updatedAt: sensor.updatedAt,
              temperatureC: sensor.temperatureC,
              oxygenMgL: sensor.oxygenMgL,
              oxygenSaturationPct: sensor.oxygenSaturationPct,
              status: DateTime.now().difference(sensor.updatedAt) >
                          const Duration(minutes: 5) ||
                      _loadError != null
                  ? CollectorSensorStatus.offline
                  : DateTime.now().difference(sensor.updatedAt) >
                          const Duration(minutes: 1)
                      ? CollectorSensorStatus.stale
                      : sensor.status),
      ];

  @override
  List<CollectorSensorMapping> mappingsForCollector(String collectorId) =>
      List.unmodifiable(_snapshots[collectorId]?.mappings ??
          const <CollectorSensorMapping>[]);

  @override
  CollectorSensor? sensorForTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  }) {
    if (facilityId != this.facilityId) return null;
    for (final entry in _snapshots.entries) {
      for (final mapping in entry.value.mappings) {
        if (mapping.facilityId == facilityId &&
            mapping.sectionId == sectionId &&
            mapping.tankId == tankId) {
          for (final sensor in sensorsForCollector(entry.key)) {
            if (sensor.id == mapping.sensorId) return sensor;
          }
        }
      }
    }
    return null;
  }

  @override
  Future<void> saveCollectorMappings(
    String collectorId,
    Iterable<CollectorSensorMapping> mappings,
  ) async {
    final selected = mappings.toList();
    if (!_addOns.any((collector) =>
            collector.id == collectorId && collector.canConfigure) ||
        selected.any((mapping) =>
            mapping.collectorId != collectorId ||
            mapping.facilityId != facilityId ||
            !mapping.isComplete)) {
      throw const CollectorBackendException(ClaimCodeResultType.invalid);
    }
    await api.saveSensorMappings(
        facilityId: facilityId, collectorId: collectorId, mappings: selected);
    if (_disposed) return;
    final current = _snapshots[collectorId];
    if (current != null) {
      _snapshots[collectorId] =
          CollectorSensorSnapshot(current.sensors, List.unmodifiable(selected));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
