import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: child),
  );
}

// A stable, easy-to-measure body so we can compare rendered heights
// across expand/collapse states.
const _bodyHeight = 120.0;
const _bodyKey = Key('collapsible_body');

Widget _body() {
  return const SizedBox(
    key: _bodyKey,
    height: _bodyHeight,
    child: Text('Body'),
  );
}

Widget _header({String label = 'Trigger'}) {
  return Container(
    padding: const EdgeInsets.all(12),
    child: Text(label),
  );
}

void main() {
  group('UiCollapsible (uncontrolled)', () {
    testWidgets('starts collapsed by default and drops body from the tree',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiCollapsible(
            header: _header(),
            child: _body(),
          ),
        ),
      );
      expect(find.byKey(_bodyKey), findsNothing);
    });

    testWidgets('initiallyExpanded = true renders body at full height',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiCollapsible(
            initiallyExpanded: true,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_bodyKey), findsOneWidget);
      expect(tester.getSize(find.byKey(_bodyKey)).height, _bodyHeight);
    });

    testWidgets('tap header toggles open → close', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          UiCollapsible(
            header: _header(),
            onExpandedChanged: changes.add,
            child: _body(),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.byKey(_bodyKey), findsOneWidget);
      expect(changes, [true]);

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.byKey(_bodyKey), findsNothing);
      expect(changes, [true, false]);
    });
  });

  group('UiCollapsible (controlled)', () {
    testWidgets(
        'header tap fires callback but does NOT change render until the '
        'parent updates `expanded`', (tester) async {
      var expanded = false;
      var calls = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiCollapsible(
              header: _header(),
              expanded: expanded,
              onExpandedChanged: (_) => calls++,
              child: _body(),
            ),
          ),
        ),
      );

      // Tap: callback fires but parent state still says collapsed, so
      // body must remain absent.
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byKey(_bodyKey), findsNothing);

      // Now the parent flips expanded → body must appear.
      await tester.pumpWidget(
        _host(
          UiCollapsible(
            header: _header(),
            expanded: true,
            onExpandedChanged: (_) => calls++,
            child: _body(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_bodyKey), findsOneWidget);
    });
  });

  group('UiCollapsible (controller-driven)', () {
    testWidgets('controller drives expand/collapse and notifies listeners',
        (tester) async {
      final controller = UiCollapsibleController();
      addTearDown(controller.dispose);
      var notifies = 0;
      controller.addListener(() => notifies++);

      await tester.pumpWidget(
        _host(
          UiCollapsible(
            controller: controller,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      expect(controller.isExpanded, isFalse);
      expect(find.byKey(_bodyKey), findsNothing);

      controller.expand();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
      expect(find.byKey(_bodyKey), findsOneWidget);
      expect(notifies, 1);

      controller.toggle();
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isFalse);
      expect(notifies, 2);
    });

    testWidgets('header tap calls controller.toggle()', (tester) async {
      final controller = UiCollapsibleController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          UiCollapsible(
            controller: controller,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(controller.isExpanded, isTrue);
    });
  });

  group('UiCollapsible (a11y + keyboard)', () {
    testWidgets(
        'header semantics expose the `expanded` flag matching render state',
        (tester) async {
      final controller = UiCollapsibleController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          UiCollapsible(
            controller: controller,
            header: _header(),
            semanticsLabel: 'Show details',
            child: _body(),
          ),
        ),
      );

      bool? currentExpanded() {
        final widgets = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.label == 'Show details');
        return widgets.isEmpty ? null : widgets.first.properties.expanded;
      }

      expect(currentExpanded(), isFalse);

      controller.expand();
      await tester.pumpAndSettle();
      expect(currentExpanded(), isTrue);
    });

    testWidgets('Enter on a focused header toggles the collapsible',
        (tester) async {
      final controller = UiCollapsibleController();
      addTearDown(controller.dispose);
      final node = FocusNode();
      addTearDown(node.dispose);

      await tester.pumpWidget(
        _host(
          UiCollapsible(
            controller: controller,
            focusNode: node,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.isExpanded, isTrue);
    });
  });

  group('UiCollapsible (lifecycle)', () {
    testWidgets(
        'internal controller is disposed with the widget without throwing',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiCollapsible(
            initiallyExpanded: true,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'maintainState keeps child mounted while collapsed (state preserved)',
        (tester) async {
      final controller = UiCollapsibleController(initiallyExpanded: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          UiCollapsible(
            controller: controller,
            maintainState: true,
            header: _header(),
            child: _body(),
          ),
        ),
      );
      expect(find.byKey(_bodyKey), findsOneWidget);

      controller.collapse();
      await tester.pumpAndSettle();
      // With maintainState the subtree still exists (hit-test height
      // is zero via ClipRect/Align, but the widget is in the tree).
      expect(find.byKey(_bodyKey), findsOneWidget);
    });
  });
}
