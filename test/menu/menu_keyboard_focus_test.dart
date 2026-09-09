import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// A menu opened while a soft keyboard is up (an attachment menu next to a
/// focused composer) must neither steal the field's focus nor tear itself
/// down when the keyboard inset changes.
void main() {
  testWidgets('menu opened over a soft keyboard keeps field focus and stays', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final field = FocusNode();
    addTearDown(field.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: field, autofocus: true),
              UiDropdownMenu(
                trigger: const Text('Attach'),
                items: [
                  UiMenuItem(label: 'Photos', onPressed: () {}),
                  UiMenuItem(label: 'Files', onPressed: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(field.hasPrimaryFocus, isTrue);

    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);
    expect(field.hasPrimaryFocus, isTrue);

    // Keyboard retreats: the menu follows its anchor instead of vanishing.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsNothing);
    expect(field.hasPrimaryFocus, isTrue);
  });

  testWidgets('menu opened without a keyboard still takes focus for keys', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiDropdownMenu(
            trigger: const Text('Actions'),
            items: [
              UiMenuItem(label: 'First', onPressed: () => selected = 'First'),
              UiMenuItem(label: 'Second', onPressed: () => selected = 'Second'),
            ],
          ),
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
  });
}
