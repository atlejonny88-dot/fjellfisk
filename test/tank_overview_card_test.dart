import 'package:fjellfisk/theme/app_theme.dart';
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Snittvekt'), findsOneWidget);
    expect(find.text('Fôr 24t'), findsOneWidget);
    expect(find.text('Døde 7d'), findsOneWidget);
    expect(find.text('Temp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
