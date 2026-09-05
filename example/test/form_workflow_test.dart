import 'package:contour_example/form_workflow.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('form example saves selected teams and text as one snapshot', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      UiApp(home: FormWorkflowExample(onSave: (value) async => saved = value)),
    );
    await tester.enterText(find.byType(EditableText).first, 'Ada');
    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save teammate'));
    await tester.pumpAndSettle();
    expect(saved!['name'], 'Ada');
    expect(saved!['teams'], {'design'});
    expect(find.text('Teammate saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
