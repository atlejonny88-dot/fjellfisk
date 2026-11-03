import 'package:fjellfisk/widgets/mobile_navigation_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('reserves Android system-navigation space for a scrollable page',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    var pressed = false;
    const lastActionKey = Key('last-action');

    await tester.pumpWidget(
      MaterialApp(
        home: MobileNavigationSafeArea(
          enabled: true,
          child: Scaffold(
            body: ListView(
              children: [
                const SizedBox(height: 900),
                FilledButton(
                  key: lastActionKey,
                  onPressed: () => pressed = true,
                  child: const Text('Last action'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(lastActionKey),
      240,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getBottomRight(find.byKey(lastActionKey)).dy,
      lessThanOrEqualTo(640 - 48),
    );

    await tester.tap(find.byKey(lastActionKey));
    expect(pressed, isTrue);
  });

  testWidgets('does not add mobile inset protection when disabled',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    const actionKey = Key('web-action');
    await tester.pumpWidget(
      MaterialApp(
        home: MobileNavigationSafeArea(
          enabled: false,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: FilledButton(
                key: actionKey,
                onPressed: () {},
                child: const Text('Web action'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getBottomRight(find.byKey(actionKey)).dy, 640);
  });

  testWidgets('keeps the last action above gesture navigation in landscape',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    const actionKey = Key('landscape-last-action');
    await tester.pumpWidget(
      MaterialApp(
        home: MobileNavigationSafeArea(
          enabled: true,
          child: Scaffold(
            body: ListView(
              children: [
                const SizedBox(height: 600),
                FilledButton(
                  key: actionKey,
                  onPressed: () {},
                  child: const Text('Landscape action'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.byKey(actionKey), 160);
    await tester.pumpAndSettle();

    expect(
      tester.getBottomRight(find.byKey(actionKey)).dy,
      lessThanOrEqualTo(360 - 24),
    );
  });
}
