import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/widgets/dashboard_v3_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Norwegian is the default and invalid stored values fall back safely',
      () {
    expect(AppLanguage.fromCode(null), AppLanguage.norwegian);
    expect(AppLanguage.fromCode(''), AppLanguage.norwegian);
    expect(AppLanguage.fromCode('de'), AppLanguage.norwegian);
    expect(AppLanguage.fromCode('no'), AppLanguage.norwegian);
  });

  test('language selection is loaded and saved with the user profile value',
      () async {
    var stored = 'en';
    final controller = LanguageController(
      loadLanguage: () async => stored,
      saveLanguage: (value) async => stored = value,
    );

    await controller.loadForCurrentUser();
    expect(controller.language, AppLanguage.english);

    await controller.select(AppLanguage.polish);
    expect(controller.language, AppLanguage.polish);
    expect(stored, 'pl');
  });

  testWidgets('flag follows Norwegian, English and Polish selections',
      (tester) async {
    var language = AppLanguage.norwegian;

    await tester.pumpWidget(
      _localizedApp(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: DashboardTopBar(
              facilityName: 'Arctic Hardanger',
              userLabel: 'test@example.com',
              isDesktop: true,
              language: language,
              onLanguageChanged: (next) => setState(() => language = next),
              onRefresh: () {},
              onLogout: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('🇳🇴'), findsOneWidget);
    await tester.tap(find.text('🇳🇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('🇬🇧'), findsOneWidget);

    await tester.tap(find.text('🇬🇧'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polski'));
    await tester.pumpAndSettle();
    expect(find.text('🇵🇱'), findsOneWidget);
  });

  testWidgets('English and Polish dashboard labels fit a narrow layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _localizedApp(
        const DashboardHeading(
            facilityName: 'Arctic Hardanger', onRefresh: _noop),
        locale: const Locale('en'),
      ),
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _localizedApp(
        const DashboardHeading(
            facilityName: 'Arctic Hardanger', onRefresh: _noop),
        locale: const Locale('pl'),
      ),
    );
    expect(find.text('Panel główny'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

Widget _localizedApp(Widget home, {Locale locale = const Locale('nb')}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
