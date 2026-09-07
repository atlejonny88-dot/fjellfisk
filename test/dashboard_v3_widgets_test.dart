import 'package:fjellfisk/theme/app_theme.dart';
import 'package:fjellfisk/widgets/dashboard_v3_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testDashboard({required bool desktop}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        drawer: desktop ? null : const Drawer(),
        appBar: DashboardTopBar(
          facilityName: 'Arctic Hardanger',
          userLabel: 'test@example.com',
          isDesktop: desktop,
          onRefresh: () {},
          onLogout: () {},
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const ResponsiveDashboardGrid(
                minItemWidth: 190,
                children: [
                  DashboardKpiCard(
                    title: 'Aktive kar',
                    value: '12',
                    detail: 'av 16 kar',
                    note: '4 tomme kar',
                    icon: Icons.radar,
                    accent: Color(0xFF0B63E5),
                  ),
                  DashboardKpiCard(
                    title: 'Biomasse',
                    value: '102,0 kg',
                    detail: '1200 fisk',
                    note: 'Aktiv biomasse',
                    icon: Icons.scale_outlined,
                    accent: Color(0xFF15945C),
                  ),
                  DashboardKpiCard(
                    title: 'Fôr i dag',
                    value: '25,0 kg',
                    detail: 'Faktisk registrert',
                    note: 'Anbefalt 28,0 kg',
                    icon: Icons.set_meal_outlined,
                    accent: Color(0xFF6C55C7),
                  ),
                  DashboardKpiCard(
                    title: 'Døde i dag',
                    value: '1',
                    detail: 'Registrert dødelighet',
                    note: 'Antall fisk',
                    icon: Icons.warning_amber_rounded,
                    accent: Color(0xFFD43838),
                  ),
                  DashboardKpiCard(
                    title: 'Snittemperatur',
                    value: '9,2 °C',
                    detail: 'Registrerte målinger',
                    note: 'Oppdatert fra karlogger',
                    icon: Icons.device_thermostat,
                    accent: Color(0xFF1678D2),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DashboardSectionCard(
                name: 'Hovedbygget med et langt seksjonsnavn',
                activeTanks: 8,
                emptyTanks: 2,
                fishCount: 1200,
                biomassLabel: '1,25 tonn',
                feedLabel: '28,5 kg',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('dashboard widgets fit a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testDashboard(desktop: false));
    await tester.pumpAndSettle();

    expect(find.text('Fjellfisk'), findsOneWidget);
    expect(find.text('Aktive kar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard widgets fill a desktop viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testDashboard(desktop: true));
    await tester.pumpAndSettle();

    expect(find.text('Snittemperatur'), findsOneWidget);
    expect(find.text('Hovedbygget med et langt seksjonsnavn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
