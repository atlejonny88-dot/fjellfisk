import '../models/addon.dart';
import 'addon_service.dart';
import 'collector_claim_service.dart';

/// Uses the existing authenticated API. Pairing never supplies mock sensors.
class RemoteAddOnService extends AddOnService {
  RemoteAddOnService({required this.api, required this.facilityId});

  final CollectorClaimService api;
  final String facilityId;
  List<AddOn> _addOns = const [_unconnected];
  bool _refreshing = false;
  bool _disposed = false;
  ClaimCodeResultType? _loadError;
  Future<void>? _refreshFuture;

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
      if (!_disposed) {
        _addOns = collectors.isEmpty ? const [_unconnected] : collectors;
      }
    } on CollectorBackendException catch (error) {
      if (!_disposed) {
        _loadError = error.type;
        // Never retain enabled management controls after authorization fails.
        if (error.type == ClaimCodeResultType.unauthorized) {
          _addOns = const [_unconnected];
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
  List<CollectorSensor> sensorsForCollector(String collectorId) => const [];

  @override
  List<CollectorSensorMapping> mappingsForCollector(String collectorId) =>
      const [];

  @override
  CollectorSensor? sensorForTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  }) =>
      null;

  @override
  Future<void> saveCollectorMappings(
    String collectorId,
    Iterable<CollectorSensorMapping> mappings,
  ) async {
    // The pairing API does not provide sensor inventory/mapping persistence yet.
    throw const CollectorBackendException(ClaimCodeResultType.unavailable);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
