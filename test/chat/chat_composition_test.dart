import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(
  Widget child, {
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => UiApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: child),
  ),
);

void main() {
  testWidgets(
    'composer keeps attachment outside and reply/actions inside; draft switches actions',
    (tester) async {
      final controller = UiFormattedTextController();
      addTearDown(controller.dispose);
      var sent = '';
      var recorded = 0;
      await tester.pumpWidget(
        host(
          Center(
            child: SizedBox(
              width: 320,
              child: UiChatComposer.conversation(
                controller: controller,
                onSend: (text) => sent = text,
                onRecord: () => recorded++,
                attachmentItems: [UiMenuItem(label: 'Photo', onPressed: () {})],
                contextShelf: const UiReplyPreview(
                  author: 'Ada',
                  summary: 'A compact quote',
                  variant: UiReplyPreviewVariant.composer,
                ),
              ),
            ),
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('chat-composer-surface'));
      expect(
        find.descendant(of: surface, matching: find.byType(UiReplyPreview)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: surface,
          matching: find.byKey(const ValueKey('open-attachments')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: surface,
          matching: find.byKey(const ValueKey('chat-idle-action')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Record voice message'));
      expect(recorded, 1);
      controller.text = '  Hello  ';
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(sent, 'Hello');
      expect(controller.text, isEmpty);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Record voice message'), findsOneWidget);
    },
  );

  testWidgets(
    'composer handles replacement controllers, disabled input and modes',
    (tester) async {
      final first = TextEditingController(text: 'first');
      final second = TextEditingController(text: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var sends = 0;
      Widget build(
        TextEditingController controller, {
        bool disabled = false,
        Widget? mode,
      }) => host(
        Center(
          child: SizedBox(
            width: 280,
            child: UiChatComposer.conversation(
              controller: controller,
              disabled: disabled,
              modeSurface: mode,
              onSend: (_) => sends++,
            ),
          ),
        ),
        scale: 2,
        direction: TextDirection.rtl,
      );
      await tester.pumpWidget(build(first));
      await tester.pumpWidget(build(second, disabled: true));
      await tester.pumpAndSettle();
      expect(tester.widget<UiInput>(find.byType(UiInput)).enabled, isFalse);
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(sends, 0);
      await tester.pumpWidget(
        build(
          second,
          mode: const Text('Recording', key: ValueKey('recording')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiInput), findsNothing);
      expect(second.text, 'second');
      await tester.pumpWidget(build(second));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scaffold measures changing chrome and reserves keyboard exactly once',
    (tester) async {
      EdgeInsets? historyPadding;
      Widget build(double header, double composer, double inset) => UiApp(
        home: MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
          child: UiChatScaffold(
            fadeHistory: false,
            composerBottomGap: 0,
            header: SizedBox(height: header),
            composer: SizedBox(
              key: const ValueKey('composer'),
              height: composer,
            ),
            historyBuilder: (_, padding) {
              historyPadding = padding;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      await tester.pumpWidget(build(70, 60, 0));
      await tester.pumpAndSettle();
      final first = historyPadding!;
      await tester.pumpWidget(build(110, 120, 200));
      await tester.pumpAndSettle();
      expect(historyPadding!.top - first.top, 40);
      expect(historyPadding!.bottom - first.bottom, 260);
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('composer'))).dy,
        400,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('grouping observes sender, hour and day boundaries', () {
    final time = DateTime(2026, 9, 8, 10, 20);
    UiChatMessageGrouping group(DateTime next, {bool sameSender = true}) =>
        UiChatMessageGrouping.resolve(
          timestamp: time,
          previousTimestamp: time,
          nextTimestamp: next,
          samePreviousSender: true,
          sameNextSender: sameSender,
        );
    expect(group(time.add(const Duration(seconds: 10))).showTimestamp, isFalse);
    expect(group(time.add(const Duration(hours: 1))).showTimestamp, isTrue);
    expect(group(time.add(const Duration(days: 1))).endsGroup, isTrue);
    expect(group(time, sameSender: false).showTimestamp, isTrue);
    expect(group(time, sameSender: false).endsGroup, isTrue);
  });

  test('success is latest-only; sending and failed remain visible', () {
    for (final status in UiMessageDeliveryStatus.values) {
      expect(
        uiChatShowsReceipt(
          outgoing: true,
          latestOutgoing: false,
          status: status,
        ),
        status == UiMessageDeliveryStatus.sending ||
            status == UiMessageDeliveryStatus.failed,
      );
      expect(
        uiChatShowsReceipt(
          outgoing: false,
          latestOutgoing: true,
          status: status,
        ),
        isFalse,
      );
      expect(
        uiChatShowsReceipt(
          outgoing: true,
          latestOutgoing: true,
          status: status,
        ),
        isTrue,
      );
    }
  });

  testWidgets(
    'message selection disables reply and directional swipe fires once',
    (tester) async {
      var replies = 0;
      var selections = 0;
      Widget build({bool selecting = false}) => host(
        Center(
          child: SizedBox(
            width: 320,
            child: UiChatMessage(
              outgoing: true,
              endsGroup: true,
              selectionMode: selecting,
              selected: selecting,
              onSelect: () => selections++,
              onReply: () => replies++,
              child: const Text('Message'),
            ),
          ),
        ),
        direction: TextDirection.rtl,
      );
      await tester.pumpWidget(build());
      await tester.drag(find.text('Message'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
      await tester.pumpWidget(build(selecting: true));
      await tester.tap(find.text('Message'));
      expect(selections, 1);
      await tester.drag(find.text('Message'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timeline projects chronological grouping and date markers', (
    tester,
  ) async {
    final groups = <int, UiChatMessageGrouping>{};
    final time = DateTime(2026, 9, 8, 10, 20);
    await tester.pumpWidget(
      host(
        UiChatTimeline.messages(
          dateLabelBuilder: (date) => 'Day ${date.day}',
          emptyState: const Text('Empty'),
          entries: [
            for (var i = 0; i < 3; i++)
              UiChatTimelineEntry(
                id: 'entry-$i',
                timestamp: time.add(Duration(hours: i == 2 ? 1 : 0)),
                senderId: 'sender',
                outgoing: true,
                builder: (_, grouping) {
                  groups[i] = grouping;
                  return Text('Entry $i');
                },
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Day 8'), findsOneWidget);
    expect(find.text('Empty'), findsNothing);
    expect(groups[0]!.showTimestamp, isFalse);
    expect(groups[1]!.showTimestamp, isTrue);
    expect(groups[2]!.endsGroup, isTrue);
    expect(groups[1]!.startsGroup, isFalse);
  });

  testWidgets(
    'timeline keeps scroller state through typing and error transitions',
    (tester) async {
      final controller = UiMessageScrollerController();
      addTearDown(controller.dispose);
      Widget build({Widget? typing, Widget? error}) => host(
        UiChatTimeline(
          controller: controller,
          typing: typing,
          errorState: error,
          items: const [UiMessageScrollerItem(id: 'one', child: Text('First'))],
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(UiMessageScroller));
      await tester.pumpWidget(
        build(typing: const Text('Typing'), error: const Text('Offline')),
      );
      await tester.pumpAndSettle();
      expect(
        identical(tester.state(find.byType(UiMessageScroller)), state),
        isTrue,
      );
      expect(find.text('Offline'), findsOneWidget);
    },
  );
}
