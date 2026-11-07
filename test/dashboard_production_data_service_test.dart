import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';
import 'package:fjellfisk/services/dashboard_production_data_service.dart';
import 'package:fjellfisk/services/remote_addon_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements FirebaseIdTokenProvider {
  const _Token();

  @override
  Future<String?> getIdToken() async => 'test-token';
}

void main() {
  final now = DateTime(2026, 11, 5, 10, 30);

  test('uses recent and today-only records without reading empty tanks',
      () async {
    final source = _FakeDashboardSource(
      sections: const [DashboardSectionRecord(id: 'section-1', name: 'A')],
      tanks: const {
        'section-1': [
          DashboardTankRecord(id: 'active', fishCount: 100),
          DashboardTankRecord(id: 'empty', fishCount: 0),
        ],
      },
      recentLogs: const {
        'section-1/active': [
          {'avgWeightGram': 250.0},
        ],
      },
      todayLogs: {
        'section-1/active': [
          {'date': Timestamp.fromDate(now), 'feedKg': 2.5, 'mortality': 3},
        ],
      },
    );
    final service = DashboardProductionDataService(
      source: source,
      clock: () => now,
    );

    final dashboard = await service.load(facilityId: 'facility-1');

    expect(dashboard['activeTanks'], 1);
    expect(dashboard['emptyTanks'], 1);
    expect(dashboard['fish'], 100);
    expect(dashboard['biomassKg'], 25.0);
    expect(dashboard['recommendedFeedKg'], 0.25);
    expect(dashboard['feedTodayKg'], 2.5);
    expect(dashboard['mortalityToday'], 3);
    expect(source.recentLogRequests, ['section-1/active']);
    expect(source.todayLogRequests, ['section-1/active']);
  });

  test('bounds concurrent active-tank reads during repeated dashboard loads',
      () async {
    final source = _FakeDashboardSource(
      sections: const [DashboardSectionRecord(id: 'section-1', name: 'A')],
      tanks: {
        'section-1': List.generate(
          7,
          (index) => DashboardTankRecord(id: 'tank-$index', fishCount: 10),
        ),
      },
      delayRecentReads: const Duration(milliseconds: 20),
    );
    final service = DashboardProductionDataService(
      source: source,
      clock: () => now,
      maxConcurrentTankLoads: 2,
    );

    await service.load(facilityId: 'facility-1');
    await service.load(facilityId: 'facility-1', forceServer: true);

    expect(source.maxConcurrentRecentReads, lessThanOrEqualTo(2));
    expect(source.recentLogRequests, hasLength(14));
  });

  test('reports the exact Firestore operation that times out', () async {
    final delayedTodayLogs = Completer<List<Map<String, dynamic>>>();
    final source = _FakeDashboardSource(
      sections: const [DashboardSectionRecord(id: 'section-1', name: 'A')],
      tanks: const {
        'section-1': [DashboardTankRecord(id: 'tank-1', fishCount: 10)],
      },
      todayLogsLoader: (_, __) => delayedTodayLogs.future,
    );
    final service = DashboardProductionDataService(
      source: source,
      clock: () => now,
      readTimeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      service.load(facilityId: 'facility-1'),
      throwsA(
        isA<DashboardDataLoadException>()
            .having((error) => error.operation, 'operation',
                DashboardLoadOperation.todayLogs)
            .having((error) => error.isTimeout, 'isTimeout', isTrue),
      ),
    );
  });

  test('classifies a temporary Firestore outage without involving Collector',
      () async {
    final source = _FakeDashboardSource(
      sections: const [DashboardSectionRecord(id: 'section-1', name: 'A')],
      tanks: const {
        'section-1': [DashboardTankRecord(id: 'tank-1', fishCount: 10)],
      },
      todayLogsLoader: (_, __) => Future.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
    );
    final service = DashboardProductionDataService(
      source: source,
      clock: () => now,
    );

    await expectLater(
      service.load(facilityId: 'facility-1'),
      throwsA(
        isA<DashboardDataLoadException>()
            .having((error) => error.operation, 'operation',
                DashboardLoadOperation.todayLogs)
            .having(
              (error) => error.category,
              'category',
              'firestore-unavailable',
            ),
      ),
    );
  });

  test(
      'dashboard Firestore data stays independent from a stalled Collector API',
      () async {
    final pendingCollectorResponse = Completer<http.Response>();
    final collector = RemoteAddOnService(
      facilityId: 'facility-1',
      api: CollectorClaimService(
        backendUrl: 'https://collector.example/collector/v1',
        tokenProvider: const _Token(),
        client: MockClient((_) => pendingCollectorResponse.future),
      ),
    );
    final dashboardService = DashboardProductionDataService(
      source: _FakeDashboardSource(
        sections: const [
          DashboardSectionRecord(id: 'section-1', name: 'A'),
        ],
        tanks: const {
          'section-1': [DashboardTankRecord(id: 'tank-1', fishCount: 10)],
        },
      ),
      clock: () => now,
    );

    final collectorRefresh = collector.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(collector.isRefreshing, isTrue);

    final dashboard = await dashboardService.load(facilityId: 'facility-1');
    expect(dashboard['activeTanks'], 1);

    collector.dispose();
    pendingCollectorResponse.complete(http.Response('[]', 200));
    await collectorRefresh;
  });

  test('Firestore source limits latest weights and queries only today for KPIs',
      () async {
    final firestore = FakeFirebaseFirestore();
    final logs = firestore
        .collection('facilities')
        .doc('facility-1')
        .collection('sections')
        .doc('section-1')
        .collection('tanks')
        .doc('tank-1')
        .collection('logs');
    final startOfToday = DateTime(now.year, now.month, now.day);
    for (var index = 0; index < 51; index++) {
      await logs.doc('recent-$index').set({
        'date': Timestamp.fromDate(now.subtract(Duration(minutes: index))),
        'avgWeightGram': index + 1,
      });
    }
    await logs.doc('yesterday').set({
      'date':
          Timestamp.fromDate(startOfToday.subtract(const Duration(days: 1))),
      'feedKg': 99,
    });
    await logs.doc('today').set({
      'date': Timestamp.fromDate(startOfToday.add(const Duration(hours: 1))),
      'feedKg': 2,
    });
    final source = FirestoreDashboardProductionDataSource(firestore);

    final recent = await source.fetchRecentLogs(
      facilityId: 'facility-1',
      sectionId: 'section-1',
      tankId: 'tank-1',
      forceServer: false,
    );
    final today = await source.fetchTodayLogs(
      facilityId: 'facility-1',
      sectionId: 'section-1',
      tankId: 'tank-1',
      from: startOfToday,
      to: now,
      forceServer: false,
    );

    expect(recent, hasLength(50));
    expect(today.where((log) => log['feedKg'] == 99), isEmpty);
    expect(today.where((log) => log['feedKg'] == 2), hasLength(1));
  });
}

class _FakeDashboardSource implements DashboardProductionDataSource {
  _FakeDashboardSource({
    this.sections = const [],
    this.tanks = const {},
    this.recentLogs = const {},
    this.todayLogs = const {},
    this.delayRecentReads,
    this.todayLogsLoader,
  });

  final List<DashboardSectionRecord> sections;
  final Map<String, List<DashboardTankRecord>> tanks;
  final Map<String, List<Map<String, dynamic>>> recentLogs;
  final Map<String, List<Map<String, dynamic>>> todayLogs;
  final Duration? delayRecentReads;
  final Future<List<Map<String, dynamic>>> Function(
    String sectionId,
    String tankId,
  )? todayLogsLoader;

  final recentLogRequests = <String>[];
  final todayLogRequests = <String>[];
  var _concurrentRecentReads = 0;
  var maxConcurrentRecentReads = 0;

  @override
  Future<List<DashboardSectionRecord>> fetchSections({
    required String facilityId,
    required bool forceServer,
  }) async =>
      sections;

  @override
  Future<List<DashboardTankRecord>> fetchTanks({
    required String facilityId,
    required String sectionId,
    required bool forceServer,
  }) async =>
      tanks[sectionId] ?? const [];

  @override
  Future<List<Map<String, dynamic>>> fetchRecentLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required bool forceServer,
  }) async {
    recentLogRequests.add('$sectionId/$tankId');
    _concurrentRecentReads++;
    maxConcurrentRecentReads = maxConcurrentRecentReads < _concurrentRecentReads
        ? _concurrentRecentReads
        : maxConcurrentRecentReads;
    try {
      final delay = delayRecentReads;
      if (delay != null) await Future<void>.delayed(delay);
      return recentLogs['$sectionId/$tankId'] ?? const [];
    } finally {
      _concurrentRecentReads--;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTodayLogs({
    required String facilityId,
    required String sectionId,
    required String tankId,
    required DateTime from,
    required DateTime to,
    required bool forceServer,
  }) {
    todayLogRequests.add('$sectionId/$tankId');
    final loader = todayLogsLoader;
    if (loader != null) return loader(sectionId, tankId);
    return Future.value(todayLogs['$sectionId/$tankId'] ?? const []);
  }
}
