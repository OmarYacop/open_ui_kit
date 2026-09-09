import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host({
  Offset offset = Offset.zero,
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
  UiMenuTokens? menu,
  bool reducedMotion = false,
  VoidCallback? action,
  bool enabled = true,
}) => UiApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      padding: const EdgeInsets.only(top: 24),
      viewInsets: const EdgeInsets.only(bottom: 60),
      disableAnimations: reducedMotion,
    ),
    child: Directionality(
      textDirection: direction,
      child: Stack(
        children: [
          Positioned(
            left: 350,
            top: 100,
            child: UiDropdownMenu(
              key: const ValueKey('menu'),
              destinationOffset: offset,
              transitionDurationScale: scale,
              menuTokens: menu,
              triggerBuilder: (_, open) =>
                  UiButton(label: 'Open', onPressed: open),
              items: [
                UiMenuItem(
                  label: 'Action',
                  onPressed: action,
                  enabled: enabled,
                ),
                const UiMenuSubmenu(
                  label: 'Nested',
                  items: [UiMenuItem(label: 'Child')],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

Rect destination(WidgetTester tester) {
  final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
  return morph.destinationGeometry.rect.shift(
    tester.getTopLeft(find.byType(UiMenuStack)),
  );
}

Rect source(WidgetTester tester) {
  final stack = tester.widget<UiMenuStack>(find.byType(UiMenuStack));
  return stack.rootSourceGeometry!.rect.shift(
    tester.getTopLeft(find.byType(UiMenuStack)),
  );
}

void main() {
  testWidgets('final submenu target opens before root settles', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.text('Nested'));
    await tester.tapAt(const Offset(20, 50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(target);
    await tester.pump();
    expect(find.byType(UiMenuTransition), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Child').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stable opening targets retain disabled action behavior', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(host(enabled: false, action: () => selected++));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final target = tester.getCenter(find.text('Action'));
    await tester.tapAt(const Offset(20, 50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(target);
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(find.byType(UiMenuStack), findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    for (final elapsed in [120, 240, 400]) {
      testWidgets(
        'final action target works during opening at ${elapsed}ms $direction',
        (tester) async {
          var selected = 0;
          await tester.pumpWidget(
            host(direction: direction, action: () => selected++),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final finalTarget = tester.getCenter(find.text('Action'));
          await tester.tapAt(const Offset(20, 50));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(Duration(milliseconds: elapsed));
          final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
          expect(morph.controller.isAnimating, isTrue);
          final gesture = await tester.startGesture(finalTarget);
          await tester.pump(const Duration(milliseconds: 40));
          await gesture.up();
          expect(selected, 1, reason: 'Selection must not wait for the spring');
          await tester.pumpAndSettle();
          expect(find.byType(UiMenuStack), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'destination offset moves menu but retains source in $direction',
      (tester) async {
        await tester.pumpWidget(host(direction: direction));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final before = destination(tester);
        final trigger = source(tester);
        await tester.pumpWidget(
          host(direction: direction, offset: const Offset(20, 16)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          destination(tester).topLeft,
          before.topLeft + const Offset(20, 16),
        );
        expect(source(tester), trigger);
        await tester.tapAt(const Offset(20, 50));
        await tester.pumpAndSettle();
        expect(find.byType(UiMenuStack), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final offset in [const Offset(5000, 5000), const Offset(-5000, -5000)]) {
    testWidgets('large offset stays inside safe area and keyboard $offset', (
      tester,
    ) async {
      await tester.pumpWidget(host(offset: offset));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final rect = destination(tester);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.bottom, lessThanOrEqualTo(540));
      expect(find.text('Action').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('per-menu tokens and timing reach the transition and selection', (
    tester,
  ) async {
    const menu = UiMenuTokens(
      springStrength: .1,
      travelArc: 8,
      pressExpansion: .05,
      backdropBlurSigma: 0,
      surfaceOpacity: 1,
      closeDuration: Duration(milliseconds: 120),
    );
    var selected = 0;
    await tester.pumpWidget(
      host(menu: menu, scale: .5, action: () => selected++),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(morph.controller.durationScale, .5);
    expect(morph.springStrength, .1);
    expect(morph.travelArc, 8);
    expect(morph.pressExpansion, .05);
    expect(
      UiThemeTokens.of(tester.element(find.byType(UiMenuStack))).menu,
      menu,
    );
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.byType(UiMenuStack), findsNothing);
  });

  testWidgets('changing timing closes the overlay and allows reopening', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(scale: .7));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuStack), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<UiFluidMorph>(find.byType(UiFluidMorph))
          .controller
          .durationScale,
      .7,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion overrides custom slow timing', (tester) async {
    await tester.pumpWidget(host(scale: 10, reducedMotion: true));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(morph.controller.isAnimating, isFalse);
    expect(morph.controller.value, 1);
    await tester.tapAt(const Offset(20, 50));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuStack), findsNothing);
  });
}
