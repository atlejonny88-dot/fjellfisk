import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/addon.dart';

enum ClaimCodeResultType {
  success,
  invalid,
  expired,
  alreadyUsed,
  busy,
  unauthorized,
  unavailable,
}

class ClaimCodeResult {
  const ClaimCodeResult(this.type);

  final ClaimCodeResultType type;

  bool get isSuccess => type == ClaimCodeResultType.success;
}

abstract class AddOnService extends ChangeNotifier {
  List<AddOn> get addOns;

  Future<ClaimCodeResult> claimCollector(String claimCode);

  Future<void> disconnect(String addOnId);

  List<CollectorSensor> sensorsForCollector(String collectorId);

  List<CollectorSensorMapping> mappingsForCollector(String collectorId);

  CollectorSensor? sensorForTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  });

  Future<void> saveCollectorMappings(
    String collectorId,
    Iterable<CollectorSensorMapping> mappings,
  );
}

/// Local pairing substitute until a reviewed backend endpoint is available.
/// It intentionally contains no Firebase, network, collector, or credential code.
class MockAddOnService extends AddOnService {
  MockAddOnService({
    List<AddOn>? initialAddOns,
    DateTime Function()? clock,
    DateTime? claimCodeExpiresAt,
    Future<void> Function()? claimDelay,
    List<CollectorSensor>? initialSensors,
    List<CollectorSensorMapping>? initialMappings,
  })  : _clock = clock ?? DateTime.now,
        _claimCodeExpiresAt = claimCodeExpiresAt ??
            (clock ?? DateTime.now)().add(const Duration(minutes: 15)),
        _claimDelay = claimDelay ??
            (() => Future<void>.delayed(const Duration(milliseconds: 180))),
        _addOns = List<AddOn>.from(
          initialAddOns ??
              const [
                AddOn(
                  id: 'fjellfisk-collector',
                  type: AddOnType.collector,
                  name: 'Fjellfisk Collector',
                  description:
                      'Koble Fjellfisk til lokale sensorer og støttede systemer.',
                  status: AddOnStatus.notConnected,
                ),
              ],
        ),
        _sensors = List<CollectorSensor>.from(
          initialSensors ?? _mockSensors((clock ?? DateTime.now)()),
        ),
        _mappings =
            List<CollectorSensorMapping>.from(initialMappings ?? const []);

  static final MockAddOnService shared = MockAddOnService();
  static const String mockClaimCode = 'FJ-8K4P-2XQ7';

  final DateTime Function() _clock;
  final DateTime _claimCodeExpiresAt;
  final Future<void> Function() _claimDelay;
  final List<AddOn> _addOns;
  final List<CollectorSensor> _sensors;
  final List<CollectorSensorMapping> _mappings;
  bool _claimInProgress = false;
  bool _claimCodeConsumed = false;

  @override
  List<AddOn> get addOns => List<AddOn>.unmodifiable(_addOns);

  @override
  List<CollectorSensor> sensorsForCollector(String collectorId) =>
      List<CollectorSensor>.unmodifiable(
        _sensors.where((sensor) => sensor.collectorId == collectorId),
      );

  @override
  List<CollectorSensorMapping> mappingsForCollector(String collectorId) =>
      List<CollectorSensorMapping>.unmodifiable(
        _mappings.where((mapping) => mapping.collectorId == collectorId),
      );

  @override
  CollectorSensor? sensorForTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  }) {
    CollectorSensorMapping? mapping;
    for (final candidate in _mappings) {
      if (candidate.matchesTank(
        facilityId: facilityId,
        sectionId: sectionId,
        sectionName: sectionName,
        tankId: tankId,
        tankName: tankName,
      )) {
        mapping = candidate;
        break;
      }
    }
    if (mapping == null) return null;

    AddOn? collector;
    for (final candidate in _addOns) {
      if (candidate.id == mapping.collectorId) {
        collector = candidate;
        break;
      }
    }
    if (collector?.isConnected != true) return null;

    for (final sensor in _sensors) {
      if (sensor.id == mapping.sensorId &&
          sensor.collectorId == mapping.collectorId) {
        return sensor;
      }
    }
    return null;
  }

  @override
  Future<void> saveCollectorMappings(
    String collectorId,
    Iterable<CollectorSensorMapping> mappings,
  ) async {
    final validSensorIds = _sensors
        .where((sensor) => sensor.collectorId == collectorId)
        .map((sensor) => sensor.id)
        .toSet();
    final sanitized = mappings
        .where(
          (mapping) =>
              mapping.collectorId == collectorId &&
              mapping.isComplete &&
              validSensorIds.contains(mapping.sensorId),
        )
        .toList(growable: false);

    _mappings.removeWhere((mapping) => mapping.collectorId == collectorId);
    _mappings.addAll(sanitized);
    notifyListeners();
  }

  static String normalizeClaimCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');
  }

  @override
  Future<ClaimCodeResult> claimCollector(String claimCode) async {
    if (_claimInProgress) {
      return const ClaimCodeResult(ClaimCodeResultType.busy);
    }

    _claimInProgress = true;
    try {
      await _claimDelay();
      final collectorIndex = _addOns.indexWhere(
        (addOn) => addOn.type == AddOnType.collector,
      );
      if (collectorIndex < 0) {
        return const ClaimCodeResult(ClaimCodeResultType.invalid);
      }

      final normalizedCode = normalizeClaimCode(claimCode);
      if (normalizedCode != normalizeClaimCode(mockClaimCode)) {
        return const ClaimCodeResult(ClaimCodeResultType.invalid);
      }
      if (_clock().isAfter(_claimCodeExpiresAt)) {
        return const ClaimCodeResult(ClaimCodeResultType.expired);
      }
      if (_claimCodeConsumed || _addOns[collectorIndex].isConnected) {
        return const ClaimCodeResult(ClaimCodeResultType.alreadyUsed);
      }

      final now = _clock();
      _claimCodeConsumed = true;
      _addOns[collectorIndex] = _addOns[collectorIndex].copyWith(
        status: AddOnStatus.connected,
        connectedDeviceId: 'mock-collector-vigo-pc',
        connectedAt: now,
        lastSeenAt: now,
        version: '1.0.0',
        deviceName: 'Vigo-PC',
        readerType: 'OxyGuard / VIGO',
        sensorCount: _sensors
            .where((sensor) => sensor.collectorId == _addOns[collectorIndex].id)
            .length,
        latestMeasurementAt: now,
      );
      notifyListeners();
      return const ClaimCodeResult(ClaimCodeResultType.success);
    } finally {
      _claimInProgress = false;
    }
  }

  @override
  Future<void> disconnect(String addOnId) async {
    final index = _addOns.indexWhere((addOn) => addOn.id == addOnId);
    if (index < 0) return;

    _addOns[index] = _addOns[index].copyWith(
      status: AddOnStatus.revoked,
      clearConnection: true,
      clearLastSeen: true,
      clearLatestMeasurement: true,
    );
    notifyListeners();
  }

  static List<CollectorSensor> _mockSensors(DateTime now) => [
        CollectorSensor(
          id: 'pacific-01',
          collectorId: 'fjellfisk-collector',
          name: 'Pacific 01',
          status: CollectorSensorStatus.live,
          updatedAt: now.subtract(const Duration(seconds: 8)),
          temperatureC: 8.60,
          oxygenMgL: 13.10,
          oxygenSaturationPct: 113,
        ),
        CollectorSensor(
          id: 'pacific-02',
          collectorId: 'fjellfisk-collector',
          name: 'Pacific 02',
          status: CollectorSensorStatus.stale,
          updatedAt: now.subtract(const Duration(minutes: 2)),
          temperatureC: 8.35,
          oxygenMgL: 12.82,
          oxygenSaturationPct: 110,
        ),
        CollectorSensor(
          id: 'pacific-03',
          collectorId: 'fjellfisk-collector',
          name: 'Pacific 03',
          status: CollectorSensorStatus.offline,
          updatedAt: now.subtract(const Duration(minutes: 14)),
        ),
        CollectorSensor(
          id: 'pacific-04',
          collectorId: 'fjellfisk-collector',
          name: 'Pacific 04',
          status: CollectorSensorStatus.live,
          updatedAt: now.subtract(const Duration(seconds: 11)),
          temperatureC: 8.74,
          oxygenMgL: 13.02,
          oxygenSaturationPct: 112,
        ),
      ];
}
