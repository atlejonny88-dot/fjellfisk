import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/services/dashboard_temperature_service.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/widgets/dashboard_temperature_kpi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _keyA =
    DashboardTemperatureTankKey(sectionId: 'section-a', tankId: 'tank-a');
const _keyB =
    DashboardTemperatureTankKey(sectionId: 'section-a', tankId: 'tank-b');
const _keyC =
    DashboardTemperatureTankKey(sectionId: 'section-b', tankId: 'tank-c');

CollectorSensorMapping _mapping(
        DashboardTemperatureTankKey key, String sensorId) =>
    CollectorSensorMapping(
      collectorId: 'collector-1',
      sensorId: sensorId,
      facilityId: 'facility-a',
      sectionId: key.sectionId,
      sectionName: key.sectionId,
      tankId: key.tankId,
      tankName: key.tankId,
    );

CollectorSensor _sensor(
  String id,
  double? temperature, {
  CollectorSensorStatus status = CollectorSensorStatus.live,
}) =>
    CollectorSensor(
      id: id,
      collectorId: 'collector-1',
      name: id,
      status: status,
      updatedAt: DateTime.utc(2026, 11, 3, 12),
      temperatureC: temperature,
    );

DashboardTemperatureSummary _summary({
  required DashboardTemperatureConfiguration configuration,
  required List<CollectorSensorMapping> mappings,
  required Map<String, CollectorSensor> sensors,
  Set<DashboardTemperatureTankKey>? active,
}) =>
    DashboardTemperatureCalculator.calculate(
      configuration: configuration,
      mappings: mappings,
      activeTanks: active ?? {_keyA, _keyB, _keyC},
      sensorForMapping: (mapping) => sensors[mapping.sensorId],
    );

void main() {
  group('dashboard temperature calculator', () {
    test('uses only the selected mapped tanks', () {
      final result = _summary(
        configuration: DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: {_keyA, _keyB},
        ),
        mappings: [
          _mapping(_keyA, 'a'),
          _mapping(_keyB, 'b'),
          _mapping(_keyC, 'c')
        ],
        sensors: {
          'a': _sensor('a', 10.7),
          'b': _sensor('b', 10.1),
          'c': _sensor('c', 28.0),
        },
      );

      expect(result.state, DashboardTemperatureState.live);
      expect(result.includedTankCount, 2);
      expect(result.roundedTemperatureC, 10.4);
    });

    test('does not count a tank twice when it has duplicate mappings', () {
      final result = _summary(
        configuration: DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: {_keyA},
        ),
        mappings: [_mapping(_keyA, 'first'), _mapping(_keyA, 'second')],
        sensors: {
          'first': _sensor('first', 9.9),
          'second': _sensor('second', 15),
        },
      );

      expect(result.includedTankCount, 1);
      expect(result.roundedTemperatureC, 9.9);
    });

    test(
        'excludes stale, offline and missing readings without temperature bounds',
        () {
      final result = _summary(
        configuration: DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: {_keyA, _keyB, _keyC},
        ),
        mappings: [
          _mapping(_keyA, 'a'),
          _mapping(_keyB, 'b'),
          _mapping(_keyC, 'c')
        ],
        sensors: {
          'a': _sensor('a', 25),
          'b': _sensor('b', 8.2, status: CollectorSensorStatus.stale),
          'c': _sensor('c', null, status: CollectorSensorStatus.offline),
        },
      );

      expect(result.state, DashboardTemperatureState.live);
      expect(result.includedTankCount, 1);
      expect(result.roundedTemperatureC, 25);
    });

    test('reports not configured for an explicit empty selection', () {
      final result = _summary(
        configuration: DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: {},
        ),
        mappings: [_mapping(_keyA, 'a')],
        sensors: {'a': _sensor('a', 9)},
      );

      expect(result.state, DashboardTemperatureState.notConfigured);
    });

    test('reports no data when selected sources have no valid live reading',
        () {
      final result = _summary(
        configuration: DashboardTemperatureConfiguration(
          isConfigured: true,
          selectedTanks: {_keyA},
        ),
        mappings: [_mapping(_keyA, 'a')],
        sensors: {'a': _sensor('a', 9, status: CollectorSensorStatus.stale)},
      );

      expect(result.state, DashboardTemperatureState.noData);
    });

    test('uses mapped active tanks as a temporary default before configuration',
        () {
      final result = _summary(
        configuration: const DashboardTemperatureConfiguration.unconfigured(),
        mappings: [_mapping(_keyA, 'a'), _mapping(_keyB, 'b')],
        sensors: {'a': _sensor('a', 9), 'b': _sensor('b', 11)},
        active: {_keyA},
      );

      expect(result.state, DashboardTemperatureState.live);
      expect(result.usesDefaultSelection, isTrue);
      expect(result.roundedTemperatureC, 9);
    });
  });

  test('configuration persists independently for each facility', () async {
    final firestore = FakeFirebaseFirestore();
    final store = FirestoreDashboardTemperatureConfigurationStore(
      firestore: firestore,
    );
    await store.save(
      'facility-a',
      DashboardTemperatureConfiguration(
        isConfigured: true,
        selectedTanks: {_keyA, _keyB},
      ),
    );
    await store.save(
      'facility-b',
      DashboardTemperatureConfiguration(
        isConfigured: true,
        selectedTanks: {_keyC},
      ),
    );

    expect((await store.load('facility-a')).selectedTanks, {_keyA, _keyB});
    expect((await store.load('facility-b')).selectedTanks, {_keyC});
  });

  testWidgets('KPI updates when the existing live sensor service changes',
      (tester) async {
    final service = _LiveService(10.1);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            LanguageScope(controller: LanguageController(), child: child!),
        home: Scaffold(
          body: DashboardTemperatureKpi(
            service: service,
            facilityId: 'facility-a',
            configuration: DashboardTemperatureConfiguration(
              isConfigured: true,
              selectedTanks: {_keyA},
            ),
            activeTanks: {_keyA},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10,1 °C'), findsOneWidget);

    service.setTemperature(12.26);
    await tester.pumpAndSettle();
    expect(find.text('12,3 °C'), findsOneWidget);
  });
}

class _LiveService extends AddOnService {
  _LiveService(double temperature) : _temperature = temperature;

  double _temperature;

  @override
  List<AddOn> get addOns => const [
        AddOn(
          id: 'collector-1',
          type: AddOnType.collector,
          name: 'Collector',
          description: '',
          status: AddOnStatus.connected,
        ),
      ];

  @override
  List<CollectorSensorMapping> mappingsForCollector(String collectorId) =>
      [_mapping(_keyA, 'sensor-a')];

  @override
  CollectorSensor? sensorForTank({
    required String facilityId,
    required String sectionId,
    required String sectionName,
    required String tankId,
    required String tankName,
  }) =>
      _sensor('sensor-a', _temperature);

  void setTemperature(double value) {
    _temperature = value;
    notifyListeners();
  }

  @override
  Future<ClaimCodeResult> claimCollector(String claimCode) async =>
      const ClaimCodeResult(ClaimCodeResultType.invalid);

  @override
  Future<void> disconnect(String addOnId) async {}

  @override
  Future<void> saveCollectorMappings(
    String collectorId,
    Iterable<CollectorSensorMapping> mappings,
  ) async {}

  @override
  List<CollectorSensor> sensorsForCollector(String collectorId) => const [];
}
