import 'dart:async';

import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/models/addon.dart';
import 'package:fjellfisk/screens/addons_screen.dart';
import 'package:fjellfisk/screens/collector_setup_screen.dart';
import 'package:fjellfisk/services/addon_service.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/widgets/dashboard_v3_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({
    required AddOnService service,
    required String role,
    Locale locale = const Locale('nb'),
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => LanguageScope(
        controller: LanguageController(),
        child: child!,
      ),
      home: AddOnsScreen(
        service: service,
        roleLoader: () async => role,
      ),
    );
  }

  MockAddOnService service({List<AddOn>? initialAddOns}) => MockAddOnService(
        initialAddOns: initialAddOns,
        claimDelay: () async {},
      );

  testWidgets('admin can pair the collector with the valid mock code',
      (tester) async {
    final mock = service();
    await tester.pumpWidget(app(service: mock, role: 'admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koble til collector'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fj-8k4p-2xq7');
    await tester.tap(find.widgetWithText(FilledButton, 'Koble til'));
    await tester.pumpAndSettle();

    expect(find.text('Tilkoblet'), findsOneWidget);
    expect(find.text('Vigo-PC'), findsOneWidget);
    expect(find.text('OxyGuard / VIGO'), findsOneWidget);
    expect(find.text('4 sensorer'), findsOneWidget);
  });

  testWidgets('invalid pairing code remains in dialog with clear feedback',
      (tester) async {
    await tester.pumpWidget(app(service: service(), role: 'admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koble til collector'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'invalid');
    await tester.tap(find.widgetWithText(FilledButton, 'Koble til'));
    await tester.pumpAndSettle();

    expect(
        find.text('Koden er ugyldig eller kan ikke brukes.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('non-admin can view add-ons but cannot open pairing',
      (tester) async {
    await tester.pumpWidget(app(service: service(), role: 'leser'));
    await tester.pumpAndSettle();

    expect(find.text('Fjellfisk Collector'), findsOneWidget);
    expect(find.text('Koble til collector'), findsNothing);
    expect(
      find.text('Bare administratorer kan koble til eller fra add-ons.'),
      findsOneWidget,
    );
    final setup = tester.widget<FilledButton>(
      find.byKey(const ValueKey('collector-setup-fjellfisk-collector')),
    );
    expect(setup.onPressed, isNull);
  });

  testWidgets('setup is disabled until a collector is connected',
      (tester) async {
    await tester.pumpWidget(app(service: service(), role: 'admin'));
    await tester.pumpAndSettle();

    final setupFinder =
        find.byKey(const ValueKey('collector-setup-fjellfisk-collector'));
    expect(tester.widget<FilledButton>(setupFinder).onPressed, isNull);

    await tester.tap(setupFinder);
    await tester.pumpAndSettle();
    expect(find.text('Collector Setup'), findsNothing);
  });

  testWidgets('connected collector opens setup and saves a sensor mapping',
      (tester) async {
    final mock = service(initialAddOns: [_connectedCollector()]);
    await tester.pumpWidget(app(service: mock, role: 'admin'));
    await tester.pumpAndSettle();

    final setupFinder =
        find.byKey(const ValueKey('collector-setup-fjellfisk-collector'));
    expect(tester.widget<FilledButton>(setupFinder).onPressed, isNotNull);
    await tester.tap(setupFinder);
    await tester.pumpAndSettle();

    expect(find.text('Collector Setup'), findsWidgets);
    expect(find.text('Pacific 01'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collector-setup-section-pacific-01')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('collector-setup-section-pacific-01')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hovedbygg').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collector-setup-tank-pacific-01')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('K1').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collector-live-preview-pacific-01')),
      findsOneWidget,
    );
    final saveSetup = find.byKey(const ValueKey('save-collector-setup'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1100));
    await tester.pumpAndSettle();
    await tester.tap(saveSetup);
    await tester.pumpAndSettle();

    final mapping = mock.mappingsForCollector('fjellfisk-collector').single;
    expect(mapping.sectionName, 'Hovedbygg');
    expect(mapping.tankName, 'K1');
  });

  testWidgets('non-admin can view setup but cannot change mappings',
      (tester) async {
    final mock = service(initialAddOns: [_connectedCollector()]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => LanguageScope(
          controller: LanguageController(),
          child: child!,
        ),
        home: CollectorSetupScreen(
          service: mock,
          collectorId: 'fjellfisk-collector',
          roleLoader: () async => 'leser',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bare administratorer kan endre sensoroppsettet.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('collector-setup-section-pacific-01')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('save-collector-setup')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('disconnect asks for confirmation then revokes the add-on',
      (tester) async {
    final mock = service(initialAddOns: [
      AddOn(
        id: 'fjellfisk-collector',
        type: AddOnType.collector,
        name: 'Fjellfisk Collector',
        description: 'Mock collector',
        status: AddOnStatus.connected,
        connectedDeviceId: 'mock-device',
        connectedAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        version: '1.0.0',
        deviceName: 'Vigo-PC',
        readerType: 'OxyGuard / VIGO',
        sensorCount: 3,
        latestMeasurementAt: DateTime.now(),
      ),
    ]);
    await tester.pumpWidget(app(service: mock, role: 'admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koble fra collector'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Collector slutter å sende nye målinger og må kobles til på nytt. Historiske data slettes ikke.'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Koble fra'));
    await tester.pumpAndSettle();

    expect(find.text('Tilgang fjernet'), findsOneWidget);
    expect(mock.addOns.single.status, AddOnStatus.revoked);
  });

  testWidgets('Add-ons navigation uses the existing tools menu',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('nb'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DashboardNavigation(
            facilityName: 'Testanlegg',
            userLabel: 'admin@example.invalid',
            roleFuture: Future.value('admin'),
            onDashboard: () {},
            onDiary: () {},
            onReport: () {},
            onFeedInventory: () {},
            onAddOns: () => opened = true,
            onAdminUsers: () {},
            onExport: () {},
            onLogout: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add-ons'));
    expect(opened, isTrue);
  });

  for (final locale in [const Locale('en'), const Locale('pl')]) {
    testWidgets('Add-ons localizes visible labels for ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(
        app(service: service(), role: 'admin', locale: locale),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(locale.languageCode == 'en'
            ? 'Connect collector'
            : 'Połącz collector'),
        findsOneWidget,
      );
      expect(find.text('Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('setup layout fits a narrow viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(
      service: service(initialAddOns: [_connectedCollector()]),
      role: 'admin',
    ));
    await tester.pumpAndSettle();
    final setupFinder =
        find.byKey(const ValueKey('collector-setup-fjellfisk-collector'));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(setupFinder);
    await tester.pumpAndSettle();

    expect(find.text('Pacific 01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pairing button blocks a second submit while loading',
      (tester) async {
    final gate = Completer<void>();
    final mock = MockAddOnService(claimDelay: () => gate.future);
    await tester.pumpWidget(app(service: mock, role: 'admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koble til collector'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FJ-8K4P-2XQ7');
    await tester.tap(find.widgetWithText(FilledButton, 'Koble til'));
    await tester.pump();
    expect(find.text('Kobler til…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Kobler til…'))
            .onPressed,
        isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(mock.addOns.single.status, AddOnStatus.connected);
  });
}

AddOn _connectedCollector() => AddOn(
      id: 'fjellfisk-collector',
      type: AddOnType.collector,
      name: 'Fjellfisk Collector',
      description: 'Mock collector',
      status: AddOnStatus.connected,
      connectedDeviceId: 'mock-device',
      connectedAt: DateTime(2026, 10, 8, 12),
      lastSeenAt: DateTime(2026, 10, 8, 12),
      version: '1.0.0',
      deviceName: 'Vigo-PC',
      readerType: 'OxyGuard / VIGO',
      sensorCount: 4,
      latestMeasurementAt: DateTime(2026, 10, 8, 12),
    );
