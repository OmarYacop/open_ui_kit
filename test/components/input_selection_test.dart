import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('UiInput provides native text-selection controls', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'A message');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UiInput(controller: controller)),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.selectionControls, isNotNull);
    expect(editable.rendererIgnoresPointer, isTrue);

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    final inputBounds = tester.getRect(find.byType(EditableText));
    await tester.longPressAt(
      Offset(inputBounds.left + 24, inputBounds.center.dy),
    );
    await tester.pump();

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(controller.selection.isCollapsed, isFalse);
    expect(state.selectionOverlay?.toolbarIsVisible, isTrue);
  });
}
