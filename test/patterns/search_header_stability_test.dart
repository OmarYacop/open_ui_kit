import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('search keyboard avoidance preserves scrolled header state', (
    tester,
  ) async {
    Widget page(bool searching) => UiApp(
      home: UiPageScaffold(
        resizeBodyForKeyboard: searching,
        body: CustomScrollView(
          slivers: [
            UiSliverNavigationBar(
              spec: UiNavigationSpec(
                title: 'Chats',
                actions: [
                  UiIconButton(
                    icon: const Icon(IconData(0xe001)),
                    semanticsLabel: 'Filter',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final offset = state.position.pixels;
    await tester.pumpWidget(page(true));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable).first),
      same(state),
    );
    expect(state.position.pixels, offset);
    await tester.pumpWidget(page(false));
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable).first),
      same(state),
    );
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets('conversation title truncates beside unread count $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        UiApp(
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 280,
                child: UiConversationTile(
                  title: 'A very long conversation title that must stay on one line',
                  preview: const Text('Latest message'),
                  unread: true,
                  unreadCountLabel: '12',
                  timestamp: '12:30',
                ),
              ),
            ),
          ),
        ),
      );
      final title = tester.widget<UiText>(
        find.byWidgetPredicate(
          (w) => w is UiText && w.data.startsWith('A very long'),
        ),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(
        tester.getCenter(find.text(title.data)).dy,
        closeTo(tester.getCenter(find.text('12')).dy, 1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
