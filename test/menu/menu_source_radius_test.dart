import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final corners in <BorderRadiusGeometry>[
      BorderRadius.zero,
      BorderRadius.circular(12),
      const BorderRadiusDirectional.only(
        topStart: Radius.circular(4),
        topEnd: Radius.circular(18),
        bottomStart: Radius.circular(10),
      ),
    ]) {
      testWidgets(
        'source corners survive open and reverse ($direction, $corners)',
        (tester) async {
          final expected = corners.resolve(direction);
          await tester.pumpWidget(
            UiApp(
              home: Directionality(
                textDirection: direction,
                child: Center(
                  child: UiDropdownMenu(
                    sourceBorderRadius: corners,
                    triggerBuilder: (context, open) => UiIconButton(
                      size: UiSize.lg,
                      icon: const SizedBox(width: 20, height: 20),
                      semanticsLabel: 'Open',
                      borderRadius: corners.resolve(direction),
                      onPressed: open,
                    ),
                    items: const [
                      UiMenuItem(label: 'Action'),
                      UiMenuItem(label: 'Another'),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byType(UiIconButton));
          await tester.pump();
          final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
          expect(morph.sourceGeometry.borderRadius, expected);
          final surface = tester
              .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
              .first;
          expect(surface.geometry.borderRadius, expected);
          await tester.pumpAndSettle();
          final closeContext = tester.element(find.byType(UiFluidMorph));
          morph.controller.close(closeContext);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final returning = tester
              .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
              .first
              .geometry;
          final target = UiFluidGeometry.lerp(
            returning,
            morph.sourceGeometry,
            1,
          );
          expect(target.borderRadius, expected);
          // Interrupt closing: it must retain the current corner geometry.
          morph.controller.open(closeContext, direct: true);
          await tester.pump();
          expect(
            tester
                .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
                .first
                .geometry
                .borderRadius,
            returning.borderRadius,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
