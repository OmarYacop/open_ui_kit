import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('UiFormattedTextParser', () {
    test('parses default operators and leaves unclosed operators alone', () {
      final parser = UiFormattedTextParser(UiFormattedTextRule.defaults());
      final matches = parser.parse(
        r'**bold** _italic_ ~~gone~~ `code` __line__ ==mark== **',
      );

      expect(matches.map((match) => match.rule.id), [
        'bold',
        'italic',
        'strikethrough',
        'code',
        'underline',
        'highlight',
      ]);
    });

    test('ignores escaped opening operators', () {
      final parser = UiFormattedTextParser(UiFormattedTextRule.defaults());

      expect(parser.parse(r'\**plain**'), isEmpty);
    });
  });

  group('UiFormattedTextController', () {
    test('wraps, unwraps, and restores the selected content range', () {
      final controller = UiFormattedTextController(text: 'hello world')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);

      expect(controller.toggle('bold'), isTrue);
      expect(controller.text, '**hello** world');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );

      expect(controller.toggle('bold'), isTrue);
      expect(controller.text, 'hello world');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    });

    test('inserts an empty pair with the caret between operators', () {
      final controller = UiFormattedTextController(text: 'Say ')
        ..selection = const TextSelection.collapsed(offset: 4);

      controller.toggle('italic');

      expect(controller.text, 'Say __');
      expect(controller.selection.baseOffset, 5);
    });
  });

  testWidgets('display strips operators and applies their styles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const UiFormattedText('A **bold** move')));

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    final root = richText.text as TextSpan;
    final bold = root.children!.whereType<TextSpan>().firstWhere(
      (span) => span.style?.fontWeight == FontWeight.w700,
    );

    expect(root.toPlainText(includeSemanticsLabels: false), 'A bold move');
    expect(bold.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('display composes nested operators', (tester) async {
    await tester.pumpWidget(
      _host(const UiFormattedText('**bold and _italic_**')),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    final root = richText.text as TextSpan;
    final bold = root.children!.whereType<TextSpan>().first;
    final italic = bold.children!.whereType<TextSpan>().firstWhere(
      (span) => span.style?.fontStyle == FontStyle.italic,
    );

    expect(root.toPlainText(includeSemanticsLabels: false), 'bold and italic');
    expect(bold.style?.fontWeight, FontWeight.w700);
    expect(italic.style?.fontWeight, FontWeight.w700);
    expect(italic.style?.fontStyle, FontStyle.italic);
  });

  testWidgets('toolbar exposes accessible formatting actions', (tester) async {
    final controller = UiFormattedTextController(text: 'hello')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pumpWidget(_host(UiFormatToolbar(controller: controller)));

    expect(find.bySemanticsLabel('Text formatting'), findsOneWidget);
    final boldAction = find.byWidgetPredicate(
      (widget) => widget is UiPressable && widget.semanticsLabel == 'Bold',
    );
    expect(boldAction, findsOneWidget);
    await tester.tap(boldAction);
    expect(controller.text, '**hello**');
  });
}
