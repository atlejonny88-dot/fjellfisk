import 'package:fjellfisk/widgets/tank_registration_actions.dart';
import 'package:fjellfisk/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget actions(
          {bool write = true,
          bool active = true,
          bool saving = false,
          bool saved = false,
          VoidCallback? onSave}) =>
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: TankRegistrationActions(
            canWrite: write,
            isActive: active,
            saving: saving,
            openingNext: false,
            hasSaved: saved,
            onSave: onSave ?? () {},
            onSaveNext: onSave ?? () {},
            onNext: () {},
            onInfo: () {},
            onWeightSample: () {},
            onMove: () {},
            onHistory: () {},
            onGrowth: () {},
            onMortality: () {},
          ),
        ))),
      );

  testWidgets('reader and empty tanks cannot register; reader can see history',
      (tester) async {
    await tester.pumpWidget(actions(write: false));
    expect(find.text('Lagre'), findsNothing);
    expect(find.text('Lagre og neste'), findsNothing);
    expect(find.text('Flytt fisk'), findsNothing);
    expect(find.text('Historikk'), findsOneWidget);
    await tester.pumpWidget(actions(active: false));
    expect(find.text('Lagre'), findsNothing);
    expect(find.text('Lagre og neste'), findsNothing);
  });

  testWidgets('both save buttons disabled during pending write',
      (tester) async {
    var writes = 0;
    await tester.pumpWidget(actions(saving: true, onSave: () => writes++));
    await tester.tap(find.text('Lagrer…'));
    await tester.tap(find.text('Lagre og neste'));
    expect(writes, 0);
    expect(find.text('Neste kar'), findsNothing);
    await tester.pumpWidget(actions(saved: true));
    expect(find.text('Neste kar'), findsOneWidget);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('registration actions fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(actions(saved: true));
      await tester.pumpAndSettle();
      expect(find.text('Lagre og neste'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
