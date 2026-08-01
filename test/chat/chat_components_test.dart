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
    expect(controller.firstUnseenMessageId, '30');
    expect(find.byType(UiMessageQueueBadge), findsOneWidget);

    final jumpToQueued = controller.jumpToFirstUnseen();
    await tester.pumpAndSettle();
    expect(await jumpToQueued, isTrue);
    expect(controller.isAtLiveEdge, isTrue);
    expect(controller.unseenCount, 0);

    final jumpToLatest = controller.jumpToLatest();
    await tester.pumpAndSettle();
    await jumpToLatest;
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

  testWidgets('scroller keeps an unread boundary until an outgoing append', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    final key = GlobalKey<_ScrollerHarnessState>();
    await tester.pumpWidget(
      _host(
        _ScrollerHarness(
          key: key,
          controller: controller,
          initialUnreadMessageId: '24',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiUnreadMessagesMarker), findsOneWidget);
    expect(controller.hasUnreadMarker, isTrue);
    expect(
      tester.getTopLeft(find.text('Unread messages')).dy,
      lessThan(tester.getTopLeft(find.text('Message 24')).dy),
    );

    key.currentState!.append();
    await tester.pumpAndSettle();
    expect(find.byType(UiUnreadMessagesMarker), findsOneWidget);

    key.currentState!.append(outgoing: true);
    await tester.pumpAndSettle();
    expect(find.byType(UiUnreadMessagesMarker), findsNothing);
    expect(controller.hasUnreadMarker, isFalse);
  });

  testWidgets('scroller controller can dismiss the unread boundary', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      _host(
        _ScrollerHarness(
          controller: controller,
          initialUnreadMessageId: '24',
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.dismissUnreadMarker();
    await tester.pump();

    expect(find.byType(UiUnreadMessagesMarker), findsNothing);
  });

  testWidgets('outgoing append follows the live edge while reading history', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    final key = GlobalKey<_ScrollerHarnessState>();
    await tester.pumpWidget(
      _host(_ScrollerHarness(key: key, controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 260));
    await tester.pumpAndSettle();
    expect(controller.isAtLiveEdge, isFalse);

    key.currentState!.append(outgoing: true);
    await tester.pumpAndSettle();

    expect(controller.isAtLiveEdge, isTrue);
    expect(controller.unseenCount, 0);
  });

  testWidgets('scroll controls expand reply action beside latest', (
    tester,
  ) async {
    var replyPressed = false;
    var latestPressed = false;
    await tester.pumpWidget(
      _host(
        UiMessageScrollControls(
          show: true,
          queuedMessageCount: 4,
          replyReturnCount: 2,
          onScrollToBottom: () => latestPressed = true,
          onReplyReturn: () => replyPressed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UiMessageQueueBadge), findsOneWidget);
    expect(find.byType(UiMessageReplyReturnButton), findsOneWidget);
    expect(find.byType(UiMessageScrollToBottomButton), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    final replyRect = tester.getRect(
      find.byType(UiMessageReplyReturnButton),
    );
    final latestRect = tester.getRect(
      find.byType(UiMessageScrollToBottomButton),
    );
    expect(replyRect.height, closeTo(latestRect.height, .01));
    expect(replyRect.width, greaterThan(latestRect.width));
    expect(replyRect.center.dy, latestRect.center.dy);
    expect(replyRect.right, lessThanOrEqualTo(latestRect.left));
    await tester.tap(find.byType(UiMessageReplyReturnButton));
    await tester.tap(find.byType(UiMessageScrollToBottomButton));
    expect(replyPressed, isTrue);
    expect(latestPressed, isTrue);
  });

  testWidgets('reply action springs in when controls mount with a stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiMessageScrollControls(
          show: true,
          queuedMessageCount: 0,
          replyReturnCount: 1,
          onScrollToBottom: () {},
          onReplyReturn: () {},
        ),
      ),
    );

    final controls = find.byKey(const ValueKey('message-scroll-controls'));
    final initialWidth = tester.getSize(controls).width;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final animatedWidth = tester.getSize(controls).width;
    await tester.pumpAndSettle();
    final settledWidth = tester.getSize(controls).width;

    expect(animatedWidth, greaterThan(initialWidth));
    expect(settledWidth, greaterThan(initialWidth));

    await tester.pumpWidget(
      _host(
        UiMessageScrollControls(
          show: true,
          queuedMessageCount: 0,
          onScrollToBottom: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 75));
    final exitingWidth = tester.getSize(controls).width;
    await tester.pumpAndSettle();
    final exitedWidth = tester.getSize(controls).width;

    expect(exitingWidth, lessThan(settledWidth));
    expect(exitingWidth, greaterThan(exitedWidth));
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
  const _ScrollerHarness({
    super.key,
    required this.controller,
    this.initialUnreadMessageId,
  });

  final UiMessageScrollerController controller;
  final String? initialUnreadMessageId;

  @override
  State<_ScrollerHarness> createState() => _ScrollerHarnessState();
}

class _ScrollerHarnessState extends State<_ScrollerHarness> {
  var count = 30;
  final Set<int> outgoing = {};

  void append({bool outgoing = false}) => setState(() {
        if (outgoing) this.outgoing.add(count);
        count++;
      });

  @override
  Widget build(BuildContext context) {
    return UiMessageScroller(
      controller: widget.controller,
      initialUnreadMessageId: widget.initialUnreadMessageId,
      padding: const EdgeInsets.all(16),
      items: [
        for (var index = 0; index < count; index++)
          UiMessageScrollerItem(
            id: '$index',
            isOutgoing: outgoing.contains(index),
            child: SizedBox(height: 56, child: Text('Message $index')),
          ),
      ],
    );
  }
}
