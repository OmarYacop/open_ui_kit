import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(Widget child) => UiApp(
  home: Center(child: SizedBox(width: 320, child: child)),
);

void main() {
  testWidgets('filters pasted codes and completes only on user text edits', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final completed = <String>[];
    await tester.pumpWidget(
      host(
        UiOtpInput(
          controller: controller,
          groupLength: 3,
          onCompleted: completed.add,
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await tester.enterText(find.byType(EditableText), '12-34 567');
    await tester.pump();
    expect(controller.text, '123456');
    expect(completed, ['123456']);
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(completed.length, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, '13456');
    controller.text = '654321';
    await tester.pump();
    expect(completed.length, 1);
  });

  testWidgets('slot taps replace characters and support alphanumeric codes', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'AB12');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        UiOtpInput(
          length: 4,
          type: UiOtpInputType.alphanumeric,
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'AZ12',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    expect(controller.text, 'AZ12');
  });

  testWidgets('long press opens editing actions', (tester) async {
    await tester.pumpWidget(host(const UiOtpInput(initialValue: '123456')));
    await tester.longPress(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets(
    'keyboard editing keeps active slots visible in narrow RTL fields',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        UiApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 180,
                child: UiOtpInput(controller: controller, groupLength: 3),
              ),
            ),
          ),
        ),
      );
      final scroll = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;
      expect(scroll.offset, 0);
      await tester.tap(find.byType(GestureDetector).first);
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      expect(scroll.offset, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(controller.selection.extentOffset, 0);
      expect(scroll.offset, 0);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).autofillHints,
        [AutofillHints.oneTimeCode],
      );
    },
  );

  testWidgets('selected first slot stays visible in a one-slot viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(width: 50, child: UiOtpInput(initialValue: '123456')),
        ),
      ),
    );
    await tester.tap(find.text('1'));
    await tester.pump();
    final scroll = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .controller!;
    expect(scroll.offset, 0);
  });

  testWidgets('controller handoff preserves value and external ownership', (
    tester,
  ) async {
    final controller = TextEditingController(text: '123');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      host(UiOtpInput(controller: controller, focusNode: focus)),
    );
    await tester.pumpWidget(host(const UiOtpInput()));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '123',
    );
    controller.text = '456';
    focus.requestFocus();
    await tester.pumpWidget(const SizedBox());
    expect(controller.text, '456');
  });

  testWidgets('disabled prevents focus and read-only keeps editing locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const UiOtpInput(enabled: false, initialValue: '123456')),
    );
    await tester.tap(find.text('1'));
    await tester.pump();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.readOnly, isTrue);
    await tester.pumpWidget(host(const UiOtpInput(readOnly: true)));
    await tester.tap(find.text('1'));
    await tester.pump();
    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.readOnly, isTrue);
  });

  testWidgets('one semantic text field and no narrow RTL large-text overflow', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      host(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Align(
              child: SizedBox(
                width: 180,
                child: UiOtpInput(
                  label: 'Verification code',
                  errorText: 'Try again',
                  groupLength: 3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SingleChildScrollView)).width, 180);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.bySemanticsLabel('Verification code'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
