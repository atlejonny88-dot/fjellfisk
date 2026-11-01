import 'dart:convert';

import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/screens/addons_screen.dart';
import 'package:fjellfisk/screens/collector_setup_screen.dart';
import 'package:fjellfisk/services/collector_claim_service.dart';
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
  var paired = false;
  var forbidden = false;
  var gets = 0;
  var claims = 0;
  late CollectorClaimService api;

  setUp(() {
    paired = false;
    forbidden = false;
    gets = 0;
    claims = 0;
    api = CollectorClaimService(
      backendUrl: 'https://collector.example',
      tokenProvider: _Token(),
      client: MockClient((request) async {
        if (forbidden) return http.Response('{}', 403);
        if (request.url.path.endsWith('/sensors')) {
          return http.Response('{"sensors":[],"mappings":[]}', 200);
        }
        if (request.method == 'POST') {
          claims++;
          paired = true;
          return http.Response('{}', 200);
        }
        gets++;
        return http.Response(
          jsonEncode(paired
              ? [
                  {'collectorId': 'real-device', 'state': 'PAIRED'}
                ]
              : []),
          200,
        );
      }),
    );
  });

  Widget app({String role = 'admin', Locale locale = const Locale('nb')}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => LanguageScope(
          controller: LanguageController(),
          child: child!,
        ),
        home: AddOnsScreen(
          facilityId: 'actual-facility',
          claimService: api,
          roleLoader: () async => role,
        ),
      );

  Finder setup(String id) => find.byKey(ValueKey('collector-setup-$id'));

  testWidgets('existing real pairing enables setup on first page load',
      (tester) async {
    paired = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(gets, 1);
    expect(
        tester.widget<FilledButton>(setup('real-device')).onPressed, isNotNull);
    await tester.tap(setup('real-device'));
    await tester.pumpAndSettle();
    expect(find.text('Collector Setup'), findsWidgets);
    expect(find.text('Pacific 01'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Ingen sensorer er mottatt fra Collector ennå.'),
        findsOneWidget);
    final save = find.byKey(const ValueKey('save-collector-setup'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('claim updates the card, and reopening does not forget pairing',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(setup('fjellfisk-collector')).onPressed,
        isNull);
    await tester.tap(find.text('Koble til collector'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'FJ-REAL-CODE');
    await tester.tap(find.widgetWithText(FilledButton, 'Koble til'));
    await tester.pumpAndSettle();
    expect(claims, 1);
    expect(
        tester.widget<FilledButton>(setup('real-device')).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
        tester.widget<FilledButton>(setup('real-device')).onPressed, isNotNull);
    expect(claims, 1);
  });

  testWidgets('refresh restores changed pairing without another claim',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    paired = true;
    await tester.tap(find.byKey(const ValueKey('refresh-collector-status')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<FilledButton>(setup('real-device')).onPressed, isNotNull);
    expect(claims, 0);
  });

  testWidgets('readers can view real status but cannot manage collector',
      (tester) async {
    paired = true;
    await tester.pumpWidget(app(role: 'leser'));
    await tester.pumpAndSettle();
    expect(gets, 1);
    expect(find.text('Koble til collector'), findsNothing);
    expect(tester.widget<FilledButton>(setup('real-device')).onPressed, isNull);
  });

  testWidgets(
      'permission denied shows localized fallback, never mock connection',
      (tester) async {
    forbidden = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Tilkoblet'), findsNothing);
    expect(find.text('Pacific 01'), findsNothing);
    expect(tester.widget<FilledButton>(setup('fjellfisk-collector')).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [
    const Locale('nb'),
    const Locale('en'),
    const Locale('pl')
  ]) {
    testWidgets('real setup fits mobile in ${locale.languageCode}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      paired = true;
      await tester.pumpWidget(app(locale: locale));
      await tester.pumpAndSettle();
      await tester.ensureVisible(setup('real-device'));
      await tester.pumpAndSettle();
      await tester.tap(setup('real-device'));
      await tester.pumpAndSettle();
      expect(find.byType(CollectorSetupScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
