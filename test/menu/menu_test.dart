import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('dropdown opens from trigger and closes on outside tap',
      (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Open menu'),
          items: [
            UiMenuItem(label: 'Profile', onPressed: () {}),
          ],
        ),
      ),
    );

    expect(find.text('Profile'), findsNothing);

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('dropdown closes when the trigger is tapped again',
      (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Open menu'),
          items: [
            UiMenuItem(label: 'Profile', onPressed: () {}),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Open menu')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('keyboard navigation activates focused row with Enter',
      (tester) async {
    var selected = '';
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Actions'),
          items: [
            UiMenuItem(label: 'First', onPressed: () => selected = 'First'),
            UiMenuItem(label: 'Second', onPressed: () => selected = 'Second'),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected, 'Second');
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('destructive and disabled rows expose semantics hints',
      (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('More'),
          items: [
            UiMenuItem(label: 'Delete', destructive: true, onPressed: () {}),
            UiMenuItem(label: 'Archive', enabled: false, onPressed: () {}),
          ],
        ),
      ),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    final destructiveNode = tester.getSemantics(find.text('Delete'));
    expect(destructiveNode.hint, contains('destructive'));

    final disabledNode = tester.getSemantics(find.text('Archive'));
    expect(disabledNode.hint, contains('disabled'));
  });
}
