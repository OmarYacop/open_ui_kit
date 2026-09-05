import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Widget _bar({required bool showLabel, required VoidCallback onPressed}) {
  return CustomScrollView(
    slivers: [
      UiSliverNavigationBar(
        spec: UiNavigationSpec(
          title: 'Details',
          back: UiNavigationBackConfig(
            label: 'A very long previous page title',
            showLabel: showLabel,
            onPressed: onPressed,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 800)),
    ],
  );
}

void main() {
  testWidgets('back button shows its label by default', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _host(_bar(showLabel: true, onPressed: () => pressed = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('A very long previous page title'), findsOneWidget);

    await tester.tap(find.byType(UiNavigationBackButton));
    expect(pressed, isTrue);
  });

  testWidgets(
    'showLabel: false hides the label but keeps it as the semantics label and stays tappable',
    (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _host(_bar(showLabel: false, onPressed: () => pressed = true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('A very long previous page title'), findsNothing);
      expect(
        find.bySemanticsLabel('A very long previous page title'),
        findsOneWidget,
      );

      await tester.tap(find.byType(UiNavigationBackButton));
      expect(pressed, isTrue);
    },
  );

  testWidgets(
    'hiding the label shrinks the leading footprint that reserves title width',
    (tester) async {
      await tester.pumpWidget(_host(_bar(showLabel: true, onPressed: () {})));
      await tester.pumpAndSettle();
      final withLabelWidth = tester
          .getSize(find.byType(UiNavigationBackButton))
          .width;

      await tester.pumpWidget(_host(_bar(showLabel: false, onPressed: () {})));
      await tester.pumpAndSettle();
      final iconOnlyWidth = tester
          .getSize(find.byType(UiNavigationBackButton))
          .width;

      // `_CompactRow` reserves `middleSideReserve` for the centered title
      // based directly on the back button's max width, so a smaller leading
      // footprint here is what frees more room for a longer title.
      expect(iconOnlyWidth, lessThan(withLabelWidth));
    },
  );
}
