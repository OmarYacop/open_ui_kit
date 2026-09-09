import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final mode in UiBottomTabOverflowBehavior.values) {
    for (final custom in [false, true]) {
      testWidgets('$mode: same accessory stays sharp (custom: $custom)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var index = 0;
        var icon = Icons.search;
        var pressed = -1;
        late StateSetter update;
        const items = [
          UiBottomTabItem(label: 'Home'),
          UiBottomTabItem(label: 'Library'),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final destination = index;
                final button = UiIconButton(
                  icon: Icon(icon),
                  semanticsLabel: 'Action $index',
                  onPressed: () => pressed = destination,
                );
                return UiBottomTabScaffold(
                  overflowBehavior: mode,
                  items: items,
                  currentIndex: index,
                  onChanged: (value) => setState(() => index = value),
                  pages: const [SizedBox.expand(), SizedBox.expand()],
                  bottomAccessory: UiBottomTabAccessory(
                    contentKey: custom ? icon : null,
                    leadingItem: items[index],
                    child: custom ? Center(child: button) : button,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => index = 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byIcon(Icons.search),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ImageFiltered &&
                  widget.imageFilter !=
                      ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            ),
          ),
          findsNothing,
        );
        expect(find.bySemanticsLabel('Action 0'), findsNothing);
        await tester.tap(find.bySemanticsLabel('Action 1'));
        expect(pressed, 1);
        await tester.pumpAndSettle();

        // An actual content change must dissolve even on the same page.
        update(() => icon = Icons.add);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byIcon(Icons.add),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is ImageFiltered &&
                  widget.imageFilter !=
                      ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            ),
          ),
          findsWidgets,
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsNothing);
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
