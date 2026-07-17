import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UiNavigationBackButton history flyout RTL (PR-2)', () {
    // The history menu is attached via a CompositedTransformFollower.
    // Before PR-2 it used Alignment.bottomLeft/topLeft (absolute) so
    // the flyout always opened on the physical left. The directional
    // anchors switch to "start"-relative, so in RTL the flyout opens
    // aligned to the trigger's right edge.
    Future<Rect> pumpAndOpen(
      WidgetTester tester, {
      required TextDirection dir,
    }) async {
      const history = [
        UiNavigationBackHistoryItem(title: 'Root'),
        UiNavigationBackHistoryItem(title: 'Shelves'),
      ];
      await tester.pumpWidget(
        _host(
          SafeArea(
            child: Center(
              child: UiNavigationBackButton(
                label: 'Library',
                onPressed: () {},
                history: history,
                onHistorySelected: (_) {},
              ),
            ),
          ),
          dir: dir,
        ),
      );
      await tester.pumpAndSettle();
      // Long-press the trigger to show the history flyout.
      await tester.longPress(find.text('Library'));
      await tester.pumpAndSettle();
      return tester.getRect(find.text('Root'));
    }

    testWidgets('flyout starts aligned with the trigger left edge in LTR',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.ltr);
      final trigger = tester.getRect(find.text('Library'));
      expect(
        menuItem.left,
        lessThanOrEqualTo(trigger.right),
        reason: 'LTR flyout should start no further right than the trigger',
      );
    });

    testWidgets('flyout starts aligned with the trigger right edge in RTL',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.rtl);
      final trigger = tester.getRect(find.text('Library'));
      // In RTL the flyout's "start" is the right edge; so the menu
      // item's right edge should sit at or to the right of the
      // trigger's left edge.
      expect(
        menuItem.right,
        greaterThanOrEqualTo(trigger.left),
        reason: 'RTL flyout should start no further left than the trigger',
      );
    });
  });
}
