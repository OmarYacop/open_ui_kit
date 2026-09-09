import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final dragging in [false, true]) {
    testWidgets('standard list preserves arrivals while dragging=$dragging', (
      tester,
    ) async {
      UiMessageScrollerItem row(int i) => UiMessageScrollerItem(
        id: '$i',
        child: SizedBox(height: i.isEven ? 50 : 180, child: Text('message $i')),
      );
      final items = ValueNotifier(List.generate(80, row));
      final controller = UiMessageScrollerController();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: items,
            builder: (_, value, _) => UiMessageScroller(
              items: value,
              controller: controller,
              initialMessageId: '40',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CustomScrollView), findsNothing);
      final gesture = dragging
          ? await tester.startGesture(const Offset(400, 400))
          : null;
      await gesture?.moveBy(const Offset(0, 60));
      await tester.pump();
      final y = tester.getTopLeft(find.text('message 40')).dy;
      items.value = [...items.value, row(80), row(81)];
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('message 40')).dy, closeTo(y, 1));
      expect(controller.unseenCount, 2);
      if (gesture != null) {
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump();
        expect(
          tester.getTopLeft(find.text('message 40')).dy,
          closeTo(y + 80, 1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      items.dispose();
      controller.dispose();
    });
  }

  testWidgets(
    'streamed tail grows at the live edge and default opening is lazy',
    (tester) async {
      final height = ValueNotifier(60.0);
      final built = <int>{};
      final controller = UiMessageScrollerController();
      await tester.pumpWidget(
        MaterialApp(
          home: UiMessageScroller(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 120),
            items: [
              for (var i = 0; i < 1000; i++)
                UiMessageScrollerItem(
                  id: '$i',
                  child: Builder(
                    builder: (_) {
                      built.add(i);
                      return i == 999
                          ? ValueListenableBuilder(
                              valueListenable: height,
                              builder: (_, value, _) => SizedBox(
                                key: const ValueKey('tail'),
                                height: value,
                              ),
                            )
                          : SizedBox(height: 80, child: Text('message $i'));
                    },
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(built.length, lessThan(30));
      height.value = 320;
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('tail'))).dy,
        closeTo(480, 1),
      );
      expect(controller.isAtLiveEdge, isTrue);
      await tester.pumpWidget(const SizedBox());
      height.dispose();
      controller.dispose();
    },
  );
}
