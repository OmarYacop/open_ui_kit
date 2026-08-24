import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UiNavigationBackButton default (chevron-only)', () {
    testWidgets('paints no label text by default', (tester) async {
      await tester.pumpWidget(
        _host(UiNavigationBackButton(label: 'Library', onPressed: () {})),
      );
      expect(find.text('Library'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
      // The label still drives the accessibility announcement even when
      // it isn't painted.
      expect(find.bySemanticsLabel('Library'), findsOneWidget);
    });

    testWidgets('showLabel: true restores the chevron-plus-title look', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          UiNavigationBackButton(
            label: 'Library',
            onPressed: () {},
            showLabel: true,
          ),
        ),
      );
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('back chevron mirrors with text direction', (tester) async {
      await tester.pumpWidget(
        _host(UiNavigationBackButton(label: 'Library', onPressed: () {})),
      );
      var icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(
        icon.icon,
        UiDirectionalIcons.chevronBack(
          tester.element(find.byType(Icon).first),
        ),
      );

      await tester.pumpWidget(
        _host(
          UiNavigationBackButton(label: 'Library', onPressed: () {}),
          dir: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(
        icon.icon,
        UiDirectionalIcons.chevronBack(
          tester.element(find.byType(Icon).first),
        ),
      );
    });

    testWidgets('tapping activates onPressed even with no painted label', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          UiNavigationBackButton(
            label: 'Library',
            onPressed: () => tapped++,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Library'));
      expect(tapped, 1);
    });
  });

  group('UiNavigationBackButton history flyout', () {
    // The history menu is positioned via resolveUiAnchoredOverlayGeometry
    // (viewport-safe, shared with UiDropdownMenu/UiSelect) rather than a
    // fixed CompositedTransformFollower offset.
    Future<Rect> pumpAndOpen(
      WidgetTester tester, {
      required TextDirection dir,
    }) async {
      const history = [
        UiNavigationBackHistoryItem(title: 'Root'),
        UiNavigationBackHistoryItem(title: 'Shelves'),
      ];
      await tester.pumpWidget(
        _host(
          SafeArea(
            child: Center(
              child: UiNavigationBackButton(
                label: 'Library',
                onPressed: () {},
                history: history,
                onHistorySelected: (_) {},
              ),
            ),
          ),
          dir: dir,
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.bySemanticsLabel('Library'));
      await tester.pumpAndSettle();
      return tester.getRect(find.text('Root'));
    }

    testWidgets('flyout starts aligned with the trigger left edge in LTR',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.ltr);
      final trigger = tester.getRect(find.bySemanticsLabel('Library'));
      expect(
        menuItem.left,
        lessThanOrEqualTo(trigger.right),
        reason: 'LTR flyout should start no further right than the trigger',
      );
    });

    testWidgets('flyout starts aligned with the trigger right edge in RTL',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.rtl);
      final trigger = tester.getRect(find.bySemanticsLabel('Library'));
      expect(
        menuItem.right,
        greaterThanOrEqualTo(trigger.left),
        reason: 'RTL flyout should start no further left than the trigger',
      );
    });

    testWidgets('entrance fades and scales in rather than snapping open', (
      tester,
    ) async {
      const history = [UiNavigationBackHistoryItem(title: 'Root')];
      await tester.pumpWidget(
        _host(
          Center(
            child: UiNavigationBackButton(
              label: 'Library',
              onPressed: () {},
              history: history,
              onHistorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.longPress(find.bySemanticsLabel('Library'));
      await tester.pump();

      final transitionFinder = find.ancestor(
        of: find.text('Root'),
        matching: find.byType(FadeTransition),
      );
      final transition = tester.widget<FadeTransition>(transitionFinder);
      expect(transition.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();
      final settled = tester.widget<FadeTransition>(transitionFinder);
      expect(settled.opacity.value, 1.0);
    });

    testWidgets('a tall history list scrolls instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final history = [
        for (var i = 0; i < 30; i++)
          UiNavigationBackHistoryItem(title: 'Screen $i'),
      ];
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topCenter,
            child: UiNavigationBackButton(
              label: 'Library',
              onPressed: () {},
              history: history,
              onHistorySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.longPress(find.bySemanticsLabel('Library'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // All 30 rows can't fit inside a 400pt-tall viewport at once — the
      // overlay must have bounded and scrolled the content, not overflowed
      // (which would throw a RenderFlex overflow error, caught above).
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollViewHeight =
          tester.getSize(find.byType(SingleChildScrollView)).height;
      final contentHeight = tester
          .getSize(
            find.byKey(const Key('ui_navigation_back_history_content')),
          )
          .height;
      expect(scrollViewHeight, lessThan(contentHeight));
    });

    testWidgets('sliver nav caps long back labels before the title', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Current title',
                  back: UiNavigationBackConfig(
                    label: 'Extremely long parent page title',
                    onPressed: () {},
                    showLabel: true,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current title'), findsOneWidget);
      final labelRect = tester.getRect(
        find.text('Extremely long parent page title'),
      );
      final titleRect = tester.getRect(find.text('Current title'));
      final screenCenter = tester.getSize(find.byType(MaterialApp)).width / 2;

      expect(labelRect.width, lessThanOrEqualTo(112));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
    });

    testWidgets('sliver nav lets back labels use tablet width when available',
        (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Current title',
                  back: UiNavigationBackConfig(
                    label: 'Extremely long parent page title',
                    onPressed: () {},
                    showLabel: true,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelRect = tester.getRect(
        find.text('Extremely long parent page title'),
      );
      final titleRect = tester.getRect(find.text('Current title'));
      final screenCenter = tester.getSize(find.byType(MaterialApp)).width / 2;

      expect(labelRect.width, greaterThan(112));
      expect(labelRect.width, lessThanOrEqualTo(260));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
    });

    testWidgets(
        'a chevron-only back button still reserves only a compact width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: [
              UiSliverNavigationBar(
                spec: UiNavigationSpec(
                  title: 'Current title',
                  back: UiNavigationBackConfig(
                    label: 'Extremely long parent page title',
                    onPressed: () {},
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Extremely long parent page title'), findsNothing);
      final backRect = tester.getRect(
        find.bySemanticsLabel('Extremely long parent page title'),
      );
      final titleRect = tester.getRect(find.text('Current title'));
      final screenCenter = tester.getSize(find.byType(MaterialApp)).width / 2;

      expect(backRect.width, lessThanOrEqualTo(44));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
    });

    testWidgets('explicit pop targets still navigate to the selected item', (
      tester,
    ) async {
      Widget page(String title, {Widget? child}) => CustomScrollView(
            slivers: [
              UiSliverNavigationBar(spec: UiNavigationSpec(title: title)),
              SliverFillRemaining(child: child ?? Text(title)),
            ],
          );

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => page(
              'Home',
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => page(
                          'Details',
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CustomScrollView(
                                      slivers: [
                                        UiSliverNavigationBar(
                                          spec: UiNavigationSpec(
                                            title: 'Classes',
                                            back: UiNavigationBackConfig(
                                              label: 'Details',
                                              history: const [
                                                UiNavigationBackHistoryItem(
                                                  title: 'Details',
                                                  value:
                                                      UiNavigationBackPopTarget(
                                                    1,
                                                  ),
                                                ),
                                                UiNavigationBackHistoryItem(
                                                  title: 'Home',
                                                  value:
                                                      UiNavigationBackPopTarget(
                                                    2,
                                                  ),
                                                ),
                                              ],
                                              onPressed: () =>
                                                  Navigator.maybePop(context),
                                            ),
                                          ),
                                        ),
                                        const SliverFillRemaining(
                                          child: Text('Classes'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: const Text('open classes'),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open details'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open classes'));
      await tester.pumpAndSettle();

      await tester.longPress(find.bySemanticsLabel('Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Classes'), findsNothing);
    });
  });

  group('UiApp auto-populated navigator history', () {
    // The previous behavior required every screen to hand-build its own
    // `history:` list (see the explicit pop-target test above). Without
    // that, the flyout only ever showed the current page's own back
    // label — one entry, not the real stack. UiApp now installs a
    // UiNavigatorHistoryObserver automatically, and UiSliverNavigationBar
    // registers each page's title against it, so a plain
    // `Navigator.push` stack Just Works.
    testWidgets(
        'long-press back shows every prior screen in the stack, not just '
        'the immediate previous one', (tester) async {
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light,
          localizationsDelegates: const [
            DefaultWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                const UiSliverNavigationBar(
                  spec: UiNavigationSpec(title: 'Home'),
                ),
                SliverFillRemaining(
                  child: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => CustomScrollView(
                            slivers: [
                              UiSliverNavigationBar(
                                spec: UiNavigationSpec(
                                  title: 'Detail',
                                  back: UiNavigationBackConfig(
                                    onPressed: () =>
                                        Navigator.maybePop(context),
                                  ),
                                ),
                              ),
                              SliverFillRemaining(
                                child: Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (context) => CustomScrollView(
                                          slivers: [
                                            UiSliverNavigationBar(
                                              spec: UiNavigationSpec(
                                                title: 'Deep',
                                                back: UiNavigationBackConfig(
                                                  onPressed: () =>
                                                      Navigator.maybePop(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SliverFillRemaining(
                                              child: Text('Deep body'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    child: const Text('open deep'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      child: const Text('open detail'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('open detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open deep'));
      await tester.pumpAndSettle();

      await tester.longPress(find.bySemanticsLabel('Detail'));
      await tester.pumpAndSettle();

      // Both ancestors — not just the immediate previous screen — must
      // be offered.
      expect(find.text('Detail'), findsWidgets);
      expect(find.text('Home'), findsWidgets);
    });
  });

  group('history flyout inside UiPageScaffold', () {
    // UiPageScaffold wraps its body in UiLayeredOverlayHost, whose
    // per-layer Overlays are siblings of the page content in its own
    // Stack — not ancestors of it. _toggleMenu must not assume otherwise
    // (e.g. via InheritedTheme.capture(to: thatOverlay.context), which
    // throws "must be an ancestor" for a sibling).
    testWidgets('long-press opens the flyout without an ancestor assertion',
        (tester) async {
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light,
          localizationsDelegates: const [
            DefaultWidgetsLocalizations.delegate,
          ],
          home: UiPageScaffold(
            body: CustomScrollView(
              slivers: [
                UiSliverNavigationBar(
                  spec: UiNavigationSpec(
                    title: 'Detail',
                    back: UiNavigationBackConfig(
                      label: 'Library',
                      onPressed: () {},
                      history: const [
                        UiNavigationBackHistoryItem(title: 'Library'),
                      ],
                    ),
                  ),
                ),
                const SliverFillRemaining(child: Text('Body')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.bySemanticsLabel('Library'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Library'), findsWidgets);
    });
  });
}
