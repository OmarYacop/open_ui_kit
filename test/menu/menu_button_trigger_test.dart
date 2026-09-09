import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'button paints its own pressed surface and exact hit bounds ($direction)',
      (tester) async {
        await tester.pumpWidget(
          UiApp(
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: UiDropdownMenu(
                  triggerBuilder: (context, open) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: UiIconButton(
                      icon: const Icon(Icons.more_horiz),
                      semanticsLabel: 'Actions',
                      intent: UiIntent.neutral,
                      size: UiSize.lg,
                      onPressed: open,
                    ),
                  ),
                  items: const [UiMenuItem(label: 'Choice')],
                ),
              ),
            ),
          ),
        );
        final button = find.byType(UiIconButton);
        final rect = tester.getRect(button);
        expect(rect.size, const Size(44, 44));
        final surface = find.descendant(
          of: button,
          matching: find.byType(UiBox),
        );
        final before = tester.widget<UiBox>(surface).background!;
        expect(before.a, greaterThan(0));
        final down = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.widget<UiBox>(surface).background, isNot(before));
        expect(tester.getSize(surface).width, 44);
        expect(tester.getRect(surface).width, greaterThan(44));
        await down.cancel();
        await tester.pumpAndSettle();
        // Padding outside the actual button is neither a tap nor a hold target.
        final outside = rect.centerLeft - const Offset(8, 0);
        await tester.tapAt(outside);
        await tester.pumpAndSettle();
        expect(find.byType(UiMenuStack), findsNothing);
        final hold = await tester.startGesture(outside);
        await tester.pump(const Duration(milliseconds: 650));
        expect(find.byType(UiMenuStack), findsNothing);
        await hold.up();
        for (final point in [
          rect.centerLeft + const Offset(1, 0),
          rect.centerRight - const Offset(1, 0),
          rect.topCenter + const Offset(0, 1),
          rect.bottomCenter - const Offset(0, 1),
        ]) {
          await tester.tapAt(point);
          await tester.pumpAndSettle();
          expect(find.text('Choice').hitTestable(), findsOneWidget);
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('disabled builder button cannot open through tap or hold', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: UiDropdownMenu(
            triggerBuilder: (context, open) => const UiIconButton(
              icon: Icon(Icons.more_horiz),
              semanticsLabel: 'Disabled',
            ),
            items: const [UiMenuItem(label: 'Choice')],
          ),
        ),
      ),
    );
    final button = find.byType(UiIconButton);
    await tester.tapAt(tester.getCenter(button));
    await tester.pumpAndSettle();
    await tester.longPress(button);
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuStack), findsNothing);
    final node = tester.getSemantics(find.bySemanticsLabel('Disabled'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isFalse,
    );
    semantics.dispose();
  });

  for (final direction in TextDirection.values) {
    testWidgets('normal button owns tap and hold selection ($direction)', (
      tester,
    ) async {
      var selected = 0;
      await tester.pumpWidget(
        UiApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: UiDropdownMenu(
                triggerBuilder: (context, open) => UiButton(
                  label: 'Actions',
                  intent: UiIntent.neutral,
                  onPressed: open,
                ),
                items: [
                  UiMenuItem(label: 'Select', onPressed: () => selected++),
                ],
              ),
            ),
          ),
        ),
      );
      final pressable = tester.widget<UiPressable>(
        find.descendant(
          of: find.byType(UiButton),
          matching: find.byType(UiPressable),
        ),
      );
      expect(pressable.enabled, isTrue);
      expect(pressable.onPressed, isNotNull);
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Select').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      final hold = await tester.startGesture(
        tester.getCenter(find.text('Actions')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await hold.moveTo(tester.getCenter(find.text('Select')));
      await tester.pump();
      await hold.up();
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(find.byType(UiMenuStack), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('normal trigger opens using its own keyboard focus', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: UiDropdownMenu(
            triggerBuilder: (context, open) =>
                UiButton(label: 'Actions', focusNode: focus, onPressed: open),
            items: const [UiMenuItem(label: 'Choice')],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Choice').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
