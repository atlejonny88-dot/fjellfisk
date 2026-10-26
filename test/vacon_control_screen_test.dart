import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/models/vacon_control.dart';
import 'package:fjellfisk/screens/addons_screen.dart';
import 'package:fjellfisk/screens/vacon_control_screen.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/services/vacon_control_service.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => LanguageScope(
          controller: LanguageController(),
          child: child!,
        ),
        home: home,
      );

  testWidgets('Add-ons shows VACON beside the existing Collector',
      (tester) async {
    await tester.pumpWidget(
      app(
        AddOnsScreen(
          service: MockAddOnService(claimDelay: () async {}),
          roleLoader: () async => 'admin',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fjellfisk Collector'), findsOneWidget);
    expect(find.text('VACON Control'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-vacon-control')));
    await tester.pumpAndSettle();
    expect(find.text('Simulert testmodus'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only an admin can use simulated command controls',
      (tester) async {
    final service = MockVaconControlService(clock: DateTime.now);
    await tester.pumpWidget(
      app(
        VaconControlScreen(
          facilityId: MockVaconControlService.defaultFacilityId,
          service: service,
          roleLoader: () async => 'leser',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final start = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('vacon-start-simulation-pump-01')),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('admin simulation shows confirmation and verified feedback',
      (tester) async {
    final now = DateTime.now().toUtc();
    final service = MockVaconControlService(
      clock: () => now,
      devices: [
        _device(now, facilityId: MockVaconControlService.defaultFacilityId),
      ],
    );
    await tester.pumpWidget(
      app(
        VaconControlScreen(
          facilityId: MockVaconControlService.defaultFacilityId,
          service: service,
          roleLoader: () async => 'admin',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stopFinder = find.byKey(const ValueKey('vacon-stop-device-1'));
    await tester.ensureVisible(stopFinder);
    await tester.pumpAndSettle();
    await tester.tap(stopFinder);
    await tester.pumpAndSettle();
    final confirmationDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: confirmationDialog,
        matching: find.text(
          'Fjernstyring av fysisk utstyr er deaktivert. Kun en kontrollert, godkjent idriftsettelse kan åpne den senere.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: confirmationDialog,
        matching: find.widgetWithText(FilledButton, 'Fortsett simulering'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Simulert kommando verifisert med readback.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uncommissioned device always keeps controls disabled',
      (tester) async {
    final now = DateTime.utc(2026, 10, 26, 10);
    final device = _device(now).copyWith(
      controlMode: VaconControlMode.disabled,
      telemetry: VaconTelemetry(
        measuredAt: now,
        quality: 'unavailable',
        running: false,
      ),
    );
    final service = MockVaconControlService(
      clock: () => now,
      devices: [device],
      entitlements: const [
        VaconEntitlement(facilityId: 'facility-a', enabled: true),
      ],
    );
    await tester.pumpWidget(
      app(
        VaconControlScreen(
          facilityId: 'facility-a',
          service: service,
          roleLoader: () async => 'admin',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('vacon-start-device-1')),
          )
          .onPressed,
      isNull,
    );
  });
}

VaconDevice _device(
  DateTime now, {
  String facilityId = 'facility-a',
}) =>
    VaconDevice(
      id: 'device-1',
      facilityId: facilityId,
      siteId: 'site-1',
      name: 'Simulert pumpe',
      modelProfile: MockVaconControlService.documentedSimulationProfile,
      endpointLabel: 'simulated-gateway.invalid',
      port: 502,
      unitId: 1,
      minHz: 20,
      maxHz: 50,
      pollingInterval: const Duration(seconds: 15),
      connection: VaconConnectionState.online,
      controlMode: VaconControlMode.simulationOnly,
      localInterlockSatisfied: true,
      telemetry: VaconTelemetry(
        measuredAt: now,
        quality: 'simulated',
        running: false,
        actualHz: 0,
        referenceHz: 20,
      ),
    );
