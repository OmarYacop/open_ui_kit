import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('a swipe cancels the completion of an animated message jump', (
    tester,
  ) async {
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      MaterialApp(
        home: UiMessageScroller(
          controller: controller,
          initialMessageId: '500',
          items: List.generate(
            1000,
            (i) => UiMessageScrollerItem(
              id: '$i',
              child: SizedBox(height: 80, child: Text('row $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final jump = controller.jumpToMessage('503');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    final gesture = await tester.startGesture(const Offset(400, 400));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final offset = state.position.pixels;
    await tester.pumpAndSettle();
    expect(await jump, isFalse);
    expect(state.position.pixels, closeTo(offset, 1));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(state.position.pixels, greaterThan(offset + 50));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('prepending history preserves an active drag', (tester) async {
    UiMessageScrollerItem row(int i) => UiMessageScrollerItem(
      id: '$i',
      child: SizedBox(height: 80, child: Text('row $i')),
    );
    final items = ValueNotifier(List.generate(100, (i) => row(i + 100)));
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: items,
          builder: (_, value, _) =>
              UiMessageScroller(items: value, initialMessageId: '150'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(400, 400));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    final top = tester.getTopLeft(find.text('row 150')).dy;
    items.value = [for (var i = 0; i < 100; i++) row(i), ...items.value];
    await tester.pump();
    expect(tester.getTopLeft(find.text('row 150')).dy, closeTo(top, 1));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(tester.getTopLeft(find.text('row 150')).dy, closeTo(top + 100, 1));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    items.dispose();
  });

  testWidgets('parent rebuild preserves fling momentum', (tester) async {
    final rebuild = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: rebuild,
          builder: (_, value, _) => UiMessageScroller(
            initialMessageId: '500',
            items: List.generate(
              1000,
              (i) => UiMessageScrollerItem(
                id: '$i',
                child: SizedBox(height: 80, child: Text('row $i')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -300), 1500);
    await tester.pump(const Duration(milliseconds: 16));
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = state.position.pixels;
    rebuild.value++;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 32));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable).first),
      same(state),
    );
    expect(state.position.isScrollingNotifier.value, isTrue);
    expect(state.position.pixels, lessThan(before));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    rebuild.dispose();
  });

  testWidgets('reverse swipe survives a pending reading anchor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UiMessageScroller(
          initialMessageId: '500',
          items: List.generate(
            1000,
            (i) => UiMessageScrollerItem(
              id: '$i',
              child: SizedBox(height: 80, child: Text('row $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    final before = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final gesture = await tester.startGesture(const Offset(400, 250));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final after = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final offset = after.position.pixels;
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 16));
    expect(identical(before, after), isTrue);
    expect(after.position.pixels, greaterThan(offset + 50));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('messages mount lazily and parent rebuild preserves a drag', (
    tester,
  ) async {
    final rebuild = ValueNotifier<int>(0);
    final controller = UiMessageScrollerController();
    final built = <int>{};
    final items = List.generate(
      1000,
      (i) => UiMessageScrollerItem(
        id: '$i',
        child: Builder(
          builder: (_) {
            built.add(i);
            return SizedBox(height: 80, child: Text('row $i'));
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (_, value, _) => UiMessageScroller(
            items: items,
            controller: controller,
            initialMessageId: '980',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(built.length, lessThan(100));
    final scrollable = find.byType(Scrollable).first;
    final originalState = tester.state<ScrollableState>(scrollable);
    final gesture = await tester.startGesture(const Offset(400, 400));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(originalState.position.isScrollingNotifier.value, isTrue);
    rebuild.value++;
    await tester.pump();
    await tester.pump();
    final nextState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final offset = nextState.position.pixels;
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(identical(originalState, nextState), isTrue);
    expect(nextState.position.pixels, lessThan(offset - 50));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    rebuild.dispose();
    controller.dispose();
  });
}
