import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('alert actions align with both lower corners in $direction', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        UiApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 350,
                child: UiAlertDialog(
                  title: 'Delete Account',
                  description: 'This action cannot be undone.',
                  confirmLabel: 'Delete',
                  intent: UiAlertDialogIntent.destructive,
                  onConfirm: () => confirmed++,
                  onCancel: () => cancelled++,
                ),
              ),
            ),
          ),
        ),
      );
      final surface = tester.getRect(
        find
            .descendant(
              of: find.byType(UiAlertDialog),
              matching: find.byType(UiBox),
            )
            .first,
      );
      final actions = tester.getRect(
        find.byKey(const ValueKey('ui-alert-dialog-actions-stacked')),
      );
      expect(actions.left - surface.left, 12);
      expect(surface.right - actions.right, 12);
      expect(surface.bottom - actions.bottom, 12);
      final title = tester.getRect(find.text('Delete Account'));
      expect(title.left - surface.left, 20);
      expect(surface.right - title.right, 20);
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Cancel'));
      expect(confirmed, 1);
      expect(cancelled, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
