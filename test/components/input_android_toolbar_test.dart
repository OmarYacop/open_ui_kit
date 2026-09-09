import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Without a native system context menu (Android), a long press must show the
/// standard-looking Material toolbar with localized actions.
void main() {
  testWidgets('long press on Android shows the ported selection toolbar', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'A message');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      UiApp(
        lightTokens: UiThemeTokens.light,
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        home: Center(child: UiInput(controller: controller)),
      ),
    );
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final bounds = tester.getRect(find.byType(EditableText));
    await tester.longPressAt(Offset(bounds.left + 24, bounds.center.dy));
    await tester.pumpAndSettle();

    expect(find.byType(UiTextSelectionToolbar), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
    expect(find.text('selectAll'), findsNothing);
    final toolbar = tester.getSize(find.byType(UiTextSelectionToolbar));
    expect(toolbar.height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(controller.selection.textInside(controller.text), 'A message');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
