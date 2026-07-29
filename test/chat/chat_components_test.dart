import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/components/chat.dart';
import 'package:open_ui_kit/foundation.dart';
import 'package:open_ui_kit/patterns/chat.dart';

void main() {
  testWidgets('bubble constrains width and aligns to the logical end', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: UiBubble(
            alignment: UiChatAlignment.end,
            child: Text('Outgoing'),
          ),
        ),
      ),
    );

    final bubble = tester.getRect(find.text('Outgoing'));
    expect(bubble.center.dx, lessThan(400));
  });

  testWidgets('attachment exposes transfer state and independent actions', (
    tester,
  ) async {
    var actionPressed = false;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        UiAttachment(
          title: 'lesson.pdf',
          description: 'Could not upload',
          state: UiAttachmentState.error,
          actions: [
            TextButton(
              onPressed: () => actionPressed = true,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(UiAttachment)),
      matchesSemantics(
        label: 'lesson.pdf, Could not upload, upload failed',
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(actionPressed, isTrue);
    semantics.dispose();
  });

  testWidgets('attachment group bounds default horizontal attachments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          height: 120,
          child: UiAttachmentGroup(
            children: [
              UiAttachment(title: 'first.pdf'),
              UiAttachment(title: 'second.pdf'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(UiAttachment), findsNWidgets(2));
  });

  testWidgets('message keeps the outgoing avatar after its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const UiMessage(
          alignment: UiChatAlignment.end,
          avatar: SizedBox(key: Key('avatar'), width: 32, height: 32),
          child: Text('Hello'),
        ),
      ),
    );

    expect(
      tester.getTopRight(find.text('Hello')).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('avatar'))).dx),
    );
  });

  testWidgets('marker supports an actionable separator', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _host(
        UiMarker(
          label: 'Unread messages',
          variant: UiMarkerVariant.separator,
          onPressed: () => pressed = true,
        ),
      ),
    );

    await tester.tap(find.text('Unread messages'));
    expect(pressed, isTrue);
  });

  testWidgets('legacy outgoing message keeps on-primary text contrast', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const UiMessageBubble(
          text: 'Legacy message',
          author: UiMessageAuthor.outgoing,
        ),
      ),
    );

    final text = tester.widget<UiText>(
      find.descendant(
        of: find.byType(UiMessageBubble),
        matching: find.byType(UiText),
      ),
    );
    expect(text.style?.color, UiThemeTokens.light.colors.onPrimary);
  });

  testWidgets(
      'scroller holds position and reports arrivals away from live edge',
      (tester) async {
    final controller = UiMessageScrollerController();
    final key = GlobalKey<_ScrollerHarnessState>();
    await tester
        .pumpWidget(_host(_ScrollerHarness(key: key, controller: controller)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(controller.isAtLiveEdge, isFalse);

    key.currentState!.append();
    await tester.pump();
    await tester.pump();

    expect(controller.unseenCount, 1);
    expect(find.text('1 new message'), findsOneWidget);

    await tester.tap(find.text('1 new message'));
    await tester.pumpAndSettle();
    expect(controller.isAtLiveEdge, isTrue);
    expect(controller.unseenCount, 0);
  });

  testWidgets('scroller jumps to a variable-height offscreen message', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      _host(
        UiMessageScroller(
          controller: controller,
          startAtEnd: false,
          items: [
            for (var index = 0; index < 60; index++)
              UiMessageScrollerItem(
                id: '$index',
                child: SizedBox(
                  height: index.isEven ? 32 : 180,
                  child: Text('Variable $index'),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump();

    final jump = controller.jumpToMessage('47', animated: false);
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump();
    }
    expect(await jump, isTrue);
    expect(find.text('Variable 47'), findsOneWidget);
  });
}

Widget _host(Widget child) {
  return UiApp(
    home: Scaffold(
      body: SizedBox(width: 800, height: 600, child: child),
    ),
  );
}

class _ScrollerHarness extends StatefulWidget {
  const _ScrollerHarness({super.key, required this.controller});

  final UiMessageScrollerController controller;

  @override
  State<_ScrollerHarness> createState() => _ScrollerHarnessState();
}

class _ScrollerHarnessState extends State<_ScrollerHarness> {
  var count = 30;

  void append() => setState(() => count++);

  @override
  Widget build(BuildContext context) {
    return UiMessageScroller(
      controller: widget.controller,
      padding: const EdgeInsets.all(16),
      items: [
        for (var index = 0; index < count; index++)
          UiMessageScrollerItem(
            id: '$index',
            child: SizedBox(height: 56, child: Text('Message $index')),
          ),
      ],
    );
  }
}
