import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

const labels = [
  'Courses',
  'Tasks',
  'Calendar',
  'Grades',
  'Inbox',
  'Library',
  'Home',
  'People',
  'Profile',
];
final items = [
  for (final label in labels)
    UiBottomTabItem(label: label, icon: const Icon(Icons.circle_outlined)),
];
final next = find.bySemanticsLabel('Next destinations');
final previous = find.bySemanticsLabel('Previous destinations');
Finder branchSurface(String key) => find
    .descendant(
      of: find.byKey(Key(key), skipOffstage: false),
      matching: find.byType(UiFluidSurface, skipOffstage: false),
      skipOffstage: false,
    )
    .first;
final accessory = branchSurface('ui_paged_search_split');
final dock = find.byKey(const Key('ui_bottom_tab_dock'));

Widget host(
  Widget child, {
  bool rtl = false,
  bool reduced = false,
  double scale = 1,
  double keyboard = 0,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 800),
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: child,
    ),
  ),
);

Widget bar({
  int count = 9,
  int index = 0,
  ValueChanged<int>? changed,
  UiBottomTabAccessory? tool,
}) => Align(
  alignment: Alignment.bottomCenter,
  child: UiPagedBottomTabBar(
    items: items.take(count).toList(),
    currentIndex: index,
    onChanged: changed ?? (_) {},
    accessory: tool,
  ),
);

Future<void> viewport(WidgetTester tester, [double width = 390]) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('four-item end sets retain ordered destinations and shadows', (
    tester,
  ) async {
    await viewport(tester);
    for (final rtl in [false, true]) {
      final visits = <int>[];
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.bottomCenter,
            child: UiPagedBottomTabBar(
              items: items,
              currentIndex: 0,
              maxVisibleItems: 4,
              onChanged: visits.add,
              accessory: const UiBottomTabAccessory(child: Icon(Icons.search)),
            ),
          ),
          rtl: rtl,
        ),
      );
      await tester.pumpAndSettle();
      for (final label in labels.take(4)) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Inbox'), findsNothing);
      expect(
        tester
            .widget<UiFluidSurface>(branchSurface('ui_paged_next_split'))
            .shadows,
        isNotEmpty,
      );
      expect(tester.widget<UiFluidSurface>(accessory).shadows, isNotEmpty);
      await tester.tap(next);
      await tester.pumpAndSettle();
      for (final label in labels.skip(4).take(3)) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester
            .widget<UiFluidSurface>(branchSurface('ui_paged_previous_split'))
            .shadows,
        isNotEmpty,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(visits, isEmpty);
      await tester.tap(find.text('Profile'));
      expect(visits, [8]);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('search field stays full size throughout close and reversal', (
    tester,
  ) async {
    await viewport(tester, 320);
    for (final rtl in [false, true]) {
      bool expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return bar(
                tool: UiBottomTabAccessory(
                  expanded: expanded,
                  leadingItem: items.first,
                  collapsedWidth: 48,
                  height: 48,
                  child: expanded
                      ? Row(
                          children: [
                            const Expanded(
                              child: UiInput(
                                variant: UiInputVariant.embedded,
                                hint: 'Search courses',
                              ),
                            ),
                            UiIconButton(
                              icon: const Icon(Icons.close),
                              semanticsLabel: 'Close search',
                              size: UiSize.lg,
                              onPressed: () => update(() => expanded = false),
                            ),
                          ],
                        )
                      : const Icon(Icons.search),
                ),
              );
            },
          ),
          rtl: rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(dock).top - tester.getRect(accessory).bottom,
        closeTo(8, .1),
      );
      update(() => expanded = true);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Close search'));
      await tester.pump();
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'closing frame $i, rtl=$rtl',
        );
      }
      expect(tester.getSize(accessory).width, closeTo(48, .1));
      update(() => expanded = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      update(() => expanded = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      update(() => expanded = true);
      await tester.pumpAndSettle();
      expect(tester.getSize(accessory).width, closeTo(288, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('browses three sets without selecting or visiting a page', (
    tester,
  ) async {
    await viewport(tester);
    final visits = <int>[];
    await tester.pumpWidget(host(bar(changed: visits.add)));
    expect(previous, findsNothing);
    expect(next, findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(find.text('Grades'), findsOneWidget);
    expect(find.text('Courses'), findsNothing);
    expect(visits, isEmpty);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(next, findsNothing);
    expect(find.text('Profile'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    expect(visits, [8]);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(previous, findsNothing);
    expect(find.text('Courses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows emerge geometrically and the dock keeps its identity', (
    tester,
  ) async {
    await viewport(tester);
    await tester.pumpWidget(host(bar()));
    final element = tester.element(dock);
    final width = tester.getSize(dock).width;
    final backSurface = branchSurface('ui_paged_previous_split');
    expect(
      tester.getRect(backSurface).center.dx,
      greaterThanOrEqualTo(tester.getRect(dock).left),
    );
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final split = tester.widget<UiFluidSplit>(
      find.byKey(const Key('ui_paged_previous_split')),
    );
    expect(split.frame!.geometryProgress, greaterThan(0));
    expect(split.frame!.geometryProgress, lessThan(1));
    expect(
      find.descendant(
        of: find.byKey(const Key('ui_paged_previous_split')),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(previous, findsNothing); // Not focusable/tappable while emerging.
    expect(tester.getSize(dock).width, lessThan(width));
    expect(identical(tester.element(dock), element), isTrue);
    await tester.pumpAndSettle();
    expect(tester.getSize(backSurface).width, 48);
    expect(previous, findsOneWidget);
  });

  testWidgets('indicator is absent at rest, resets its timer, and disappears', (
    tester,
  ) async {
    await viewport(tester);
    await tester.pumpWidget(host(bar()));
    double opacity() => tester
        .widget<Opacity>(find.byKey(const Key('ui_paged_indicator')))
        .opacity;
    expect(opacity(), 0);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });

  testWidgets(
    'one set has no arrows or visible indicator, last set can be short',
    (tester) async {
      await viewport(tester);
      await tester.pumpWidget(host(bar(count: 3)));
      expect(previous, findsNothing);
      expect(next, findsNothing);
      await tester.pumpWidget(host(bar(count: 8, index: 7)));
      await tester.pumpAndSettle();
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(next, findsNothing);
      expect(previous, findsOneWidget);
    },
  );

  testWidgets(
    'external selection reveals its set; resizing and shrinking items stay valid',
    (tester) async {
      await viewport(tester);
      await tester.pumpWidget(host(bar()));
      await tester.pumpWidget(host(bar(index: 7)));
      await tester.pumpAndSettle();
      expect(find.text('People'), findsOneWidget);
      await tester.pumpWidget(host(bar(count: 4, index: 0)));
      await tester.pumpAndSettle();
      expect(find.text('Courses'), findsOneWidget);
      tester.view.physicalSize = const Size(240, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final rtl in [false, true]) {
    testWidgets(
      '320px large text has three targets and mirrored arrows: RTL=$rtl',
      (tester) async {
        await viewport(tester, 320);
        await tester.pumpWidget(host(bar(index: 4), rtl: rtl, scale: 2));
        final a = tester.getCenter(previous).dx;
        final b = tester.getCenter(next).dx;
        expect(rtl ? a > b : a < b, isTrue);
        for (var i = 0; i < 3; i++) {
          expect(
            tester.getSize(find.byKey(Key('ui_bottom_tab_slot_$i'))).width,
            greaterThanOrEqualTo(44),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reduced motion settles immediately and arrow focus is rescued', (
    tester,
  ) async {
    await viewport(tester);
    await tester.pumpWidget(host(bar(count: 6), reduced: true));
    final nextButton = tester.widget<UiIconButton>(
      find.ancestor(of: next, matching: find.byType(UiIconButton)).first,
    );
    nextButton.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(previous, findsOneWidget);
    expect(next, findsNothing);
    expect(find.text('Grades'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, isNot(nextButton.focusNode));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accessory releases from next arrow, remains during browsing, and retracts into dock',
    (tester) async {
      await viewport(tester);
      int selected = 2;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return bar(
                count: 6,
                index: selected,
                tool: selected == 2
                    ? null
                    : UiBottomTabAccessory(
                        leadingItem: items[selected],
                        child: const Text('Search'),
                      ),
              );
            },
          ),
        ),
      );
      final source = tester.getRect(branchSurface('ui_paged_next_split'));
      update(() => selected = 0);
      await tester.pump();
      expect(tester.getRect(accessory).center.dx, closeTo(source.center.dx, 1));
      expect(tester.getRect(accessory).center.dy, closeTo(source.center.dy, 1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getRect(accessory).center.dy, lessThan(source.center.dy));
      await tester.pumpAndSettle();
      final settled = tester.getRect(accessory);
      final element = tester.element(accessory);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.getRect(accessory), settled);
      expect(identical(tester.element(accessory), element), isTrue);
      update(() => selected = 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.getRect(accessory).center.dy,
        greaterThan(settled.center.dy),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ui_paged_search_split')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accessory on final set starts at dock edge, expands and reverses safely',
    (tester) async {
      await viewport(tester);
      bool show = false;
      bool expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return bar(
                count: 6,
                index: 4,
                tool: show
                    ? UiBottomTabAccessory(
                        expanded: expanded,
                        leadingItem: items[4],
                        child: expanded
                            ? const Text('Search messages')
                            : const Icon(Icons.search),
                      )
                    : null,
              );
            },
          ),
        ),
      );
      final source = tester.getRect(dock);
      update(() => show = true);
      await tester.pump();
      expect(
        tester.getRect(accessory).center.dx,
        closeTo(source.right - 24, 1),
      );
      expect(tester.getRect(accessory).center.dy, closeTo(source.center.dy, 1));
      await tester.pump(const Duration(milliseconds: 50));
      final intermediate = tester.getRect(accessory);
      update(() => show = false);
      await tester.pump();
      expect(
        tester.getRect(accessory).center.dy,
        closeTo(intermediate.center.dy, 1),
      );
      update(() => show = true);
      await tester.pumpAndSettle();
      final compactWidth = tester.getSize(accessory).width;
      update(() => expanded = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(accessory).width, greaterThan(compactWidth));
      await tester.pumpAndSettle();
      expect(tester.getSize(accessory).width, 358);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scaffold preserves page state and integrates expanded keyboard hit bounds',
    (tester) async {
      await viewport(tester);
      int selected = 0;
      int taps = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, update) => UiBottomTabScaffold(
              items: items.take(6).toList(),
              currentIndex: selected,
              onChanged: (value) => update(() => selected = value),
              overflowBehavior: UiBottomTabOverflowBehavior.paged,
              bottomAccessory: UiBottomTabAccessory(
                expanded: true,
                leadingItem: items[selected],
                child: UiButton(
                  label: 'Search action',
                  onPressed: () => taps++,
                ),
              ),
              pages: [
                for (var i = 0; i < 6; i++)
                  Center(child: Text('Page content $i')),
              ],
            ),
          ),
          keyboard: 280,
        ),
      );
      expect(find.text('More'), findsNothing);
      expect(tester.getRect(accessory).bottom, lessThan(520));
      await tester.tap(find.text('Search action'));
      expect(taps, 1);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(find.text('Page content 0'), findsOneWidget);
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(find.text('Page content 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
