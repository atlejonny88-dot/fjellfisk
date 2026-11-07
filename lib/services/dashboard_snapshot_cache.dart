/// Retains the last complete dashboard result when a later refresh has a
/// temporary network or Firebase failure.
class DashboardSnapshotCache<T> {
  T? _value;
  Object? _lastRefreshError;

  T? get value => _value;
  Object? get lastRefreshError => _lastRefreshError;

  Future<T> load(Future<T> Function() loader) async {
    try {
      final next = await loader();
      _value = next;
      _lastRefreshError = null;
      return next;
    } catch (error) {
      _lastRefreshError = error;
      rethrow;
    }
  }

  void clearError() => _lastRefreshError = null;
}
