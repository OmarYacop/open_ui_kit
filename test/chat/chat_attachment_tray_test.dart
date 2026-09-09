import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  UiChatDraftAttachment item(
    String id, {
    bool media = true,
    VoidCallback? remove,
    VoidCallback? preview,
  }) => UiChatDraftAttachment(
    id: id,
    name: '$id very long attachment name.pdf',
    description: 'PDF · 2.4 MB',
    removeLabel: 'Remove $id',
    previewLabel: 'Preview $id',
    onRemove: remove ?? () {},
    onPreview: preview ?? () {},
    mediaBuilder: media
        ? (_, fit) => const SizedBox(
            width: 210,
            height: 140,
            child: ColoredBox(color: Color(0xff234567)),
          )
        : null,
  );

  Widget host(
    Widget shelf, {
    bool disabled = false,
    ValueChanged<String>? send,
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
  }) => UiApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: direction,
        child: Center(
          child: SizedBox(
            width: 320,
            child: UiChatComposer.conversation(
              disabled: disabled,
              onSend: send ?? (_) {},
              allowEmptySend: true,
              attachmentShelf: shelf,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'single preview is bounded inside composer; preview and remove are distinct',
    (tester) async {
      var previews = 0;
      var removals = 0;
      String? caption;
      await tester.pumpWidget(
        host(
          UiChatAttachmentTray(
            attachments: [
              item(
                'photo',
                preview: () => previews++,
                remove: () => removals++,
              ),
            ],
          ),
          send: (text) => caption = text,
        ),
      );
      await tester.pumpAndSettle();
      final tray = tester.getRect(find.byType(UiChatAttachmentTray));
      final surface = tester.getRect(
        find.byKey(const ValueKey('chat-composer-surface')),
      );
      expect(surface.contains(tray.topLeft), isTrue);
      expect(surface.contains(tray.bottomRight), isTrue);
      expect(tray.height, 140);
      await tester.tap(find.bySemanticsLabel('Preview photo'));
      await tester.pumpAndSettle();
      expect(previews, 1);
      await tester.tap(find.bySemanticsLabel('Remove photo'));
      await tester.pumpAndSettle();
      expect(removals, 1);
      expect(previews, 1);
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(caption, '');
    },
  );

  testWidgets(
    'media batch scrolls to add and file removal survives narrow RTL large text',
    (tester) async {
      var added = 0;
      await tester.pumpWidget(
        host(
          UiChatAttachmentTray(
            attachments: [
              for (var i = 0; i < 5; i++) item('photo$i'),
              item('file', media: false),
            ],
            onAdd: () => added++,
          ),
          scale: 2,
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(UiChatAttachmentTray)).height,
        lessThanOrEqualTo(160),
      );
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(600, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Add attachment'));
      await tester.pumpAndSettle();
      expect(added, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled tray disables preview removal and add', (tester) async {
    var commands = 0;
    await tester.pumpWidget(
      host(
        UiChatAttachmentTray(
          enabled: false,
          onAdd: () => commands++,
          attachments: [
            item('a', remove: () => commands++, preview: () => commands++),
            item('b'),
          ],
        ),
        disabled: true,
      ),
    );
    await tester.pumpAndSettle();
    for (final button in tester.widgetList<UiIconButton>(
      find.byType(UiIconButton),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tapAt(
      tester.getBottomLeft(find.bySemanticsLabel('Preview a')) +
          const Offset(12, -12),
    );
    expect(commands, 0);
  });

  testWidgets(
    'removing last attachment preserves caption and returns to normal composer',
    (tester) async {
      var staged = true;
      final controller = TextEditingController(text: 'Keep my caption');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (_, setState) => UiChatComposer.conversation(
                  controller: controller,
                  onSend: (_) {},
                  allowEmptySend: staged,
                  attachmentShelf: staged
                      ? UiChatAttachmentTray(
                          attachments: [
                            item(
                              'file',
                              media: false,
                              remove: () => setState(() => staged = false),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Remove file'));
      await tester.pumpAndSettle();
      expect(find.byType(UiChatAttachmentTray), findsNothing);
      expect(controller.text, 'Keep my caption');
      expect(tester.takeException(), isNull);
    },
  );
}
