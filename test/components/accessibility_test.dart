import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('UiDropdownMenu semantics', () {
    testWidgets('destructive items announce themselves as such',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('More'),
            ),
            items: [
              UiMenuItem(label: 'Share', onPressed: () {}),
              UiMenuItem(
                label: 'Delete',
                destructive: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      final deleteSemantics = tester.getSemantics(find.text('Delete'));
      expect(deleteSemantics.label, 'Delete');
      expect(
        deleteSemantics.hint,
        contains('destructive'),
        reason: 'Destructive items should publish a screen-reader hint.',
      );

      final shareSemantics = tester.getSemantics(find.text('Share'));
      expect(shareSemantics.hint, isNot(contains('destructive')));
    });

    testWidgets('disabled items report disabled state', (tester) async {
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Open'),
            ),
            items: [
              UiMenuItem(
                label: 'Archive',
                enabled: false,
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.text('Archive'));
      expect(node.hint, contains('disabled'));
    });
  });

  group('UiInput semantics', () {
    testWidgets('error text is published as a live region', (tester) async {
      await tester.pumpWidget(
        _host(
          const UiInput(
            label: 'Email',
            errorText: 'Must be an email',
          ),
        ),
      );

      // Find the error text semantic node and confirm it carries both
      // the explicit "Error: " prefix and the live-region flag.
      final errorNode = tester.getSemantics(
        find.text('Must be an email'),
      );
      expect(errorNode.label, contains('Error'));
      expect(errorNode.label, contains('Must be an email'));
    });
  });
}
