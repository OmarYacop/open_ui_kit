import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('LMS attachment has a constant composer border in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        mode: UiThemeMode.dark,
        home: Builder(
          builder: (context) {
            final tokens = UiThemeTokens.of(context);
            return Align(
              alignment: Alignment.bottomCenter,
              child: UiDropdownMenu(
                destinationOffset: const Offset(0, -60),
                menuTokens: tokens.menu.copyWith(
                  borderColor: tokens.colors.border,
                  borderWidth: 1,
                ),
                triggerBuilder: (_, open) => UiIconButton(
                  icon: const Text('+'),
                  semanticsLabel: 'Attach file',
                  intent: UiIntent.secondary,
                  borderRadius: tokens.radius.pillAll,
                  backgroundColor: tokens.colors.surface,
                  borderColor: tokens.colors.border,
                  borderWidth: 1,
                  onPressed: open,
                ),
                items: const [
                  UiMenuItem(label: 'Camera'),
                  UiMenuItem(label: 'Photos and videos'),
                ],
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiIconButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    final finder = find.byType(UiFluidMorph);
    final morph = tester.widget<UiFluidMorph>(finder);
    final controller = morph.controller..stop();
    expect(morph.initialSourceBorder!.width, closeTo(1, .0001));
    for (final p in [0.0, .1, .25, .5, .75, 1.0]) {
      controller.value = p;
      await tester.pump();
      final surface = tester
          .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
          .first;
      expect(surface.border.width, closeTo(1, .0001));
      expect(surface.border.color, UiColorTokens.dark.border);
    }
    controller.close(tester.element(finder));
    controller.stop();
    for (final p in [.9, .75, .5, .25, .1]) {
      controller.value = p;
      await tester.pump();
      final surface = tester
          .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
          .first;
      expect(surface.border.width, closeTo(1, .0001));
      expect(surface.border.color, UiColorTokens.dark.border);
    }
    controller.value = 0;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final style in [UiCornerStyle.circular, UiCornerStyle.continuous]) {
    testWidgets(
      'pill corners and stroke stay synchronized through opening and closing $style',
      (tester) async {
        await tester.pumpWidget(
          UiApp(
            lightTokens: UiThemeData.light(
              radius: UiRadiusTokens.standard.copyWith(cornerStyle: style),
            ),
            home: Center(
              child: UiDropdownMenu(
                triggerBuilder: (context, open) => UiIconButton(
                  icon: const Text('+'),
                  semanticsLabel: 'Open',
                  borderRadius: UiThemeTokens.of(context).radius.pillAll,
                  backgroundColor: const Color(0xFF171717),
                  borderColor: const Color(0xFF262626),
                  borderWidth: 1,
                  onPressed: open,
                ),
                items: const [UiMenuItem(label: 'Action')],
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(UiIconButton)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pump();
        final finder = find.byType(UiFluidMorph);
        final morph = tester.widget<UiFluidMorph>(finder);
        final controller = morph.controller..stop();
        final initial = morph.initialSourceGeometry!;
        final initialRadius = initial.borderRadius.topLeft.x;
        expect(initialRadius, closeTo(initial.rect.shortestSide / 2, .001));
        final endRadius = morph.destinationGeometry.borderRadius.topLeft.x;
        final initialWidth = morph.initialSourceBorder!.width;
        final endWidth = morph.border.width;
        for (final progress in [0.0, .1, .25, .5, .75, 1.0]) {
          controller.value = progress;
          await tester.pump();
          final surface = tester
              .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
              .first;
          final fraction = Curves.easeOutCubic.transform(progress);
          expect(
            surface.geometry.borderRadius.topLeft.x,
            closeTo(
              initialRadius + (endRadius - initialRadius) * fraction,
              .001,
            ),
          );
          expect(
            surface.border.width,
            closeTo(initialWidth + (endWidth - initialWidth) * fraction, .001),
          );
        }
        controller.close(tester.element(finder));
        controller.stop();
        final restingRadius = morph.sourceGeometry.borderRadius.topLeft.x;
        final restingWidth = morph.sourceBorder!.width;
        for (final progress in [0.0, .1, .25, .5, .75, .99]) {
          controller.value = 1 - progress;
          await tester.pump();
          final surface = tester
              .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
              .first;
          final fraction = Curves.easeOutCubic.transform(progress);
          expect(
            surface.geometry.borderRadius.topLeft.x,
            closeTo(endRadius + (restingRadius - endRadius) * fraction, .001),
          );
          expect(
            surface.border.width,
            closeTo(endWidth + (restingWidth - endWidth) * fraction, .001),
          );
        }
        controller.value = 0;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'custom icon paint hands off and returns continuously $direction',
      (tester) async {
        const fill = Color(0xFF171717);
        const outline = Color(0xFF262626);
        const corners = BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(16),
        );
        await tester.pumpWidget(
          UiApp(
            home: Directionality(
              textDirection: direction,
              child: Center(
                child: UiDropdownMenu(
                  triggerBuilder: (_, open) => UiIconButton(
                    icon: const Text('+'),
                    semanticsLabel: 'Open',
                    size: UiSize.md,
                    backgroundColor: fill,
                    borderColor: outline,
                    borderWidth: 2,
                    borderRadius: corners,
                    surfaceMargin: const EdgeInsets.all(6),
                    onPressed: open,
                  ),
                  items: const [UiMenuItem(label: 'Action')],
                ),
              ),
            ),
          ),
        );
        final boxFinder = find.descendant(
          of: find.byType(UiIconButton),
          matching: find.byType(UiBox),
        );
        final restRect = tester.getRect(boxFinder);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(UiIconButton)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final pressedRect = tester.getRect(boxFinder);
        final pressedColor = tester.widget<UiBox>(boxFinder).background;
        await gesture.up();
        await tester.pump();
        final morphFinder = find.byType(UiFluidMorph);
        final morph = tester.widget<UiFluidMorph>(morphFinder);
        final origin = tester.getTopLeft(find.byType(UiMenuStack));
        expect(morph.sourceGeometry.rect.shift(origin), restRect);
        expect(morph.initialSourceGeometry!.rect.shift(origin), pressedRect);
        expect(morph.sourceGeometry.borderRadius, corners);
        expect(morph.sourceColor, fill);
        expect(morph.sourceBorder, const BorderSide(color: outline, width: 2));
        final firstSurface = tester
            .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
            .first;
        expect(firstSurface.color, pressedColor);
        expect(firstSurface.backdropBlurSigma, 0);
        expect(firstSurface.border.color, outline);
        expect(firstSurface.border.width, closeTo(2, .001));
        expect(firstSurface.fit, BoxFit.none);
        await tester.pumpAndSettle();
        final expanded = tester
            .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
            .first;
        expect(expanded.color, morph.color);
        expect(expanded.border, morph.border);
        morph.controller.close(tester.element(morphFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final closing = tester
            .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
            .first;
        morph.controller.open(tester.element(morphFinder), direct: true);
        await tester.pump();
        final interrupted = tester
            .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
            .first;
        expect(interrupted.color, closing.color);
        expect(interrupted.border, closing.border);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(tester.getRect(boxFinder), restRect);
        expect(tester.widget<UiBox>(boxFinder).background, fill);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
