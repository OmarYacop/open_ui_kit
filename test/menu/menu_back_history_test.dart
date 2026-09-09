import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  test('bowed travel dips and returns on the same geometry fraction', () {
    const source = UiFluidGeometry(Rect.fromLTWH(220, 20, 44, 44), 22);
    const target = UiFluidGeometry(Rect.fromLTWH(84, 20, 180, 180), 16);
    for (final p in [0.0, .25, .5, .75, 1.0]) {
      final straight = UiFluidGeometry.lerp(source, target, p);
      final curved = UiFluidGeometry.lerp(
        source,
        target,
        p,
        bend: const Offset(0, 22),
      );
      expect(curved.rect.size, straight.rect.size);
      expect(curved.radius, straight.radius);
      expect(curved.rect.left, straight.rect.left);
      if (p == 0 || p == 1) {
        expect(curved.rect, straight.rect);
      } else {
        expect(curved.rect.top, greaterThan(straight.rect.top));
      }
    }
    final middle = UiFluidGeometry.lerp(
      source,
      target,
      .5,
      bend: const Offset(0, 22),
    );
    final late = UiFluidGeometry.lerp(
      source,
      target,
      .9,
      bend: const Offset(0, 22),
    );
    expect(late.rect.top, lessThan(middle.rect.top));
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets(
      'back tap pops once; hold and drag selects history once ($direction)',
      (tester) async {
        var popped = 0;
        UiNavigationBackHistoryItem? selected;
        const root = UiNavigationBackHistoryItem(
          title: 'Root',
          subtitle: 'First screen',
          value: 2,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: UiNavigationBackButton(
                  label: 'Back',
                  onPressed: () => popped++,
                  history: const [root],
                  onHistorySelected: (item) => selected = item,
                ),
              ),
            ),
          ),
        );
        final button = find.byType(UiNavigationBackButton);
        expect(tester.getSize(button), const Size(44, 44));
        expect(
          find.descendant(of: button, matching: find.byType(UiIconButton)),
          findsOneWidget,
        );
        final icon = tester.widget<Icon>(
          find.descendant(of: button, matching: find.byType(Icon)),
        );
        expect(icon.size, 32);
        expect(
          icon.icon,
          UiDirectionalIcons.chevronBack(tester.element(button)),
        );
        await tester.tapAt(tester.getCenter(button));
        await tester.pumpAndSettle();
        expect(popped, 1);
        expect(find.byType(UiMenuStack), findsNothing);
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(find.byType(UiMenuStack), findsOneWidget);
        expect(find.text('First screen'), findsOneWidget);
        final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
        expect(morph.sourceGeometry.radius, 22);
        expect(morph.travelArc, UiMenuTokens.defaults.travelArc);
        await gesture.moveTo(tester.getCenter(find.text('Root')));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(selected, same(root));
        expect(popped, 1);
        expect(find.byType(UiMenuStack), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
