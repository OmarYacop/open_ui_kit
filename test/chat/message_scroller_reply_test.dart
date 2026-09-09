import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets(
    'near-edge arrival preserves an active touch instead of following',
    (tester) async {
      UiMessageScrollerItem row(int i) => UiMessageScrollerItem(
        id: '$i',
        child: SizedBox(height: 80, child: Text('row $i')),
      );
      final items = ValueNotifier(List.generate(30, row));
      final controller = UiMessageScrollerController();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: items,
            builder: (_, value, _) =>
                UiMessageScroller(items: value, controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(20);
      await tester.pumpAndSettle();
      expect(controller.isAtLiveEdge, isTrue);
      final gesture = await tester.startGesture(const Offset(400, 400));
      final top = tester.getTopLeft(find.text('row 28')).dy;
      items.value = [...items.value, row(30)];
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('row 28')).dy, closeTo(top, 1));
      expect(controller.unseenCount, 1);
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(tester.getTopLeft(find.text('row 28')).dy, lessThan(top - 40));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      items.dispose();
      controller.dispose();
    },
  );

  testWidgets(
    'visible reply target does not recenter and near-bottom offset stays put',
    (tester) async {
      final controller = UiMessageScrollerController();
      await tester.pumpWidget(
        MaterialApp(
          home: UiMessageScroller(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 120),
            items: List.generate(
              30,
              (i) => UiMessageScrollerItem(
                id: '$i',
                child: SizedBox(height: 80, child: Text('row $i')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(30);
      await tester.pumpAndSettle();
      expect(controller.isMessageVisible('28'), isTrue);
      final top = tester.getTopLeft(find.text('row 28')).dy;
      expect(await controller.jumpToMessage('28', onlyIfNeeded: true), isTrue);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('row 28')).dy, top);
      expect(list.controller!.offset, 30);
      expect(controller.isMessageVisible('0'), isFalse);
      final jump = controller.jumpToMessage('29', onlyIfNeeded: true);
      await tester.pumpAndSettle();
      expect(await jump, isTrue);
      expect(controller.isMessageVisible('29'), isTrue);
      final settled = list.controller!.offset;
      await tester.pump(const Duration(seconds: 1));
      expect(list.controller!.offset, settled);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('live-edge appends stay pinned on every frame', (tester) async {
    UiMessageScrollerItem row(int i) => UiMessageScrollerItem(
      id: '$i',
      child: SizedBox(height: i.isEven ? 80 : 160, child: Text('row $i')),
    );
    final items = ValueNotifier(List.generate(30, row));
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: items,
          builder: (_, value, _) => UiMessageScroller(
            items: value,
            controller: controller,
            padding: const EdgeInsets.only(bottom: 120),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 30; i < 35; i++) {
      items.value = [...items.value, row(i)];
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getBottomLeft(find.text('row $i')).dy, closeTo(480, 1));
      }
      expect(controller.isAtLiveEdge, isTrue);
      expect(controller.unseenCount, 0);
    }
    await tester.pumpWidget(const SizedBox());
    items.dispose();
    controller.dispose();
  });
}
