import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(
  Widget child, {
  bool reduced = false,
  double width = 600,
  double scale = 1,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: UiTheme(
      tokens: UiThemeTokens.light,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14),
        child: Center(
          child: SizedBox(width: width, height: 500, child: child),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets('button respects reduced motion on press', (tester) async {
    await tester.pumpWidget(
      host(UiButton(label: 'Save', onPressed: () {}), reduced: true),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(UiButton),
            matching: find.byType(Transform),
          )
          .first,
    );
    await gesture.up();
    expect(transform.transform.entry(0, 0), 1);
  });
  testWidgets('alert does not announce its copy twice', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const UiAlert(
          title: 'Saved',
          description: 'Your work is saved.',
          intent: UiAlertIntent.success,
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(UiAlert));
    expect(
      node.getSemanticsData().label,
      'Success: Saved — Your work is saved.',
    );
    semantics.dispose();
  });
  testWidgets('tooltip appears on keyboard focus', (tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(
      UiApp(
        home: UiTooltip(
          message: 'Save document',
          child: UiButton(label: 'Save', focusNode: focus, onPressed: () {}),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Save document'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
  });
}
