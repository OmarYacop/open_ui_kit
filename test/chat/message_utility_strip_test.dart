import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/chat.dart';
import 'package:open_ui_kit/foundation.dart';

void main() {
  testWidgets('message utility strip exposes labeled equal-width actions', (
    tester,
  ) async {
    var replied = false;
    var deleted = false;
    await tester.pumpWidget(
      _host(
        UiMessageUtilityStrip(
          selectionLabel: '2 selected',
          closeLabel: 'Cancel selection',
          onClose: () {},
          actions: [
            UiMessageUtilityAction(
              id: 'reply',
              icon: Icons.reply_rounded,
              label: 'Reply',
              onPressed: () => replied = true,
            ),
            UiMessageUtilityAction(
              id: 'delete',
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              intent: UiIntent.danger,
              onPressed: () => deleted = true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    final replyRect = tester.getRect(find.bySemanticsLabel('Reply'));
    final deleteRect = tester.getRect(find.bySemanticsLabel('Delete'));
    expect(replyRect.width, closeTo(deleteRect.width, .01));
    expect(replyRect.height, greaterThanOrEqualTo(48));
    expect(replyRect.center.dy, closeTo(deleteRect.center.dy, .01));

    await tester.tap(find.bySemanticsLabel('Reply'));
    await tester.tap(find.bySemanticsLabel('Delete'));
    expect(replied, isTrue);
    expect(deleted, isTrue);
  });

  testWidgets('message utility strip keeps bottom breathing room', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiMessageUtilityStrip(
          selectionLabel: '1 selected',
          closeLabel: 'Cancel selection',
          onClose: () {},
          actions: [
            UiMessageUtilityAction(
              id: 'reply',
              icon: Icons.reply_rounded,
              label: 'Reply',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stripBottom = tester
        .getBottomLeft(find.byType(UiMessageUtilityStrip))
        .dy;
    final actionBottom = tester
        .getBottomLeft(find.bySemanticsLabel('Reply'))
        .dy;
    expect(stripBottom - actionBottom, greaterThanOrEqualTo(12));
  });
}

Widget _host(Widget child) {
  return UiApp(
    home: Scaffold(body: SizedBox(width: 390, height: 600, child: child)),
  );
}
