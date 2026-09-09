import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final scale in [1.0, 1.15, 2.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('pill has balanced visible insets at $scale $direction', (
        tester,
      ) async {
        var replyTaps = 0;
        var latestTaps = 0;
        await tester.pumpWidget(
          UiApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: direction,
                child: Center(
                  child: UiMessageScrollControls(
                    show: true,
                    queuedMessageCount: 0,
                    replyReturnCount: 12,
                    onReplyReturn: () => replyTaps++,
                    onScrollToBottom: () => latestTaps++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final group = find.byKey(const ValueKey('message-scroll-controls'));
        final pillBox = find
            .descendant(of: group, matching: find.byType(UiBox))
            .first;
        final pill = tester.getRect(
          find
              .descendant(of: pillBox, matching: find.byType(DecoratedBox))
              .first,
        );
        final reply = find.byType(UiMessageReplyReturnButton);
        final latest = find.byType(UiMessageScrollToBottomButton);
        Rect surface(Finder control) => tester.getRect(
          find.descendant(of: control, matching: find.byType(UiBox)).first,
        );
        final replyRect = surface(reply);
        final latestRect = surface(latest);
        final left = direction == TextDirection.ltr ? replyRect : latestRect;
        final right = direction == TextDirection.ltr ? latestRect : replyRect;
        final inset = left.left - pill.left;
        expect(inset, greaterThanOrEqualTo(3.99));
        expect(pill.right - right.right, closeTo(inset, .01));
        expect(replyRect.top - pill.top, closeTo(inset, .01));
        expect(pill.bottom - replyRect.bottom, closeTo(inset, .01));
        expect(latestRect.center.dy, closeTo(replyRect.center.dy, .01));
        expect(latestRect.height, scale < 2 ? 34 : greaterThan(34));
        expect(pill.height, scale < 2 ? 44 : latestRect.height + 8);
        for (final control in [reply, latest]) {
          expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(control).width, greaterThanOrEqualTo(44));
          await tester.tapAt(
            tester.getRect(control).topLeft + const Offset(1, 1),
          );
        }
        expect(replyTaps, 1);
        expect(latestTaps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
