import 'dart:io';

import 'package:contour_example/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'switching from a tab with no accessory to one with an accessory',
    (tester) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      app.main();
      await tester.pumpAndSettle();

      final demoFinder = find.byKey(
        const ValueKey('real-bottom-tab-accessory-demo'),
      );
      await tester.scrollUntilVisible(
        demoFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Starting on Home: no accessory island should exist at all, within
      // this demo's own subtree (the page also has an unrelated Contour
      // prototype with its own "Search" trigger higher up).
      expect(
        find.descendant(
          of: demoFinder,
          matching: find.bySemanticsLabel('Search'),
        ),
        findsNothing,
      );
      final homeDockWidth = tester
          .getRect(find.byKey(const Key('ui_bottom_tab_dock')))
          .width;
      if (Platform.isMacOS) {
        await expectLater(
          demoFinder,
          matchesGoldenFile(
            'goldens/accessory_switch_00_home_no_accessory.png',
          ),
        );
      }

      // Switch to Messages, which does have a search accessory.
      await tester.tap(
        find.descendant(of: demoFinder, matching: find.text('Messages')),
      );
      await tester.pump();
      if (Platform.isMacOS) {
        await expectLater(
          demoFinder,
          matchesGoldenFile(
            'goldens/accessory_switch_01_messages_first_frame.png',
          ),
        );
      }

      // Sample frames across the nominal 200ms structural transition.
      final samples = <String, double>{};
      for (final step in [
        Duration.zero,
        const Duration(milliseconds: 16),
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 150),
        const Duration(milliseconds: 200),
      ]) {
        await tester.pump(step);
        final accessoryFinder = find.byKey(
          const Key('ui_bottom_tab_accessory'),
        );
        final width = accessoryFinder.evaluate().isEmpty
            ? 0.0
            : tester.getRect(accessoryFinder).width;
        samples['${step.inMilliseconds}ms'] = width;
        final dockWidth = tester
            .getRect(find.byKey(const Key('ui_bottom_tab_dock')))
            .width;
        // ignore: avoid_print
        print(
          'accessory width at +${step.inMilliseconds}ms: '
          '${width.toStringAsFixed(1)}, dock width: '
          '${dockWidth.toStringAsFixed(1)}',
        );
      }
      await tester.pumpAndSettle();

      final finalAccessoryFinder = find.byKey(
        const Key('ui_bottom_tab_accessory'),
      );
      expect(finalAccessoryFinder, findsOneWidget);
      final settledWidth = tester.getRect(finalAccessoryFinder).width;
      // ignore: avoid_print
      print('accessory width settled: ${settledWidth.toStringAsFixed(1)}');
      // ignore: avoid_print
      print('dock width on Home (no accessory): $homeDockWidth');
      final messagesDockWidth = tester
          .getRect(find.byKey(const Key('ui_bottom_tab_dock')))
          .width;
      // ignore: avoid_print
      print('dock width on Messages (with accessory): $messagesDockWidth');

      expect(tester.takeException(), isNull);
    },
  );
}
