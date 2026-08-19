import 'package:contour_example/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo app renders and the real bottom tab accessory expands', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    app.main();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final demoFinder = find.byKey(
      const ValueKey('real-bottom-tab-accessory-demo'),
    );
    await tester.scrollUntilVisible(
      demoFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // The demo starts on Home, which has no search accessory at all —
    // switch to Messages first, which does.
    await tester.tap(
      find.descendant(of: demoFinder, matching: find.text('Messages')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      demoFinder,
      matchesGoldenFile('goldens/real_bottom_tab_collapsed.png'),
    );

    await tester.tap(
      find.descendant(
        of: demoFinder,
        matching: find.bySemanticsLabel('Search'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(of: demoFinder, matching: find.text('Search messages…')),
      findsWidgets,
    );

    await expectLater(
      demoFinder,
      matchesGoldenFile('goldens/real_bottom_tab_expanded.png'),
    );
  });
}
