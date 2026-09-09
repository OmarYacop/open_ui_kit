import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets(
    'press grows continuously and release/repress retarget without jumps',
    (tester) async {
      var taps = 0;
      const iconKey = ValueKey('fixed icon');
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: UiIconButton(
              size: UiSize.lg,
              icon: const SizedBox(key: iconKey, width: 20, height: 20),
              semanticsLabel: 'Action',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      final button = find.byType(UiIconButton);
      final box = find.descendant(of: button, matching: find.byType(UiBox));
      double scale() => tester
          .widget<Transform>(
            find.ancestor(of: box, matching: find.byType(Transform)).first,
          )
          .transform
          .entry(0, 0);
      final bounds = tester.getRect(button);
      final press = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 110));
      expect(scale(), 1);
      await tester.pump(const Duration(milliseconds: 40));
      final mid = scale();
      expect(mid, greaterThan(1));
      expect(mid, lessThan(1.14));
      expect(tester.getRect(find.byKey(iconKey)).size, const Size(20, 20));
      expect(tester.getRect(button), bounds);
      await press.up();
      await tester.pump();
      expect(
        taps,
        1,
        reason: 'Activation must not wait for the return animation',
      );
      expect(scale(), closeTo(mid, .00001));
      await tester.pump(const Duration(milliseconds: 40));
      expect(scale(), lessThan(mid));
      expect(scale(), greaterThan(1));
      final second = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 110));
      final repressed = scale();
      await tester.pump(const Duration(milliseconds: 30));
      expect(scale(), greaterThan(repressed));
      await second.cancel();
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(taps, 1);
      expect(tester.getRect(button), bounds);
    },
  );

  testWidgets('reduced motion keeps the button at its resting size', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: UiIconButton(
              icon: const SizedBox(width: 20, height: 20),
              semanticsLabel: 'Action',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final press = await tester.startGesture(
      tester.getCenter(find.byType(UiIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    for (final transform in tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(UiIconButton),
        matching: find.byType(Transform),
      ),
    )) {
      expect(transform.transform.entry(0, 0), 1);
    }
    await press.cancel();
    await tester.pumpAndSettle();
  });
}
