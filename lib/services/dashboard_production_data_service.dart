import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/data_values.dart';
import '../utils/tank_status.dart';
import 'dashboard_temperature_service.dart';

/// A narrow, testable read model for the production figures on the dashboard.
///
/// Collector data deliberately does not participate here. A Collector outage
/// must not prevent the ordinary Firestore dashboard from loading.
abstract interface class DashboardProductionDataSource {
  Future<List<DashboardSectionRecord>> fetchSections({
    required String facilityId,
    required bool forceServer,
  });

  Future<List<DashboardTankRecord>> fetchTanks({
    required String facilityId,
    required String sectionId,
    required bool forceServer,
  });

  Future<List<Map<String, dynamic>>> fetchRecentLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required bool forceServer,
  });

  Future<List<Map<String, dynamic>>> fetchTodayLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required DateTime from,
    required DateTime to,
    required bool forceServer,
  });
}

class DashboardSectionRecord {
  const DashboardSectionRecord({required this.id, required this.name});

  final String id;
  final String name;
}

class DashboardTankRecord {
  const DashboardTankRecord({required this.id, required this.fishCount});

  final String id;
  final int fishCount;
}

/// Firestore implementation of the limited dashboard read model.
class FirestoreDashboardProductionDataSource
    implements DashboardProductionDataSource {
  FirestoreDashboardProductionDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sectionsRef(String facilityId) =>
      _firestore
          .collection('facilities')
          .doc(facilityId)
          .collection('sections');

  CollectionReference<Map<String, dynamic>> _logsRef({
    required String facilityId,
    required String sectionId,
    required String tankId,
  }) =>
      _sectionsRef(facilityId)
          .doc(sectionId)
          .collection('tanks')
          .doc(tankId)
          .collection('logs');

  @override
  Future<List<DashboardSectionRecord>> fetchSections({
    required String facilityId,
    required bool forceServer,
  }) async {
    final snapshot = await _readQuery(
      _sectionsRef(facilityId),
      forceServer: forceServer,
    );
    return snapshot.docs
        .map(
          (document) => DashboardSectionRecord(
            id: document.id,
            name: (document.data()['name'] ?? document.id).toString(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DashboardTankRecord>> fetchTanks({
    required String facilityId,
    required String sectionId,
    required bool forceServer,
  }) async {
    final snapshot = await _readQuery(
      _sectionsRef(facilityId).doc(sectionId).collection('tanks'),
      forceServer: forceServer,
    );
    return snapshot.docs
        .map(
          (document) => DashboardTankRecord(
            id: document.id,
            fishCount: TankStatus.fishCountFrom(document.data()['fishCount']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecentLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required bool forceServer,
  }) async {
    final snapshot = await _readQuery(
      _logsRef(
        facilityId: facilityId,
        sectionId: sectionId,
        tankId: tankId,
      ).orderBy('date', descending: true).limit(50),
      forceServer: forceServer,
    );
    return snapshot.docs.map((document) => document.data()).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTodayLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required DateTime from,
    required DateTime to,
    required bool forceServer,
  }) async {
    final snapshot = await _readQuery(
      _logsRef(
        facilityId: facilityId,
        sectionId: sectionId,
        tankId: tankId,
      )
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to)),
      forceServer: forceServer,
    );
    return snapshot.docs.map((document) => document.data()).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _readQuery(
    Query<Map<String, dynamic>> query, {
    required bool forceServer,
  }) async {
    if (!forceServer) return query.get();

    try {
      return await query.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable' &&
          error.code != 'deadline-exceeded' &&
          error.code != 'network-request-failed') {
        rethrow;
      }
      return query.get(const GetOptions(source: Source.cache));
    }
  }
}

enum DashboardLoadOperation {
  sections,
  tanks,
  recentLogs,
  todayLogs,
}

/// Identifies the exact bounded Firestore operation that failed.
class DashboardDataLoadException implements Exception {
  const DashboardDataLoadException({
    required this.operation,
    required this.elapsed,
    required this.cause,
  });

  final DashboardLoadOperation operation;
  final Duration elapsed;
  final Object cause;

  bool get isTimeout => cause is TimeoutException;

  String get category {
    if (cause is TimeoutException) return 'timeout';
    if (cause is FirebaseException) {
      return 'firestore-${(cause as FirebaseException).code}';
    }
    return 'read-error';
  }

  @override
  String toString() =>
      'DashboardDataLoadException(operation: ${operation.name}, '
      'category: $category, elapsedMs: ${elapsed.inMilliseconds})';
}

/// Loads only the dashboard data that is needed for the current day.
///
/// Earlier versions scanned every historical log for each active tank in
/// sequence. This keeps the latest-weight query bounded, asks Firestore only
/// for today's feed/mortality entries, and limits concurrent tank requests.
class DashboardProductionDataService {
  DashboardProductionDataService({
    required DashboardProductionDataSource source,
    DateTime Function()? clock,
    this.readTimeout = const Duration(seconds: 10),
    this.maxConcurrentTankLoads = 6,
  })  : _source = source,
        _clock = clock ?? DateTime.now,
        assert(maxConcurrentTankLoads > 0);

  final DashboardProductionDataSource _source;
  final DateTime Function() _clock;
  final Duration readTimeout;
  final int maxConcurrentTankLoads;

  Future<Map<String, dynamic>> load({
    required String facilityId,
    bool forceServer = false,
  }) async {
    final now = _clock();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final sections = await _read(
      DashboardLoadOperation.sections,
      () => _source.fetchSections(
        facilityId: facilityId,
        forceServer: forceServer,
      ),
    );
    final tankLists =
        await _mapConcurrent<DashboardSectionRecord, List<DashboardTankRecord>>(
      sections,
      maxConcurrent: maxConcurrentTankLoads,
      task: (section) => _read(
        DashboardLoadOperation.tanks,
        () => _source.fetchTanks(
          facilityId: facilityId,
          sectionId: section.id,
          forceServer: forceServer,
        ),
      ),
    );

    final activeTanks = <_ActiveTank>[];
    final activeTemperatureTanks = <DashboardTemperatureTankKey>{};
    var totalTanks = 0;
    var emptyTanks = 0;
    var totalFish = 0;

    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      for (final tank in tankLists[sectionIndex]) {
        totalTanks++;
        if (!TankStatus.isActiveFishCount(tank.fishCount)) {
          emptyTanks++;
          continue;
        }
        totalFish += tank.fishCount;
        activeTemperatureTanks.add(
          DashboardTemperatureTankKey(sectionId: section.id, tankId: tank.id),
        );
        activeTanks.add(_ActiveTank(section: section, tank: tank));
      }
    }

    final metrics = await _mapConcurrent<_ActiveTank, _TankMetrics>(
      activeTanks,
      maxConcurrent: maxConcurrentTankLoads,
      task: (activeTank) => _loadTankMetrics(
        facilityId: facilityId,
        activeTank: activeTank,
        startOfToday: startOfToday,
        now: now,
        forceServer: forceServer,
      ),
    );
    final metricsByTank = <String, _TankMetrics>{
      for (var index = 0; index < activeTanks.length; index++)
        _tankKey(activeTanks[index].section.id, activeTanks[index].tank.id):
            metrics[index],
    };

    var totalBiomassKg = 0.0;
    var recommendedFeedKg = 0.0;
    var feedTodayKg = 0.0;
    var mortalityToday = 0;
    final sectionRows = <Map<String, dynamic>>[];

    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
      final section = sections[sectionIndex];
      final tanks = tankLists[sectionIndex];
      var sectionActiveTanks = 0;
      var sectionFish = 0;
      var sectionBiomassKg = 0.0;
      var sectionFeedKg = 0.0;

      for (final tank in tanks) {
        if (!TankStatus.isActiveFishCount(tank.fishCount)) continue;
        sectionActiveTanks++;
        sectionFish += tank.fishCount;
        final metrics = metricsByTank[_tankKey(section.id, tank.id)]!;
        sectionBiomassKg += metrics.biomassKg;
        sectionFeedKg += metrics.recommendedFeedKg;
        totalBiomassKg += metrics.biomassKg;
        recommendedFeedKg += metrics.recommendedFeedKg;
        feedTodayKg += metrics.feedTodayKg;
        mortalityToday += metrics.mortalityToday;
      }

      sectionRows.add({
        'id': section.id,
        'name': section.name,
        'tanks': tanks.length,
        'activeTanks': sectionActiveTanks,
        'emptyTanks': tanks.length - sectionActiveTanks,
        'fish': sectionFish,
        'biomassKg': sectionBiomassKg,
        'recommendedFeedKg': sectionFeedKg,
      });
    }

    return {
      'sections': sections.length,
      'tanks': totalTanks,
      'activeTanks': activeTanks.length,
      'emptyTanks': emptyTanks,
      'fish': totalFish,
      'biomassKg': totalBiomassKg,
      'recommendedFeedKg': recommendedFeedKg,
      'mortalityToday': mortalityToday,
      'feedTodayKg': feedTodayKg,
      'activeTemperatureTanks': activeTemperatureTanks,
      'sectionRows': sectionRows,
    };
  }

  Future<_TankMetrics> _loadTankMetrics({
    required String facilityId,
    required _ActiveTank activeTank,
    required DateTime startOfToday,
    required DateTime now,
    required bool forceServer,
  }) async {
    final results = await Future.wait([
      _read(
        DashboardLoadOperation.recentLogs,
        () => _source.fetchRecentLogs(
          facilityId: facilityId,
          sectionId: activeTank.section.id,
          tankId: activeTank.tank.id,
          forceServer: forceServer,
        ),
      ),
      _read(
        DashboardLoadOperation.todayLogs,
        () => _source.fetchTodayLogs(
          facilityId: facilityId,
          sectionId: activeTank.section.id,
          tankId: activeTank.tank.id,
          from: startOfToday,
          to: now,
          forceServer: forceServer,
        ),
      ),
    ]);
    final recentLogs = results[0];
    final todayLogs = results[1];
    final averageWeight = _latestWeight(recentLogs);
    final biomassKg = _biomassKg(activeTank.tank.fishCount, averageWeight);
    var feedTodayKg = 0.0;
    var mortalityToday = 0;

    for (final log in todayLogs) {
      final date = _dateFrom(log['date']);
      if (date == null || date.isBefore(startOfToday) || date.isAfter(now)) {
        continue;
      }
      feedTodayKg += DataValues.decimal(log['feedKg']);
      mortalityToday += DataValues.integer(log['mortality'] ?? log['dead']);
    }

    return _TankMetrics(
      biomassKg: biomassKg,
      recommendedFeedKg: biomassKg * (_feedPercent(averageWeight) / 100),
      feedTodayKg: feedTodayKg,
      mortalityToday: mortalityToday,
    );
  }

  Future<T> _read<T>(
    DashboardLoadOperation operation,
    Future<T> Function() read,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await read().timeout(readTimeout);
    } on DashboardDataLoadException {
      rethrow;
    } catch (error) {
      throw DashboardDataLoadException(
        operation: operation,
        elapsed: stopwatch.elapsed,
        cause: error,
      );
    }
  }

  static Future<List<R>> _mapConcurrent<T, R>(
    List<T> items, {
    required int maxConcurrent,
    required Future<R> Function(T item) task,
  }) async {
    if (items.isEmpty) return const [];

    final results = List<R?>.filled(items.length, null);
    var nextIndex = 0;
    Object? failure;
    StackTrace? failureStackTrace;

    Future<void> worker() async {
      while (failure == null && nextIndex < items.length) {
        final index = nextIndex++;
        try {
          results[index] = await task(items[index]);
        } catch (error, stackTrace) {
          failure = error;
          failureStackTrace = stackTrace;
        }
      }
    }

    await Future.wait([
      for (var index = 0;
          index < math.min(maxConcurrent, items.length);
          index++)
        worker(),
    ]);
    if (failure != null) {
      Error.throwWithStackTrace(failure!, failureStackTrace!);
    }
    return results.cast<R>();
  }

  static String _tankKey(String sectionId, String tankId) =>
      '$sectionId/$tankId';

  static double _latestWeight(List<Map<String, dynamic>> logs) {
    for (final log in logs) {
      final weight = DataValues.weight(log);
      if (weight > 0) return weight;
    }
    return 0;
  }

  static DateTime? _dateFrom(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  static double _biomassKg(int fishCount, double averageWeightGram) =>
      fishCount <= 0 || averageWeightGram <= 0
          ? 0
          : fishCount * averageWeightGram / 1000;

  static double _feedPercent(double weight) {
    if (weight <= 0) return 0;
    if (weight < 100) return 1.5;
    if (weight < 300) return 1.0;
    if (weight < 1000) return 0.8;
    return 0.6;
  }
}

class _ActiveTank {
  const _ActiveTank({required this.section, required this.tank});

  final DashboardSectionRecord section;
  final DashboardTankRecord tank;
}

class _TankMetrics {
  const _TankMetrics({
    required this.biomassKg,
    required this.recommendedFeedKg,
    required this.feedTodayKg,
    required this.mortalityToday,
  });

  final double biomassKg;
  final double recommendedFeedKg;
  final double feedTodayKg;
  final int mortalityToday;
}
