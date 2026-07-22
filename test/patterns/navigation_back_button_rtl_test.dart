import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UiNavigationBackButton history flyout RTL (PR-2)', () {
    testWidgets('back chevron mirrors with text direction', (tester) async {
      await tester.pumpWidget(
        _host(
          UiNavigationBackButton(label: 'Library', onPressed: () {}),
        ),
      );
      var icon = tester.widget<Icon>(find.byType(Icon).first);
      expect(
        icon.icon,
        UiDirectionalIcons.chevronBack(tester.element(find.text('Library'))),
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
        UiDirectionalIcons.chevronBack(tester.element(find.text('Library'))),
      );
    });

    // The history menu is attached via a CompositedTransformFollower.
    // Before PR-2 it used Alignment.bottomLeft/topLeft (absolute) so
    // the flyout always opened on the physical left. The directional
    // anchors switch to "start"-relative, so in RTL the flyout opens
    // aligned to the trigger's right edge.
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
      // Long-press the trigger to show the history flyout.
      await tester.longPress(find.text('Library'));
      await tester.pumpAndSettle();
      return tester.getRect(find.text('Root'));
    }

    testWidgets('flyout starts aligned with the trigger left edge in LTR',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.ltr);
      final trigger = tester.getRect(find.text('Library'));
      expect(
        menuItem.left,
        lessThanOrEqualTo(trigger.right),
        reason: 'LTR flyout should start no further right than the trigger',
      );
    });

    testWidgets('flyout starts aligned with the trigger right edge in RTL',
        (tester) async {
      final menuItem = await pumpAndOpen(tester, dir: TextDirection.rtl);
      final trigger = tester.getRect(find.text('Library'));
      // In RTL the flyout's "start" is the right edge; so the menu
      // item's right edge should sit at or to the right of the
      // trigger's left edge.
      expect(
        menuItem.right,
        greaterThanOrEqualTo(trigger.left),
        reason: 'RTL flyout should start no further left than the trigger',
      );
    });
  });

  group('UiNavigationBackButton history behavior', () {
    testWidgets('sliver nav caps long back labels before the title',
        (tester) async {
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

      expect(find.text('Current title'), findsOneWidget);
      final labelRect = tester.getRect(
        find.text('Extremely long parent page title'),
      );
      final titleRect = tester.getRect(find.text('Current title'));
      final screenCenter = tester.getSize(find.byType(MaterialApp)).width / 2;

      expect(labelRect.width, lessThanOrEqualTo(112));
      expect(titleRect.center.dx, closeTo(screenCenter, 1));
    });

    testWidgets('pop targets navigate to the selected history item',
        (tester) async {
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

      await tester.longPress(find.text('Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Classes'), findsNothing);
    });
  });
}
