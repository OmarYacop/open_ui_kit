import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('card rebuild near settlement preserves menu geometry', (
    tester,
  ) async {
    late StateSetter rebuildCard;
    await tester.pumpWidget(
      UiApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildCard = setState;
            return Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100, right: 20),
                child: UiDropdownMenu(
                  trigger: const Text('Card actions'),
                  items: [
                    UiMenuItem(label: 'Edit', onPressed: () {}),
                    UiMenuItem(label: 'Cancel', onPressed: () {}),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Card actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    Rect destination() => tester
        .widget<UiFluidMorph>(find.byType(UiFluidMorph))
        .destinationGeometry
        .rect;
    final before = destination();
    rebuildCard(() {});
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        destination(),
        before,
        reason: 'Rebuild frame $i must retain measured bounds',
      );
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    'root has compact rows and no heading; submenu keeps its return title',
    (tester) async {
      await tester.pumpWidget(
        const UiApp(
          home: Center(
            child: UiDropdownMenu(
              title: 'Root heading',
              trigger: Text('Open'),
              items: [
                UiMenuItem(label: 'First'),
                UiMenuSubmenu(
                  label: 'Nested',
                  items: [UiMenuItem(label: 'Child')],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.text('Open')));
      await tester.pumpAndSettle();
      expect(find.text('Root heading'), findsNothing);
      final row = find
          .ancestor(of: find.text('First'), matching: find.byType(UiPressable))
          .first;
      expect(tester.getSize(row).height, 36);
      final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
      expect(morph.destinationGeometry.rect.height, lessThanOrEqualTo(80));
      expect(morph.destinationGeometry.rect.width, 180);
      await tester.tap(find.text('Nested'));
      await tester.pumpAndSettle();
      expect(find.text('Nested'), findsOneWidget);
      expect(find.text('Child').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'release immediately retargets the current geometry toward the menu',
    (tester) async {
      await tester.pumpWidget(
        const UiApp(
          home: Center(
            child: UiDropdownMenu(
              trigger: Text('Open'),
              items: [
                UiMenuItem(label: 'First'),
                UiMenuItem(label: 'Second'),
              ],
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Open')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 60));
      final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
      final before = tester
          .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
          .first
          .geometry
          .rect;
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final after = tester
          .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
          .first
          .geometry
          .rect;
      expect(morph.controller.retargeting, isTrue);
      expect(
        (after.center - morph.destinationGeometry.rect.center).distance,
        lessThan(
          (before.center - morph.destinationGeometry.rect.center).distance,
        ),
      );
      expect(after.width, greaterThan(before.width));
      await tester.pumpAndSettle();
    },
  );

  test(
    'menu overshoot is reduced while its shared settling endpoint stays exact',
    () {
      var originalPeak = 1.0;
      var menuPeak = 1.0;
      for (var i = 0; i <= 100; i++) {
        final normal = uiFluidSpring(i / 100);
        final menu = uiFluidSpring(
          i / 100,
          strength: UiMenuTokens.defaults.springStrength,
        );
        if (normal > originalPeak) originalPeak = normal;
        if (menu > menuPeak) menuPeak = menu;
      }
      expect(menuPeak - 1, closeTo((originalPeak - 1) * .25, .00001));
      expect(uiFluidSpring(1, strength: .25), 1);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'neutral trigger and moving menu share one fill and border ($dark)',
      (tester) async {
        final tokens = dark ? UiThemeData.dark() : UiThemeData.light();
        await tester.pumpWidget(
          MaterialApp(
            home: UiTheme(
              tokens: tokens,
              child: const Center(
                child: UiDropdownMenu(
                  trigger: UiIconButton(
                    icon: Icon(Icons.more_horiz),
                    semanticsLabel: 'Open',
                  ),
                  items: [UiMenuItem(label: 'Action')],
                ),
              ),
            ),
          ),
        );
        final button = find.byType(UiIconButton);
        final inner = tester.widget<UiBox>(
          find.descendant(of: button, matching: find.byType(UiBox)),
        );
        expect(inner.background!.a, 0);
        expect(inner.border, isNull);
        final surface = tester
            .widgetList<DecoratedBox>(
              find.ancestor(of: button, matching: find.byType(DecoratedBox)),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((decoration) => decoration.border != null);
        await tester.tapAt(tester.getCenter(button));
        await tester.pump();
        final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
        expect(morph.color, surface.color);
        expect(morph.border, (surface.border! as Border).top);
        expect(
          morph.sourceGeometry.radius,
          morph.sourceGeometry.rect.shortestSide / 2,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
