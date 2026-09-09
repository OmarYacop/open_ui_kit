import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _barPage(String title) {
  return CustomScrollView(
    slivers: [
      UiSliverNavigationBar(spec: UiNavigationSpec(title: title)),
      const SliverToBoxAdapter(child: SizedBox(height: 800)),
    ],
  );
}

Widget _chatPage(String title, {List<UiNavigationBackHistoryItem>? history}) {
  return Builder(
    builder: (context) => Column(
      children: [
        UiChatHeader(
          title: title,
          leading: UiNavigationBackButton(
            label: 'Back',
            history: history,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    ),
  );
}

class _Host extends StatefulWidget {
  const _Host({required this.observer, required this.navigator});

  final UiNavigatorHistoryObserver observer;
  final GlobalKey<NavigatorState> navigator;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) {
    return UiNavigatorHistoryScope(
      observer: widget.observer,
      child: MaterialApp(
        navigatorKey: widget.navigator,
        navigatorObservers: [widget.observer],
        home: _barPage('Home'),
      ),
    );
  }
}

Future<void> _push(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  Widget page,
) async {
  navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pumpAndSettle();
}

Future<void> _longPress(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'back button in custom chrome lists the navigator history and pops to '
    'the picked page',
    (tester) async {
      final observer = UiNavigatorHistoryObserver();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_Host(observer: observer, navigator: navigator));
      await tester.pumpAndSettle();
      await _push(tester, navigator, _barPage('Chats'));
      await _push(tester, navigator, _chatPage('Room'));
      await _push(tester, navigator, _chatPage('Details'));

      final back = find.byType(UiNavigationBackButton);
      final context = tester.element(back);
      expect(
        UiNavigationBackButton.historyOf(context).map((item) => item.title),
        ['Room', 'Chats', 'Home'],
      );

      await _longPress(tester, back);
      expect(find.byType(UiMenuStack), findsOneWidget);
      await tester.tap(find.text('Chats').last);
      await tester.pumpAndSettle();

      expect(find.byType(UiMenuStack), findsNothing);
      expect(find.byType(UiChatHeader), findsNothing);
      expect(find.text('Chats'), findsWidgets);
      expect(observer.historyItems().map((item) => item.title), ['Home']);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      observer.dispose();
    },
  );

  testWidgets('an explicit empty history opts out of the menu', (tester) async {
    final observer = UiNavigatorHistoryObserver();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_Host(observer: observer, navigator: navigator));
    await tester.pumpAndSettle();
    await _push(tester, navigator, _chatPage('Room', history: const []));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiNavigationBackButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuStack), findsNothing);
    expect(find.byType(UiChatHeader), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    observer.dispose();
  });

  testWidgets('phone dual-pane detail publishes its chat header title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observer = UiNavigatorHistoryObserver();
    final navigator = GlobalKey<NavigatorState>();
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      UiNavigatorHistoryScope(
        observer: observer,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: UiDualPane<String>(
            controller: controller,
            primaryBuilder: (_, _, select) => Column(
              children: [
                Expanded(child: _barPage('Chats')),
                TextButton(
                  onPressed: () => select('Room'),
                  child: const Text('Open room'),
                ),
              ],
            ),
            detailBuilder: (_, selected, _) =>
                UiChatHeader(title: selected ?? 'None'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open room'));
    await tester.pumpAndSettle();
    expect(find.byType(UiChatHeader), findsOneWidget);
    await _push(tester, navigator, const SizedBox());

    expect(observer.historyItems().map((item) => item.title), [
      'Room',
      'Chats',
    ]);

    await tester.pumpWidget(const SizedBox());
    observer.dispose();
  });

  testWidgets('inline dual-pane detail never renames the page history entry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final observer = UiNavigatorHistoryObserver();
    final navigator = GlobalKey<NavigatorState>();
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      UiNavigatorHistoryScope(
        observer: observer,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: UiDualPane<String>(
            controller: controller,
            primaryBuilder: (_, _, _) => _barPage('Chats'),
            detailBuilder: (_, selected, _) => _barPage(selected ?? 'None'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.select('Room');
    await tester.pumpAndSettle();
    expect(find.text('Room'), findsWidgets);
    await _push(tester, navigator, const SizedBox());

    expect(observer.historyItems().map((item) => item.title), ['Chats']);

    await tester.pumpWidget(const SizedBox());
    observer.dispose();
  });
}
