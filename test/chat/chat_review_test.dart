import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(Widget child) => UiApp(home: child);

void main() {
  testWidgets('offset morph clips in local coordinates throughout transition', (
    tester,
  ) async {
    for (final progress in [0.0, 0.5, 1.0]) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        host(
          Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 120,
                height: 120,
                child: ColoredBox(
                  color: const Color(0xFF000000),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 30, top: 40),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: UiMeasuredMorph(
                        progress: progress,
                        collapsed: const SizedBox(
                          width: 60,
                          height: 40,
                          child: ColoredBox(color: Color(0xFFFF0000)),
                        ),
                        expanded: const SizedBox(
                          width: 60,
                          height: 40,
                          child: ColoredBox(color: Color(0xFFFF0000)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(() => boundary.toImage()))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      int redAt(int x, int y) => bytes.getUint8((y * image.width + x) * 4);
      expect(redAt(32, 42), greaterThan(150), reason: 'left/top at $progress');
      expect(
        redAt(87, 77),
        greaterThan(150),
        reason: 'right/bottom at $progress',
      );
      expect(redAt(28, 42), 0);
      expect(redAt(92, 77), 0);
      image.dispose();
    }
  });

  testWidgets(
    'recording deck retains draft and exposes only cancel and finish',
    (tester) async {
      final draft = TextEditingController(text: 'Keep my draft');
      addTearDown(draft.dispose);
      late StateSetter update;
      var recording = false;
      var seconds = 1;
      var finishes = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 320,
                  child: UiChatComposer.conversation(
                    controller: draft,
                    onSend: (_) {},
                    attachmentItems: [
                      UiMenuItem(label: 'File', onPressed: () {}),
                    ],
                    actionMode: recording
                        ? UiChatComposerActions(
                            selectionLabel: 'Recording',
                            closeLabel: 'Cancel recording',
                            onClose: () => update(() => recording = false),
                            primary: UiMessageUtilityAction(
                              id: 'finish-recording',
                              icon: LucideIcons.check,
                              label: 'Finish recording',
                              intent: UiIntent.primary,
                              onPressed: () {
                                finishes++;
                                update(() => recording = false);
                              },
                            ),
                            content: Text('0:0$seconds'),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
      final input = tester.element(find.byType(UiInput));
      update(() => recording = true);
      await tester.pumpAndSettle();
      expect(find.text('0:01'), findsOneWidget);
      expect(find.byType(UiDropdownMenu), findsNothing);
      update(() => seconds = 2);
      await tester.pumpAndSettle();
      expect(find.text('0:02'), findsOneWidget);
      await tester.longPress(find.bySemanticsLabel('Cancel recording'));
      await tester.pumpAndSettle();
      expect(find.text('File'), findsNothing);
      expect(recording, isFalse);
      expect(tester.element(find.byType(UiInput)), same(input));
      expect(draft.text, 'Keep my draft');
      update(() => recording = true);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Finish recording'));
      await tester.pumpAndSettle();
      expect(finishes, 1);
      expect(draft.text, 'Keep my draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reply dismissal has visible button chrome and a full tap target',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(
          Center(
            child: SizedBox(
              width: 300,
              child: UiReplyPreview(
                variant: UiReplyPreviewVariant.composer,
                author: 'Author',
                summary: 'Reply',
                onDismiss: () => dismissed++,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(UiIconButton);
      expect(tester.widget<UiIconButton>(button).intent, UiIntent.neutral);
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(44));
      await tester.tap(find.bySemanticsLabel('Cancel reply'));
      expect(dismissed, 1);
    },
  );

  testWidgets(
    'message quote sits near bubble edge while body retains its inset',
    (tester) async {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          host(
            Directionality(
              textDirection: direction,
              child: const Center(
                child: SizedBox(
                  width: 390,
                  child: UiChatMessage(
                    reply: UiReplyPreview(
                      author: 'Author',
                      summary: 'Quoted message',
                    ),
                    child: SizedBox(
                      key: ValueKey('reply-body'),
                      height: 20,
                      width: 120,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final bubbleBox = find
            .descendant(of: find.byType(UiBubble), matching: find.byType(UiBox))
            .first;
        final bubble = tester.getRect(bubbleBox);
        final quote = tester.getRect(find.byType(UiReplyPreview));
        final body = tester.getRect(find.byKey(const ValueKey('reply-body')));
        expect(quote.left - bubble.left, 4);
        expect(bubble.right - quote.right, 4);
        expect(quote.top - bubble.top, 4);
        expect(body.left - bubble.left, 8);
        expect(body.top - quote.bottom, 4);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'preview uses remaining width instead of splitting with timestamp',
    (tester) async {
      await tester.pumpWidget(
        host(
          Center(
            child: SizedBox(
              width: 390,
              child: UiConversationTile(
                title: 'Sandbox support',
                avatar: const SizedBox(width: 48, height: 48),
                timestamp: '9:16 AM',
                preview: const SizedBox(key: ValueKey('preview'), height: 20),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('preview'))).width,
        greaterThan(195),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retry is a single compact inline recovery action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      host(
        Center(
          child: UiMessageReceipt(
            status: UiMessageDeliveryStatus.failed,
            timestamp: '10:42',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.text('Failed to send'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      tester.getSize(find.byType(UiMessageReceipt)).height,
      lessThanOrEqualTo(32),
    );
    await tester.tap(find.bySemanticsLabel('Retry'));
    expect(retries, 1);
  });

  testWidgets(
    'composer sits eight pixels above keyboard with no extra history gap',
    (tester) async {
      EdgeInsets? reserve;
      await tester.pumpWidget(
        UiApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 200),
            ),
            child: UiChatScaffold(
              header: const SizedBox(height: 52),
              fadeHistory: false,
              historyBuilder: (_, padding) {
                reserve = padding;
                return const SizedBox.expand();
              },
              composer: UiChatComposer.conversation(onSend: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.getRect(
        find.byKey(const ValueKey('chat-composer-surface')),
      );
      expect(surface.bottom, 392);
      expect(reserve!.bottom, 264);
    },
  );

  testWidgets(
    'Contour keeps left control and draft through selection reversal',
    (tester) async {
      final draft = TextEditingController(text: 'Unsent draft');
      addTearDown(draft.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      late StateSetter update;
      var selecting = false;
      var selectedCount = 1;
      var deletes = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 320,
                  child: UiChatComposer.conversation(
                    controller: draft,
                    focusNode: focus,
                    onSend: (_) {},
                    attachmentItems: [
                      UiMenuItem(label: 'File', onPressed: () {}),
                    ],
                    actionMode: !selecting
                        ? null
                        : UiChatComposerActions(
                            selectionLabel: '$selectedCount selected',
                            selectedCount: selectedCount,
                            closeLabel: 'Close selection',
                            onClose: () => update(() => selecting = false),
                            primary: UiMessageUtilityAction(
                              id: 'delete',
                              icon: LucideIcons.trash2,
                              label: 'Delete',
                              intent: UiIntent.danger,
                              onPressed: () => deletes++,
                            ),
                            actions: [
                              UiMessageUtilityAction(
                                id: 'reply',
                                icon: LucideIcons.reply,
                                label: 'Reply',
                                onPressed: () {},
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      final left = tester.getRect(
        find.byKey(const ValueKey('open-attachments')),
      );
      final inputElement = tester.element(find.byType(UiInput));
      update(() => selecting = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      update(() => selecting = false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(draft.text, 'Unsent draft');
      expect(tester.element(find.byType(UiInput)), same(inputElement));
      update(() => selecting = true);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('open-attachments'))),
        left,
      );
      expect(find.bySemanticsLabel('Close selection'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      update(() => selectedCount = 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final growing = tester
          .getSize(find.byKey(const ValueKey('selection-close-surface')))
          .width;
      expect(growing, greaterThan(left.width));
      await tester.pumpAndSettle();
      final wide = tester.getRect(
        find.byKey(const ValueKey('open-attachments')),
      );
      expect(wide.width, greaterThan(left.width));
      expect(growing, lessThan(wide.width));
      expect(find.text('2'), findsOneWidget);
      update(() => selectedCount = 1);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('open-attachments'))),
        left,
      );
      expect(find.text('1'), findsNothing);

      expect(find.byType(UiDropdownMenu), findsNothing);
      await tester.longPress(find.bySemanticsLabel('Close selection'));
      await tester.pumpAndSettle();
      expect(find.text('File'), findsNothing);
      // A held close button may activate on release, but never opens a menu.
      update(() => selecting = true);
      await tester.pumpAndSettle();
      final delete = tester.widget<UiIconButton>(
        find.byKey(const ValueKey('selection-primary-delete')),
      );
      expect(delete.backgroundColor, UiThemeTokens.light.colors.danger);
      expect(delete.backgroundColor!.a, 1);
      await tester.tap(find.bySemanticsLabel('Delete'));
      expect(deletes, 1);
      await tester.tap(find.bySemanticsLabel('Close selection'));
      await tester.pumpAndSettle();
      expect(draft.text, 'Unsent draft');
      expect(tester.takeException(), isNull);
    },
  );
}
