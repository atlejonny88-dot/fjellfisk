import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/widgets/tank_overview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tank card fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TankOverviewCard(
              name: 'Kar med et svært langt navn',
              isActive: true,
              fishCountLabel: '12 450 stk',
              biomassLabel: '48,32 tonn',
              weightLabel: '3 880,5 g',
              feedLabel: '412,5 kg',
              mortalityLabel: '3 stk',
              temperatureLabel: '12,4 °C',
              statusLabel: 'Aktiv',
              statusMessage: 'Alt innen normale verdier',
              statusColor: const Color(0xFF0BA765),
              statusIcon: Icons.check_circle,
              onTap: () {},
              onDelete: () {},
              reviewed: true,
              noteText: 'Kontroller filteret',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snittvekt'), findsOneWidget);
    expect(find.text('Fôr 24t'), findsOneWidget);
    expect(find.text('Døde 7d'), findsOneWidget);
    expect(find.text('Temperatur'), findsOneWidget);
    expect(find.text('Gjennomgått i denne økten'), findsOneWidget);
    expect(find.text('Kontroller filteret'), findsOneWidget);
    expect(find.text('Alt innen normale verdier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mapped collector sensor replaces only the temperature metric',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_tankApp(
      collectorSensor: CollectorSensor(
        id: 'pacific-01',
        collectorId: 'fjellfisk-collector',
        name: 'Pacific 01',
        status: CollectorSensorStatus.live,
        updatedAt: DateTime.now(),
        temperatureC: 8.6,
        oxygenMgL: 13.1,
        oxygenSaturationPct: 113,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Temperatur'), findsNothing);
    expect(find.text('Temp.'), findsOneWidget);
    expect(find.text('O₂'), findsOneWidget);
    expect(find.text('Metning'), findsOneWidget);
    expect(find.text('8,6 °C'), findsOneWidget);
    expect(find.text('13,1 mg/L'), findsOneWidget);
    expect(find.text('113 %'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale and offline collector states are distinct',
      (tester) async {
    await tester.pumpWidget(_tankApp(
      collectorSensor: CollectorSensor(
        id: 'pacific-02',
        collectorId: 'fjellfisk-collector',
        name: 'Pacific 02',
        status: CollectorSensorStatus.stale,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        temperatureC: 8.3,
        oxygenMgL: 12.8,
        oxygenSaturationPct: 110,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Forsinket'), findsOneWidget);

    await tester.pumpWidget(_tankApp(
      collectorSensor: CollectorSensor(
        id: 'pacific-03',
        collectorId: 'fjellfisk-collector',
        name: 'Pacific 03',
        status: CollectorSensorStatus.offline,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 14)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Collector offline'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}

Widget _tankApp({CollectorSensor? collectorSensor}) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('nb'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => LanguageScope(
        controller: LanguageController(),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TankOverviewCard(
            name: 'K1',
            isActive: true,
            fishCountLabel: '12 450 stk',
            biomassLabel: '48,32 tonn',
            weightLabel: '3 880,5 g',
            feedLabel: '412,5 kg',
            mortalityLabel: '3 stk',
            temperatureLabel: '12,4 °C',
            statusLabel: 'Aktiv',
            statusMessage: 'Alt innen normale verdier',
            statusColor: const Color(0xFF0BA765),
            statusIcon: Icons.check_circle,
            collectorSensor: collectorSensor,
            onTap: () {},
          ),
        ),
      ),
    );
