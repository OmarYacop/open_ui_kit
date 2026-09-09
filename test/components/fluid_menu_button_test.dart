import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('anchored button opens, holds into popup, and selects once', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      UiApp(
        home: Align(
          alignment: Alignment.bottomRight,
          child: UiFluidMenuButton(
            title: 'Actions',
            trigger: const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: UiText('More')),
            ),
            items: [
              UiMenuSubmenu(
                label: 'Organize',
                items: [
                  UiMenuItem(label: 'Rename', onPressed: () => selected++),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('More')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Organize').hitTestable(), findsOneWidget);
    final menu = tester.getRect(find.byType(UiFluidMenuStack));
    expect(menu.left, greaterThanOrEqualTo(0));
    expect(menu.right, lessThanOrEqualTo(800));
    expect(menu.bottom, lessThanOrEqualTo(600));
    await gesture.moveTo(tester.getCenter(find.text('Organize')));
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.text('Rename')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.byType(UiFluidMenuStack), findsNothing);
    await tester.tap(find.byType(UiFluidMenuButton));
    await tester.pumpAndSettle();
    expect(find.byType(UiFluidMenuStack), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(UiFluidMenuStack), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('human-duration taps keep popup open in scrolling page', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: UiPageScaffold(
          body: ListView(
            children: [
              const SizedBox(height: 100),
              Align(
                alignment: Alignment.centerRight,
                child: UiFluidMenuButton(
                  title: 'Actions',
                  trigger: const SizedBox(width: 44, height: 44),
                  items: [UiMenuItem(label: 'Cancel class')],
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final milliseconds in [60, 120, 200, 350]) {
      final press = await tester.startGesture(
        tester.getCenter(find.byType(UiFluidMenuButton)),
      );
      await tester.pump(Duration(milliseconds: milliseconds));
      await press.up();
      await tester.pumpAndSettle();
      expect(
        find.text('Cancel class').hitTestable(),
        findsOneWidget,
        reason: 'press duration $milliseconds',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });
  testWidgets(
    'unchanged display notifications preserve popup; resize dismisses',
    (tester) async {
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: UiFluidMenuButton(
              title: 'Actions',
              trigger: const SizedBox(width: 44, height: 44),
              items: const [UiMenuItem(label: 'Cancel class')],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(UiFluidMenuButton));
      await tester.pumpAndSettle();
      tester.binding.handleMetricsChanged();
      await tester.pumpAndSettle();
      expect(find.text('Cancel class').hitTestable(), findsOneWidget);
      tester.view.physicalSize = const Size(700, 500);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpAndSettle();
      expect(find.byType(UiFluidMenuStack), findsNothing);
      await tester.tap(find.byType(UiFluidMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('Cancel class').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
