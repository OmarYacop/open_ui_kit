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
    'tapping expand while the accessory is still fading in (presence < 1)',
    (tester) async {
      var index = 0;
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: UiTheme(
            tokens: UiThemeTokens.light,
            child: StatefulBuilder(
              builder: (context, setState) {
                return UiBottomTabScaffold(
                  items: _items,
                  currentIndex: index,
                  onChanged: (i) => setState(() {
                    index = i;
                    if (i == 0) expanded = false;
                  }),
                  pages: const [
                    SizedBox.expand(),
                    SizedBox.expand(),
                    SizedBox.expand(),
                  ],
                  bottomAccessory: index == 0
                      ? null
                      : UiBottomTabAccessory(
                          expanded: expanded,
                          leadingItem: _items[index],
                          onLeadingPressed: () =>
                              setState(() => expanded = false),
                          child: UiPressable(
                            onPressed: () => setState(() => expanded = true),
                            semanticsLabel: 'Search',
                            builder: (context, state, _) =>
                                const Center(child: Icon(Icons.search)),
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Messages: presence starts fading the accessory in.
      await tester.tap(find.text('Messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      final accessoryKey = find.byKey(const Key('ui_bottom_tab_accessory'));
      final beforeExpand = tester.getRect(accessoryKey);
      // ignore: avoid_print
      print('accessory rect just before expand tap: $beforeExpand');

      // Interrupt: request expand while presence is still animating in.
      await tester.tap(find.bySemanticsLabel('Search'), warnIfMissed: false);
      for (final step in [
        const Duration(milliseconds: 1),
        const Duration(milliseconds: 20),
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 150),
        const Duration(milliseconds: 200),
      ]) {
        await tester.pump(step);
        final r = accessoryKey.evaluate().isEmpty
            ? null
            : tester.getRect(accessoryKey);
        // ignore: avoid_print
        print('accessory rect at +${step.inMilliseconds}ms: $r');
      }
      await tester.pumpAndSettle();
      final settled = tester.getRect(accessoryKey);
      // ignore: avoid_print
      print('accessory rect settled: $settled');
      expect(tester.takeException(), isNull);
      expect(expanded, isTrue);
    },
  );
}
