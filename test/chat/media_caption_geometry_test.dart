import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final reply in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets('captioned media stays evenly inset reply=$reply rtl=$rtl', (
        tester,
      ) async {
        await tester.pumpWidget(
          UiApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Center(
                child: UiChatMessage(
                  outgoing: true,
                  fullMediaCorners: true,
                  reply: reply
                      ? const SizedBox(height: 36, child: UiText('Reply'))
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 240,
                        height: 180,
                        key: Key('media'),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(4),
                        child: UiText('Caption'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bubble = tester.getRect(
          find
              .descendant(
                of: find.byType(UiBubble),
                matching: find.byType(UiBox),
              )
              .first,
        );
        final media = tester.getRect(find.byKey(const Key('media')));
        expect(media.left - bubble.left, 4);
        expect(bubble.right - media.right, 4);
        expect(media.top - bubble.top, reply ? 40 : 4);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
