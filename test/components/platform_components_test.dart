import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) => MaterialApp(
      theme: UiThemeData.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('UiSheetScope', () {
    testWidgets('open + programmatic dismiss resolves the future',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));

      final future = UiSheetScope.show<String>(
        ctx,
        builder: (_, controller) => UiSheet(
          header: const UiSheetHeader(title: 'Sheet'),
          child: UiButton(
            label: 'confirm',
            intent: UiIntent.primary,
            onPressed: () => controller.dismiss('yes'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      await tester.tap(find.text('confirm'));
      await tester.pumpAndSettle();
      expect(await future, 'yes');
    });

    testWidgets('barrier tap dismisses with null', (tester) async {
      await tester.pumpWidget(_host(const SizedBox()));
      final ctx = tester.element(find.byType(Scaffold));
      final future = UiSheetScope.show<String>(
        ctx,
        builder: (_, __) => const UiSheet(child: Text('content')),
      );
      await tester.pumpAndSettle();
      // Tap the top-left corner (outside the sheet) to hit the barrier.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await future, isNull);
    });
  });

  group('UiDropdownMenu', () {
    testWidgets('activating an item fires onPressed + closes menu',
        (tester) async {
      var hit = 0;
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Menu'),
            ),
            items: [
              UiMenuItem(label: 'One', onPressed: () => hit++),
              const UiMenuSeparator(),
              UiMenuItem(
                label: 'Disabled',
                enabled: false,
                onPressed: () => hit += 100,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(hit, 1);
      // Menu closed.
      expect(find.text('One'), findsNothing);
    });

    testWidgets('keyboard Enter activates the focused row', (tester) async {
      var hit = 0;
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Kbd'),
            ),
            items: [
              UiMenuItem(label: 'Alpha', onPressed: () => hit++),
              UiMenuItem(label: 'Beta', onPressed: () => hit += 10),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Kbd'));
      await tester.pumpAndSettle();
      // First row is auto-focused on open; Enter activates it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(hit, 1);
    });

    testWidgets('destructive item uses danger foreground color',
        (tester) async {
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('DangerMenu'),
            ),
            items: [
              UiMenuItem(label: 'Delete', destructive: true, onPressed: () {}),
            ],
          ),
        ),
      );

      await tester.tap(find.text('DangerMenu'));
      await tester.pumpAndSettle();

      final deleteText = tester
          .widgetList<Text>(find.text('Delete'))
          .firstWhere((t) => t.style?.color != null);
      expect(deleteText.style!.color, UiColorTokens.light.danger);
    });
  });

  group('UiBottomTabBar / Scaffold', () {
    testWidgets('renders items + switches selection', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat', badge: 3),
                UiBottomTabItem(label: 'Me'),
              ],
              pages: const [
                Center(child: Text('home-page')),
                Center(child: Text('chat-page')),
                Center(child: Text('me-page')),
              ],
              currentIndex: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );
      expect(find.text('home-page'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(index, 1);
    });

    testWidgets('selected dock pill can be dragged to another tab',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat'),
                UiBottomTabItem(label: 'Me'),
              ],
              pages: const [
                Center(child: Text('home-page')),
                Center(child: Text('chat-page')),
                Center(child: Text('me-page')),
              ],
              currentIndex: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, 2);
    });

    testWidgets('drag outside the dock cancels and does not change selection',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat'),
                UiBottomTabItem(label: 'Me'),
              ],
              pages: const [
                Center(child: Text('home-page')),
                Center(child: Text('chat-page')),
                Center(child: Text('me-page')),
              ],
              currentIndex: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, -160));
      await gesture.moveBy(const Offset(420, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, 0);
    });

    testWidgets('preserveState keeps off-screen pages mounted', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'A'),
                UiBottomTabItem(label: 'B'),
              ],
              pages: const [
                Text('page-a', key: Key('pa')),
                Text('page-b', key: Key('pb')),
              ],
              currentIndex: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );
      // Both pages are mounted — IndexedStack keeps them.
      expect(find.byKey(const Key('pa'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('pb'), skipOffstage: false), findsOneWidget);
    });

    testWidgets('preserveState only lays out the selected page',
        (tester) async {
      var index = 0;
      var firstPageLayouts = 0;
      var secondPageLayouts = 0;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'First'),
                UiBottomTabItem(label: 'Second'),
              ],
              pages: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    firstPageLayouts += 1;
                    return const SizedBox.expand(
                      child: Text('first-page', key: Key('first-layout-page')),
                    );
                  },
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    secondPageLayouts += 1;
                    return const SizedBox.expand(child: Text('second-page'));
                  },
                ),
              ],
              currentIndex: index,
              onChanged: (value) => setState(() => index = value),
            ),
          ),
        ),
      );

      expect(firstPageLayouts, greaterThan(0));
      expect(secondPageLayouts, 0);

      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();

      expect(secondPageLayouts, greaterThan(0));
      final firstPageLayoutsAfterSwitch = firstPageLayouts;

      tester.view.physicalSize = const Size(760, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pump();

      expect(firstPageLayouts, firstPageLayoutsAfterSwitch);
      expect(
        find.byKey(const Key('first-layout-page'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('floating scaffold body extends underneath the dock',
        (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            height: 700,
            child: UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat'),
              ],
              pages: const [
                ColoredBox(
                  key: Key('page-body'),
                  color: Color(0xFF00FF00),
                  child: SizedBox.expand(),
                ),
                Center(child: Text('chat-page')),
              ],
              currentIndex: 0,
              onChanged: _noopTabChange,
            ),
          ),
        ),
      );

      final bodyRect = tester.getRect(find.byKey(const Key('page-body')));
      final dockRect =
          tester.getRect(find.byKey(const Key('ui_bottom_tab_dock')));
      expect(bodyRect.height, 700);
      expect(bodyRect.bottom, greaterThan(dockRect.top));
    });

    testWidgets('floating dock sinks toward home-indicator edge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: const SizedBox(
              width: 390,
              height: 844,
              child: UiBottomTabBar(
                items: [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                ],
                currentIndex: 0,
                onChanged: _noopTabChange,
              ),
            ),
          ),
        ),
      );

      final dockRect =
          tester.getRect(find.byKey(const Key('ui_bottom_tab_dock')));
      expect(dockRect.bottom, closeTo(828, 0.1));
    });

    testWidgets('scaffold automatically overflows bottom tabs into More drawer',
        (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (ctx, setState) => UiBottomTabScaffold(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Schedule'),
                UiBottomTabItem(label: 'Chat'),
                UiBottomTabItem(label: 'Library'),
                UiBottomTabItem(label: 'Account'),
              ],
              pages: const [
                Center(child: Text('home-page')),
                Center(child: Text('schedule-page')),
                Center(child: Text('chat-page')),
                Center(child: Text('library-page')),
                Center(child: Text('account-page')),
              ],
              currentIndex: index,
              onChanged: (i) => setState(() => index = i),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('Library'), findsNothing);
      expect(find.byKey(const Key('ui_bottom_tab_dock')), findsOneWidget);
      expect(
        find.byKey(const Key('ui_bottom_tab_detached_dock')),
        findsNothing,
      );

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      final openBar = tester.widget<UiBottomTabBar>(
        find.byType(UiBottomTabBar),
      );
      expect(openBar.currentIndex, 3);
      final openWidths = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(Key('ui_bottom_tab_slot_$i'))).width,
      ];
      for (final width in openWidths.skip(1)) {
        expect(width, closeTo(openWidths.first, 0.01));
      }

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      expect(index, 4);
      expect(find.text('account-page'), findsOneWidget);
      final overflowSelectedBar = tester.widget<UiBottomTabBar>(
        find.byType(UiBottomTabBar),
      );
      expect(overflowSelectedBar.currentIndex, 3);
    });

    testWidgets('scaffold can convert bottom tabs to a rail on wide screens',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          UiBottomTabScaffold(
            items: const [
              UiBottomTabItem(label: 'Home'),
              UiBottomTabItem(label: 'Chat'),
            ],
            pages: const [
              Center(child: Text('home-page')),
              Center(child: Text('chat-page')),
            ],
            currentIndex: 0,
            onChanged: (_) {},
            convertToRailOnWideScreens: true,
            railBreakpoint: 600,
            railBuilder: (context, config) => SizedBox(
              key: const Key('rail'),
              width: 96,
              child: Text('rail-${config.items.length}'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rail')), findsOneWidget);
      expect(find.text('rail-2'), findsOneWidget);
      expect(find.byKey(const Key('ui_bottom_tab_dock')), findsNothing);
    });

    testWidgets('automatic bottom overflow is bypassed in rail mode',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          UiBottomTabScaffold(
            items: const [
              UiBottomTabItem(label: 'Home'),
              UiBottomTabItem(label: 'Schedule'),
              UiBottomTabItem(label: 'Chat'),
              UiBottomTabItem(label: 'Library'),
              UiBottomTabItem(label: 'Account'),
            ],
            pages: const [
              Center(child: Text('home-page')),
              Center(child: Text('schedule-page')),
              Center(child: Text('chat-page')),
              Center(child: Text('library-page')),
              Center(child: Text('account-page')),
            ],
            currentIndex: 0,
            onChanged: (_) {},
            convertToRailOnWideScreens: true,
            railBreakpoint: 600,
            railBuilder: (context, config) => SizedBox(
              key: const Key('rail'),
              width: 96,
              child: Text('rail-${config.items.length}'),
            ),
          ),
        ),
      );

      expect(find.text('rail-5'), findsOneWidget);
      expect(find.text('More'), findsNothing);
    });

    testWidgets('bottom tab slots mirror in RTL', (tester) async {
      tester.view.physicalSize = const Size(420, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: UiBottomTabBar(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat'),
                UiBottomTabItem(label: 'Me'),
              ],
              currentIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final firstLeft = tester.getTopLeft(
        find.byKey(const Key('ui_bottom_tab_slot_0')),
      );
      final secondLeft = tester.getTopLeft(
        find.byKey(const Key('ui_bottom_tab_slot_1')),
      );
      expect(firstLeft.dx, greaterThan(secondLeft.dx));
    });

    testWidgets('adaptive layout switches to centered floating dock on tablet',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          UiBottomTabBar(
            items: const [
              UiBottomTabItem(label: 'Home'),
              UiBottomTabItem(label: 'Chat'),
              UiBottomTabItem(label: 'Me'),
            ],
            currentIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('ui_bottom_tab_dock')), findsOneWidget);
      final dockRect =
          tester.getRect(find.byKey(const Key('ui_bottom_tab_dock')));
      expect(dockRect.width, lessThan(1024));
    });

    testWidgets('floating dock fills compact width but hugs content when wide',
        (tester) async {
      Widget hostForWidth(double width) {
        return _host(
          SizedBox(
            width: width,
            child: UiBottomTabBar(
              items: const [
                UiBottomTabItem(label: 'Home'),
                UiBottomTabItem(label: 'Chat'),
                UiBottomTabItem(label: 'Me'),
                UiBottomTabItem(label: 'More'),
              ],
              currentIndex: 0,
              onChanged: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidget(hostForWidth(390));
      var dockRect =
          tester.getRect(find.byKey(const Key('ui_bottom_tab_dock')));
      expect(dockRect.width, 358);

      await tester.pumpWidget(hostForWidth(900));
      await tester.pumpAndSettle();
      dockRect = tester.getRect(find.byKey(const Key('ui_bottom_tab_dock')));
      expect(dockRect.width, 300);
    });

    testWidgets('selected tab slot expands while inactive slots stay compact',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 390,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Overview'),
                  UiBottomTabItem(label: 'Notes'),
                  UiBottomTabItem(label: 'Calendar'),
                  UiBottomTabItem(label: 'Tasks'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      List<double> slotWidths() => [
            for (var i = 0; i < 4; i++)
              tester.getSize(find.byKey(Key('ui_bottom_tab_slot_$i'))).width,
          ];

      var widths = slotWidths();
      expect(widths, hasLength(4));
      expect(widths[0], greaterThan(widths[1]));
      expect(widths[0], greaterThan(widths[2]));

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      widths = slotWidths();
      expect(widths[2], greaterThan(widths[0]));
      expect(widths[2], greaterThan(widths[1]));
    });

    testWidgets('selected slot obeys max cap and inactive slots obey min floor',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 900,
            child: UiBottomTabBar(
              items: const [
                UiBottomTabItem(label: 'A'),
                UiBottomTabItem(label: 'B'),
                UiBottomTabItem(label: 'C'),
              ],
              currentIndex: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widths = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byKey(Key('ui_bottom_tab_slot_$i'))).width,
      ];
      expect(widths[1], greaterThan(widths[0]));
      expect(widths[1], greaterThan(widths[2]));
      expect(widths[1], lessThanOrEqualTo(180.0 + 0.5));
    });

    testWidgets('inactive dock tabs keep their natural width when room allows',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 480,
            child: UiBottomTabBar(
              items: const [
                UiBottomTabItem(label: 'Overview'),
                UiBottomTabItem(label: 'Assignments'),
                UiBottomTabItem(label: 'Notifications'),
              ],
              currentIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widths = [
        for (var i = 0; i < 3; i++)
          tester.getSize(find.byKey(Key('ui_bottom_tab_slot_$i'))).width,
      ];
      expect(widths[1], greaterThan(72.0));
      expect(widths[2], greaterThan(72.0));
      expect(widths[1], greaterThan(widths[0]));
      expect(widths[2], greaterThan(widths[1]));
    });

    testWidgets('very narrow width stays non-overflowing and tappable',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 220,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Chat'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(index, 1);
    });

    testWidgets(
        'drag leaving the pill and re-entering tab bar away from pill does '
        'not change selection', (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      // Horizontal escape — pause.
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      // Return partway (still clear of frozen pill) plus vertical drift.
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, 0);
    });

    testWidgets('in-pill drag that tracks the pill still changes selection',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, greaterThan(0));
    });

    testWidgets('horizontal escape freezes dock pill and confirms nearest',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double indicatorLeft() => (tester
                  .widget<AnimatedPositioned>(
                      find.byType(AnimatedPositioned).first)
                  .left ??
              0)
          .toDouble();

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      final tracked = indicatorLeft();
      expect(tracked, greaterThan(0));

      await gesture.moveBy(const Offset(600, 0));
      await tester.pump();
      final frozen = indicatorLeft();
      expect(frozen, closeTo(tracked, 0.5));

      await gesture.moveBy(const Offset(140, 0));
      await tester.pump();
      expect(indicatorLeft(), closeTo(frozen, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(index, greaterThan(0));
    });

    testWidgets('dock horizontal escape then catch-up resumes drag',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(500, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-530, 0));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, greaterThan(0));
    });

    testWidgets('dock drag ignores vertical drift and keeps tracking',
        (tester) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setState) => UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home'),
                  UiBottomTabItem(label: 'Chat'),
                  UiBottomTabItem(label: 'Me'),
                ],
                currentIndex: index,
                onChanged: (i) => setState(() => index = i),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.text('Home'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -140));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(index, greaterThan(0));
    });
  });

  group('UiSidebar / UiResponsiveNavigationScaffold', () {
    testWidgets('renders expanded items + responds to active state',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 400,
            child: UiSidebar(
              items: [
                UiSidebarGroup(
                  label: 'Main',
                  items: [
                    UiSidebarItem(
                      label: 'Inbox',
                      onPressed: () => taps++,
                      active: true,
                    ),
                    UiSidebarItem(
                      label: 'Archive',
                      onPressed: () => taps++,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      await tester.tap(find.text('Archive'));
      expect(taps, 1);
    });

    test('resolveFormFactor picks phone / tablet / desktop from width', () {
      const s = UiResponsiveNavigationScaffold(body: SizedBox.shrink());
      expect(s.resolveFormFactor(400), UiNavigationFormFactor.phone);
      expect(s.resolveFormFactor(720), UiNavigationFormFactor.tablet);
      expect(s.resolveFormFactor(1200), UiNavigationFormFactor.desktop);
    });

    testWidgets('responsive scaffold shows phone chrome under the breakpoint',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const UiResponsiveNavigationScaffold(
            sidebar: SizedBox(width: 80, child: Text('sidebar')),
            bottomBar: SizedBox(height: 56, child: Text('bar')),
            body: SizedBox.expand(),
          ),
        ),
      );
      expect(find.text('bar'), findsOneWidget);
      expect(find.text('sidebar'), findsNothing);
    });

    testWidgets('responsive scaffold shows desktop chrome above breakpoint',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const UiResponsiveNavigationScaffold(
            sidebar: SizedBox(width: 80, child: Text('sidebar')),
            secondary: SizedBox(width: 80, child: Text('secondary')),
            bottomBar: SizedBox(height: 56, child: Text('bar')),
            body: SizedBox.expand(),
          ),
        ),
      );
      expect(find.text('sidebar'), findsOneWidget);
      expect(find.text('secondary'), findsOneWidget);
      expect(find.text('bar'), findsNothing);
    });

    testWidgets('responsive scaffold overlays side chrome without a gutter',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const UiResponsiveNavigationScaffold(
            sidebar: SizedBox(
              key: Key('sidebar'),
              width: 80,
              child: Text('sidebar'),
            ),
            body: SizedBox.expand(key: Key('body')),
          ),
        ),
      );

      final sidebarRight = tester.getTopRight(find.byKey(const Key('sidebar')));
      final bodyLeft = tester.getTopLeft(find.byKey(const Key('body')));
      expect(bodyLeft.dx, sidebarRight.dx);
    });

    testWidgets('responsive scaffold mirrors side chrome in RTL',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: UiResponsiveNavigationScaffold(
              sidebar: SizedBox(
                key: Key('sidebar'),
                width: 80,
                child: Text('sidebar'),
              ),
              body: SizedBox.expand(key: Key('body')),
            ),
          ),
        ),
      );

      final sidebarLeft = tester.getTopLeft(find.byKey(const Key('sidebar')));
      final bodyRight = tester.getTopRight(find.byKey(const Key('body')));
      expect(sidebarLeft.dx, bodyRight.dx);
    });

    testWidgets('responsive scaffold can show tablet secondary + bottom bar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          const UiResponsiveNavigationScaffold(
            sidebar: SizedBox(width: 80, child: Text('sidebar')),
            secondary: SizedBox(width: 80, child: Text('secondary-desktop')),
            tabletSecondary:
                SizedBox(width: 80, child: Text('secondary-tablet')),
            bottomBar: SizedBox(height: 56, child: Text('tablet-bar')),
            showBottomBarOnTablet: true,
            showSecondaryOnTablet: true,
            body: SizedBox.expand(),
          ),
        ),
      );

      expect(find.text('sidebar'), findsOneWidget);
      expect(find.text('tablet-bar'), findsOneWidget);
      expect(find.text('secondary-tablet'), findsOneWidget);
      expect(find.text('secondary-desktop'), findsNothing);
    });
  });

  group('UiDatePicker / UiTimePicker', () {
    testWidgets('date picker emits tapped day', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 320,
              child: UiDatePicker(
                value: DateTime(2024, 3, 15),
                onChanged: (d) => picked = d,
              ),
            ),
          ),
        ),
      );
      // A day in the visible month (March 2024).
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2024, 3, 20));
    });

    testWidgets('date picker skips taps on disabled days', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 320,
              child: UiDatePicker(
                value: DateTime(2024, 3, 15),
                disabled: (d) => d.day == 20,
                onChanged: (d) => picked = d,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });

    testWidgets('date picker respects min constraint', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 320,
              child: UiDatePicker(
                value: DateTime(2024, 3, 15),
                min: DateTime(2024, 3, 10),
                onChanged: (d) => picked = d,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(picked, isNull, reason: 'Days before min should reject taps.');
    });

    test('UiTimeValue formats correctly in 12/24 hour', () {
      expect(const UiTimeValue(hour: 0, minute: 5).formatted12(), '12:05 AM');
      expect(const UiTimeValue(hour: 13, minute: 30).formatted24(), '13:30');
      expect(const UiTimeValue(hour: 13, minute: 30).formatted12(), '1:30 PM');
    });
  });
}

void _noopTabChange(int index) {}
