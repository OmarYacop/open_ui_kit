import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const _items = [
  UiBottomTabItem(label: 'Home'),
  UiBottomTabItem(label: 'Messages'),
  UiBottomTabItem(label: 'Profile'),
];

void main() {
  testWidgets(
    'UiBottomTabScaffold: switching to a tab whose accessory just became available',
    (tester) async {
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UiTheme(
            tokens: UiThemeTokens.light,
            child: StatefulBuilder(
              builder: (context, setState) {
                return UiBottomTabScaffold(
                  items: _items,
                  currentIndex: index,
                  onChanged: (i) => setState(() => index = i),
                  pages: const [
                    SizedBox.expand(),
                    SizedBox.expand(),
                    SizedBox.expand(),
                  ],
                  // Only Messages/Profile offer search — same asymmetry as
                  // the raw UiBottomTabBar test.
                  bottomAccessory: index == 0
                      ? null
                      : const UiBottomTabAccessory(child: Icon(Icons.search)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ui_bottom_tab_accessory')), findsNothing);

      await tester.tap(find.text('Messages'));

      for (final step in [
        Duration.zero,
        const Duration(milliseconds: 16),
        const Duration(milliseconds: 40),
        const Duration(milliseconds: 80),
        const Duration(milliseconds: 120),
        const Duration(milliseconds: 160),
        const Duration(milliseconds: 200),
      ]) {
        await tester.pump(step);
        final finder = find.byKey(const Key('ui_bottom_tab_accessory'));
        final width = finder.evaluate().isEmpty
            ? 0.0
            : tester.getRect(finder).width;
        // ignore: avoid_print
        print(
          'UiBottomTabScaffold accessory width at '
          '+${step.inMilliseconds}ms: ${width.toStringAsFixed(1)}',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('ui_bottom_tab_accessory')), findsOneWidget);
    },
  );
}
