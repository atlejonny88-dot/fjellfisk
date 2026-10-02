import 'package:fjellfisk/l10n/app_localizations.dart';
import 'package:fjellfisk/l10n/language_controller.dart';
import 'package:fjellfisk/screens/login_screen.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = LanguageController(saveLanguage: (_) async {});
    await tester.pumpWidget(_loginApp(controller));
    await tester.pumpAndSettle();

    expect(find.text('Fjellfisk'), findsOneWidget);
    expect(find.text('Drift. Oversikt. Kontroll.'), findsOneWidget);
    expect(find.text('Fjellfisk v3.0.0'), findsOneWidget);
    expect(find.text('Logg inn'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login follows the selected UI language', (tester) async {
    final controller = LanguageController(saveLanguage: (_) async {});
    await tester.pumpWidget(_loginApp(controller));
    await tester.pumpAndSettle();

    await controller.select(AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('Operations. Overview. Control.'), findsOneWidget);
    expect(find.text('Log in'), findsNWidgets(2));

    await controller.select(AppLanguage.polish);
    await tester.pumpAndSettle();

    expect(find.text('Eksploatacja. Przegląd. Kontrola.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _loginApp(LanguageController controller) {
  return LanguageScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        locale: controller.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ),
  );
}
