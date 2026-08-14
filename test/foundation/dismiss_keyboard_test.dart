import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart';

void main() {
  testWidgets('UiDismissKeyboard clears focus when its surface is tapped', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UiDismissKeyboard(
          child: SizedBox(
            width: 300,
            height: 300,
            child: Align(
              alignment: Alignment.topLeft,
              child: Focus(
                focusNode: focusNode,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(250, 250));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });
}
