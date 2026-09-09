import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('async initial load, mixed media prepend and distant jump', (
    tester,
  ) async {
    final items = ValueNotifier<List<UiMessageScrollerItem>>([]);
    final controller = UiMessageScrollerController();
    UiMessageScrollerItem item(int n) => UiMessageScrollerItem(
      id: '$n',
      child: SizedBox(height: n % 3 == 0 ? 420 : 48, child: Text('row $n')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 600,
          child: ValueListenableBuilder(
            valueListenable: items,
            builder: (_, value, _) =>
                UiMessageScroller(items: value, controller: controller),
          ),
        ),
      ),
    );
    items.value = [for (var i = 30; i < 100; i++) item(i)];
    await tester.pumpAndSettle();
    expect(find.text('row 99'), findsOneWidget);
    final jump = controller.jumpToMessage('45', animated: false);
    await tester.pumpAndSettle();
    expect(await jump, isTrue);
    final y = tester.getTopLeft(find.text('row 45')).dy;
    items.value = [for (var i = 0; i < 30; i++) item(i), ...items.value];
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row 45')).dy, closeTo(y, 1));
    expect(controller.unseenCount, 0);
    expect(controller.isAtLiveEdge, isFalse);
    await tester.pumpWidget(const SizedBox());
    items.dispose();
    controller.dispose();
  });

  testWidgets('media above the reading anchor can resize without moving it', (
    tester,
  ) async {
    final height = ValueNotifier<double>(50);
    final controller = UiMessageScrollerController();
    await tester.pumpWidget(
      MaterialApp(
        home: UiMessageScroller(
          controller: controller,
          items: [
            for (var i = 0; i < 40; i++)
              UiMessageScrollerItem(
                id: '$i',
                child: i == 19
                    ? ValueListenableBuilder(
                        valueListenable: height,
                        builder: (_, h, _) =>
                            SizedBox(height: h, child: const Text('media')),
                      )
                    : SizedBox(height: 60, child: Text('item $i')),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final jump = controller.jumpToMessage('20', animated: false);
    await tester.pumpAndSettle();
    expect(await jump, isTrue);
    final top = tester.getTopLeft(find.text('item 20')).dy;
    height.value = 400;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('item 20')).dy, closeTo(top, 1));
    expect(controller.isAtLiveEdge, isFalse);
    await tester.pumpWidget(const SizedBox());
    height.dispose();
    controller.dispose();
  });

  testWidgets(
    'latest respects composer padding and kept-alive jumps stay visible',
    (tester) async {
      final controller = UiMessageScrollerController();
      await tester.pumpWidget(
        MaterialApp(
          home: UiMessageScroller(
            controller: controller,
            padding: const EdgeInsets.only(top: 100, bottom: 150),
            items: [
              for (var i = 0; i < 40; i++)
                UiMessageScrollerItem(
                  id: '$i',
                  child: _KeptMessage(index: i),
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.text('kept 39')).dy, closeTo(450, 1));
      // Visit a row, then keep it alive outside the laid-out range.
      var jump = controller.jumpToMessage('10', animated: false);
      await tester.pumpAndSettle();
      expect(await jump, isTrue);
      final latest = controller.jumpToLatest(animated: false);
      await tester.pumpAndSettle();
      await latest;
      jump = controller.jumpToMessage('10', animated: false);
      await tester.pumpAndSettle();
      expect(await jump, isTrue);
      expect(find.text('kept 10').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('kept 10')).dy, closeTo(300, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('search callbacks debounce and cancel on disposal', (
    tester,
  ) async {
    final values = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: UiInput(
          textInputAction: TextInputAction.search,
          onChanged: values.add,
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'a');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(EditableText), 'ab');
    await tester.pump(const Duration(milliseconds: 299));
    expect(values, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(values, ['ab']);
    await tester.enterText(find.byType(EditableText), 'abc');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(values, ['ab']);
  });

  testWidgets(
    'composer contains input and send and blocks keyboard while disabled',
    (tester) async {
      final controller = TextEditingController(text: 'hello');
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UiChatComposer(
            controller: controller,
            compactSendAction: true,
            disabled: true,
            onSend: (_) => sends++,
          ),
        ),
      );
      final surface = find.byKey(const ValueKey('chat-composer-input-surface'));
      expect(
        find.descendant(of: surface, matching: find.byType(UiInput)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: surface,
          matching: find.byKey(const ValueKey('chat-send-action')),
        ),
        findsOneWidget,
      );
      tester
          .widget<EditableText>(find.byType(EditableText))
          .onSubmitted
          ?.call('hello');
      expect(sends, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('hidden tabs cannot overwrite the visible page history title', (
    tester,
  ) async {
    final observer = UiNavigatorHistoryObserver();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UiNavigatorHistoryScope(
        observer: observer,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: IndexedStack(
            index: 0,
            children: [
              for (final title in ['Chat', 'Hidden library'])
                CustomScrollView(
                  slivers: [
                    UiSliverNavigationBar(spec: UiNavigationSpec(title: title)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    expect(observer.historyItems().map((item) => item.title), ['Chat']);
    await tester.pumpWidget(const SizedBox());
    observer.dispose();
  });

  testWidgets('settled dock search allows its button surface to grow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.bottomCenter,
          child: UiPagedBottomTabBar(
            items: const [
              UiBottomTabItem(label: 'Chat', icon: Icon(Icons.chat)),
            ],
            currentIndex: 0,
            onChanged: (_) {},
            accessory: UiBottomTabAccessory(
              child: UiIconButton(
                key: const Key('accessory-search'),
                icon: const Icon(Icons.search),
                semanticsLabel: 'Search',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final surface = tester.widget<UiFluidSurface>(
      find
          .descendant(
            of: find.byKey(const Key('ui_paged_search_split')),
            matching: find.byType(UiFluidSurface),
          )
          .first,
    );
    expect(surface.clipBehavior, Clip.none);
    final button = find.byKey(const Key('accessory-search'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final transform = tester.widget<Transform>(
      find.descendant(of: button, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.storage[0], greaterThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  test(
    'history replacement preserves order and scopes candidates to current page',
    () {
      final observer = UiNavigatorHistoryObserver();
      PageRoute<void> route(String name) => PageRouteBuilder(
        settings: RouteSettings(name: name),
        pageBuilder: (_, _, _) => const SizedBox(),
      );
      final a = route('A'),
          b = route('B'),
          c = route('C'),
          replacement = route('replacement');
      observer.didPush(a, null);
      observer.didPush(b, a);
      observer.didPush(c, b);
      observer.didReplace(oldRoute: b, newRoute: replacement);
      expect(observer.historyItems().map((i) => i.title), ['replacement', 'A']);
      expect(
        observer.historyItems(currentRoute: replacement).map((i) => i.title),
        ['A'],
      );
      expect(
        (observer.historyItems().first.value as UiNavigationBackPopTarget)
            .route,
        same(replacement),
      );
      observer.dispose();
    },
  );
}

class _KeptMessage extends StatefulWidget {
  const _KeptMessage({required this.index});
  final int index;
  @override
  State<_KeptMessage> createState() => _KeptMessageState();
}

class _KeptMessageState extends State<_KeptMessage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(height: 90, child: Text('kept ${widget.index}'));
  }
}
