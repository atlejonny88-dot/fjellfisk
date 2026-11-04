import 'dart:convert';

import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/screens/collector_setup_screen.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';
import 'package:fjellfisk/services/remote_addon_service.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Token implements FirebaseIdTokenProvider {
  @override
  Future<String?> getIdToken() async => 'test-token';
}

void main() {
  late CollectorClaimService api;
  var mappings = <Map<String, dynamic>>[];
  var saveFails = false;
  var health = 'ok';
  var backendUnavailable = false;
  late String timestamp;
  setUp(() {
    mappings = [];
    saveFails = false;
    health = 'ok';
    backendUnavailable = false;
    timestamp = DateTime.now().toUtc().toIso8601String();
    api = CollectorClaimService(
      backendUrl: 'https://collector.example',
      tokenProvider: _Token(),
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-token');
        if (backendUnavailable) {
          return http.Response('{"error":{"code":"UNAVAILABLE"}}', 503);
        }
        if (request.method == 'POST') {
          expect(
              request.url.path, '/admin/v1/collectors/real-collector/mappings');
          if (saveFails) return http.Response('{}', 403);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['siteId'], 'facility-a');
          mappings = (body['mappings'] as List).cast<Map<String, dynamic>>();
          return http.Response('{"saved":1}', 200);
        }
        if (request.url.path.endsWith('/sensors')) {
          return http.Response(
              jsonEncode({
                'sensors': [
                  {
                    'sensorId': 'real-probe',
                    'name': 'Pacific 01 / Probe 01',
                    'timestampUtc': timestamp,
                    'health': health,
                    'temperatureC': 9.52,
                    'oxygenMgL': 11.66,
                    'oxygenSaturationPct': 101.85
                  }
                ],
                'mappings': mappings,
              }),
              200);
        }
        return http.Response(
            jsonEncode([
              {
                'collectorId': 'real-collector',
                'state': 'PAIRED',
                'lastSeenAt': timestamp
              }
            ]),
            200);
      }),
    );
  });

  RemoteAddOnService service() => RemoteAddOnService(
      api: api,
      facilityId: 'facility-a',
      sectionLoader: () async => const [
            CollectorSectionOption(
                id: 'section-real',
                name: 'Tunnel ekte',
                tanks: [CollectorTankOption(id: 'tank-real', name: 'Kar ekte')])
          ]);

  Widget app(RemoteAddOnService remote,
          {Locale locale = const Locale('nb'), String role = 'admin'}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            LanguageScope(controller: LanguageController(), child: child!),
        home: CollectorSetupScreen(
            service: remote,
            collectorId: 'real-collector',
            roleLoader: () async => role),
      );

  test(
      'real readings and mappings persist across service restart with strict facility isolation',
      () async {
    final remote = service();
    await remote.refresh();
    final sensor = remote.sensorsForCollector('real-collector').single;
    expect(sensor.temperatureC, 9.52);
    expect(sensor.oxygenMgL, 11.66);
    expect(sensor.oxygenSaturationPct, 101.85);
    expect(remote.addOns.single.sensorCount, 1);
    await remote.saveCollectorMappings('real-collector', const [
      CollectorSensorMapping(
          collectorId: 'real-collector',
          sensorId: 'real-probe',
          facilityId: 'facility-a',
          sectionId: 'section-real',
          sectionName: 'Tunnel ekte',
          tankId: 'tank-real',
          tankName: 'Kar ekte')
    ]);
    remote.dispose();
    final restarted = service();
    await restarted.refresh();
    expect(
        restarted
            .sensorForTank(
                facilityId: 'facility-a',
                sectionId: 'section-real',
                sectionName: 'Renamed',
                tankId: 'tank-real',
                tankName: 'Renamed')
            ?.oxygenMgL,
        11.66);
    expect(
        restarted.sensorForTank(
            facilityId: 'facility-b',
            sectionId: 'section-real',
            sectionName: 'Tunnel ekte',
            tankId: 'tank-real',
            tankName: 'Kar ekte'),
        isNull);
    restarted.dispose();
  });

  test('old collector is offline and stale sensor data never appears live',
      () async {
    timestamp = DateTime.now()
        .subtract(const Duration(days: 3))
        .toUtc()
        .toIso8601String();
    final remote = service();
    await remote.refresh();
    expect(remote.addOns.single.status, AddOnStatus.offline);
    expect(remote.sensorsForCollector('real-collector').single.status,
        CollectorSensorStatus.offline);
    remote.dispose();
  });

  test('delayed heartbeat remains paired and keeps setup available', () async {
    timestamp = DateTime.now()
        .subtract(const Duration(minutes: 2))
        .toUtc()
        .toIso8601String();
    final remote = service();

    await remote.refresh();

    expect(remote.addOns.single.status, AddOnStatus.delayed);
    expect(remote.addOns.single.isConnected, isTrue);
    expect(remote.addOns.single.canConfigure, isTrue);
    remote.dispose();
  });

  test('temporary API failure retains the last known sensor state', () async {
    final remote = service();
    await remote.refresh();

    backendUnavailable = true;
    await remote.refresh();

    expect(remote.loadError, ClaimCodeResultType.unavailable);
    expect(remote.addOns.single.status, AddOnStatus.connected);
    expect(remote.sensorsForCollector('real-collector').single.status,
        CollectorSensorStatus.live);
    remote.dispose();
  });

  testWidgets('paired collector separates failed sensor reads from connection',
      (tester) async {
    health = 'failed';
    final remote = service();
    await remote.refresh();

    await tester.pumpWidget(app(remote));
    await tester.pumpAndSettle();

    expect(remote.sensorsForCollector('real-collector').single.status,
        CollectorSensorStatus.failed);
    expect(find.text('Tilkoblet'), findsOneWidget);
    expect(find.text('Feilet'), findsOneWidget);
    expect(
      find.text(
          'Collector er tilkoblet, men klarer ikke å lese sensorverdiene.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    remote.dispose();
  });

  testWidgets('Setup chooses actual sections and tanks and saves to backend',
      (tester) async {
    final remote = service();
    await remote.refresh();
    await tester.pumpWidget(app(remote));
    await tester.pumpAndSettle();
    expect(find.text('Pacific 01 / Probe 01'), findsOneWidget);
    expect(find.textContaining('11,7 mg/L'), findsOneWidget);
    expect(find.text('Hovedbygg'), findsNothing);
    final sectionField =
        find.byKey(const ValueKey('collector-setup-section-real-probe'));
    await tester.ensureVisible(sectionField);
    await tester.pumpAndSettle();
    await tester.tap(sectionField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunnel ekte').last);
    await tester.pumpAndSettle();
    final tankField =
        find.byKey(const ValueKey('collector-setup-tank-real-probe'));
    await tester.ensureVisible(tankField);
    await tester.pumpAndSettle();
    await tester.tap(tankField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kar ekte').last);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-collector-setup'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(mappings.single['tankId'], 'tank-real');
    expect(remote.mappingsForCollector('real-collector').single.sectionId,
        'section-real');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final clear = find.byKey(const ValueKey('clear-sensor-mapping-real-probe'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(mappings, isEmpty);
    expect(remote.sensorsForCollector('real-collector'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    remote.dispose();
  });

  for (final locale in [
    const Locale('nb'),
    const Locale('en'),
    const Locale('pl')
  ]) {
    testWidgets(
        'real sensors fit mobile ${locale.languageCode} without granting reader writes',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final remote = service();
      await remote.refresh();
      await tester.pumpWidget(app(remote, locale: locale, role: 'leser'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DropdownButtonFormField<String>>(find
                  .byKey(const ValueKey('collector-setup-section-real-probe')))
              .onChanged,
          isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      remote.dispose();
    });
  }
}
