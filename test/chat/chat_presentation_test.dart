import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(
  Widget child, {
  double width = 320,
  bool dark = false,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => UiApp(
  mode: dark ? UiThemeMode.dark : UiThemeMode.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: direction,
      child: SingleChildScrollView(
        child: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('conversation surfaces retain borders and unread contrast', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      final colors = (dark ? UiThemeTokens.dark : UiThemeTokens.light).colors;
      for (final unread in [false, true]) {
        await tester.pumpWidget(
          host(
            UiConversationTile(
              title: 'Chat',
              preview: const Text('Preview'),
              unread: unread,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final decoration =
            tester
                    .widget<AnimatedContainer>(
                      find
                          .descendant(
                            of: find.byType(UiConversationTile),
                            matching: find.byType(AnimatedContainer),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, unread ? colors.surfaceMuted : colors.surface);
        expect(decoration.border, Border.all(color: colors.border));
      }
      await tester.pumpWidget(
        host(
          const UiConversationTile(
            title: 'Chat',
            preview: Text('Preview'),
            selected: true,
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<AnimatedContainer>(
                    find
                        .descendant(
                          of: find.byType(UiConversationTile),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.border, Border.all(color: colors.primary));
    }
  });

  testWidgets(
    'delivery states announce their meaning and retry only failures',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var retries = 0;
      for (final status in UiMessageDeliveryStatus.values) {
        await tester.pumpWidget(
          host(
            UiMessageReceipt(
              status: status,
              statusLabel: 'Localized ${status.name}',
              timestamp: '10:42',
              onRetry: () => retries++,
            ),
          ),
        );
        expect(
          find.bySemanticsLabel('Localized ${status.name}'),
          findsOneWidget,
        );
        expect(
          find.text('Retry'),
          status == UiMessageDeliveryStatus.failed
              ? findsOneWidget
              : findsNothing,
        );
      }
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'reply navigation and dismissal are independent keyboard actions',
    (tester) async {
      var jumps = 0;
      var cancels = 0;
      await tester.pumpWidget(
        host(
          UiReplyPreview(
            author: 'Ada',
            summary: 'Lesson notes',
            onPressed: () => jumps++,
            onDismiss: () => cancels++,
          ),
        ),
      );
      await tester.tap(find.text('Lesson notes'));
      expect(jumps, 1);
      await tester.tap(find.bySemanticsLabel('Cancel reply'));
      expect(cancels, 1);
      expect(jumps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(jumps + cancels, 3);
    },
  );

  testWidgets(
    'conversation reports selected and unread state and blocks disabled presses',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var opens = 0;
      await tester.pumpWidget(
        host(
          UiConversationTile(
            title: 'Study group',
            preview: const UiText('Latest message'),
            unread: true,
            selected: true,
            unreadCountLabel: '3',
            unreadLabel: '3 unread messages',
            enabled: false,
            onPressed: () => opens++,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('3 unread messages')),
        findsOneWidget,
      );
      await tester.tap(find.text('Study group'));
      expect(opens, 0);
      semantics.dispose();
    },
  );

  testWidgets('compact large-text RTL and dark states fit without overflow', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiReplyPreview(
                author: 'A participant with a very long name',
                summary: 'A long quoted message that wraps naturally and remains readable.',
                onDismiss: () {},
              ),
              UiMessageReceipt(
                status: UiMessageDeliveryStatus.failed,
                timestamp: '10:42 AM',
                statusLabel: 'The message could not be sent',
                onRetry: () {},
              ),
              const UiConversationTile(
                title: 'A very long conversation title',
                preview: UiText(
                  'A long preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                timestamp: 'Yesterday',
                unread: true,
                unreadCountLabel: '99+',
                pinned: true,
                muted: true,
                avatar: UiAvatar(name: 'Ada', size: 40),
              ),
            ],
          ),
          width: 280,
          dark: dark,
          scale: 2,
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'conversation reserves header and changing dock/keyboard extents',
    (tester) async {
      EdgeInsets? reserved;
      Future<void> render(double keyboard) => tester.pumpWidget(
        host(
          SizedBox(
            height: 600,
            child: UiConversationLayout(
              header: const SizedBox(height: 60),
              composer: const SizedBox(height: 80),
              headerExtent: 60,
              composerExtent: 80,
              composerBottomGap: 16,
              obscuredBottomInset: keyboard,
              fadeHistory: false,
              historyBuilder: (_, padding) {
                reserved = padding;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      await render(0);
      final initial = reserved!;
      expect(initial.top, greaterThanOrEqualTo(60));
      expect(initial.bottom, greaterThanOrEqualTo(96));
      await render(250);
      expect(reserved!.bottom - initial.bottom, 250);
      expect(tester.takeException(), isNull);
    },
  );
}
