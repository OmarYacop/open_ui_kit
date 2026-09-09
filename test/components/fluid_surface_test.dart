import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('trigger holds, cancels and supports keyboard activation', (
    tester,
  ) async {
    final controller = UiFluidController(vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(
            width: 90,
            height: 48,
            child: UiFluidTrigger(
              controller: controller,
              label: 'Open actions',
              child: const Text('More'),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('More')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.value, .2);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(controller.value, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.value, 1);
  });

  testWidgets(
    'split keeps multiple actions in one surface and gates hidden semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final controller = UiFluidController(vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        UiApp(
          home: SizedBox(
            width: 320,
            height: 100,
            child: UiFluidSplit(
              controller: controller,
              sourceGeometry: const UiFluidGeometry(
                Rect.fromLTWH(240, 20, 64, 48),
                24,
              ),
              color: const Color(0xffdddddd),
              source: const Text('Edit'),
              branches: const [
                UiFluidBranch(
                  geometry: UiFluidGeometry(Rect.fromLTWH(80, 20, 140, 48), 24),
                  child: Row(children: [Text('Find'), Text('Add')]),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(UiFluidSplit)).toStringDeep(),
        isNot(contains('Find')),
      );
      for (final t in [.1, .3, .5, .8, 1.0, .7, .2, 0.0]) {
        controller.value = t;
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Edit'), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(UiFluidSplit)).toStringDeep(),
          t > .15 ? contains('Find') : isNot(contains('Find')),
        );
      }
      semantics.dispose();
    },
  );
}
