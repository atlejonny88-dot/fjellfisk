import 'package:fjellfisk/services/dashboard_snapshot_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the last complete dashboard when a refresh fails', () async {
    final cache = DashboardSnapshotCache<String>();

    expect(await cache.load(() async => 'complete dashboard'),
        'complete dashboard');
    await expectLater(
      cache.load(() async => throw StateError('temporary outage')),
      throwsStateError,
    );

    expect(cache.value, 'complete dashboard');
    expect(cache.lastRefreshError, isA<StateError>());
  });

  test('a successful retry replaces the snapshot and clears the error',
      () async {
    final cache = DashboardSnapshotCache<int>();
    await cache.load(() async => 1);
    await expectLater(
        cache.load(() async => throw Exception()), throwsException);

    expect(await cache.load(() async => 2), 2);
    expect(cache.value, 2);
    expect(cache.lastRefreshError, isNull);
  });
}
