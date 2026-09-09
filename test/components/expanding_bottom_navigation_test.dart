import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

final destinations = List.generate(
  8,
  (i) => UiBottomTabItem(
    id: 'page$i',
    label: 'Page $i',
    icon: const Icon(Icons.circle_outlined),
  ),
);
Finder page(int i) => find.byKey(ValueKey('ui_drawer_destination_page$i'));
final handle = find.byKey(const Key('ui_drawer_handle'));

Widget host(
  UiBottomTabDrawerController controller, {
  ValueChanged<int>? onChanged,
  double scale = 1,
  bool rtl = false,
  bool reduced = false,
  int selected = 0,
  double keyboard = 0,
  EdgeInsets safe = EdgeInsets.zero,
  UiBottomTabAccessory? accessory,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      viewInsets: EdgeInsets.only(bottom: keyboard),
      padding: safe,
      viewPadding: safe,
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: UiExpandingBottomTabBar(
        items: destinations,
        currentIndex: selected,
        onChanged: onChanged ?? (_) {},
        controller: controller,
        accessory: accessory,
      ),
    ),
  ),
);
Future<void> pumpDrawer(WidgetTester tester) async {
  // Edit mode deliberately keeps wiggling, so settle only finite transitions.
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('drawer closes in half the opening duration', (tester) async {
    final controller = UiBottomTabDrawerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    final surface = find.byKey(const Key('ui_expanding_dock_surface'));
    final compact = tester.getRect(surface);
    controller.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    final midway = tester.getRect(surface);
    await tester.pump(const Duration(milliseconds: 225));
    expect(tester.getRect(surface).height, greaterThan(midway.height));
    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    expect(tester.getRect(surface), compact);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      size: const Size(390, 844),
      safe: const EdgeInsets.only(top: 59, bottom: 34),
    ),
    (
      size: const Size(844, 390),
      safe: const EdgeInsets.fromLTRB(59, 0, 59, 21),
    ),
  ]) {
    testWidgets(
      'dock hugs the edge within rounded device corners ${scenario.size}',
      (tester) async {
        tester.view.reset();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.size;
        addTearDown(tester.view.reset);
        final controller = UiBottomTabDrawerController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(host(controller, safe: scenario.safe));
        final surface = find.byKey(const Key('ui_expanding_dock_surface'));
        void checkBounds() {
          final rect = tester.getRect(surface);
          expect(rect.left, greaterThanOrEqualTo(scenario.safe.left));
          expect(
            rect.right,
            lessThanOrEqualTo(scenario.size.width - scenario.safe.right),
          );
          expect(rect.bottom, lessThanOrEqualTo(scenario.size.height - 8));
          final geometry = tester.widget<UiFluidSurface>(surface).geometry;
          final device = RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(scenario.safe.bottom * 2),
          ).getOuterPath((Offset.zero & scenario.size).inflate(.1));
          final outline = RoundedSuperellipseBorder(
            borderRadius: geometry.borderRadius,
          ).getOuterPath(rect);
          for (final metric in outline.computeMetrics()) {
            for (var distance = 0.0; distance < metric.length; distance += 2) {
              expect(
                device.contains(metric.getTangentForOffset(distance)!.position),
                isTrue,
                reason: 'Dock outline must clear the rounded window envelope',
              );
            }
          }
        }

        checkBounds();
        controller.open();
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          checkBounds();
        }
        expect(
          scenario.size.height - tester.getRect(surface).bottom,
          closeTo(
            scenario.safe.bottom * .25 < 8 ? 8 : scenario.safe.bottom * .25,
            .01,
          ),
        );
        controller.close();
        await pumpDrawer(tester);
        checkBounds();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.iOS}),
    );
  }

  testWidgets(
    'scaffold defaults to four expanding slots with themed geometry',
    (tester) async {
      final c = UiBottomTabDrawerController();
      addTearDown(c.dispose);
      final nav = UiBottomNavigationTokens.defaults.copyWith(
        compactHeight: 88,
        iconSize: 28,
        iconTitleGap: 8,
      );
      expect(
        UiBottomNavigationTokens.lerp(
          nav,
          nav.copyWith(iconSize: 32),
          .5,
        ).iconSize,
        30,
      );
      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light.copyWith(bottomNavigation: nav),
          mode: UiThemeMode.light,
          home: UiBottomTabScaffold(
            items: destinations,
            pages: List.generate(8, (_) => const SizedBox.expand()),
            currentIndex: 0,
            onChanged: (_) {},
            drawerController: c,
          ),
        ),
      );
      await pumpDrawer(tester);
      final bar = tester.widget<UiExpandingBottomTabBar>(
        find.byType(UiExpandingBottomTabBar),
      );
      expect(bar.maxVisibleItems, 4);
      expect(find.byType(UiPagedBottomTabBar), findsNothing);
      expect(find.text('More'), findsNothing);
      final iconTheme = tester
          .widgetList<IconTheme>(
            find.descendant(of: page(0), matching: find.byType(IconTheme)),
          )
          .last;
      expect(iconTheme.data.size, 28);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first hold lifts one item and cancellation restores draft order',
    (tester) async {
      final c = UiBottomTabDrawerController()..open();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await pumpDrawer(tester);
      final first = tester.getTopLeft(page(1));
      final destination = tester.getCenter(page(3));
      final drag = await tester.startGesture(tester.getCenter(page(0)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.customizing, isTrue);
      expect(page(0), findsNothing); // Only the lifted preview remains.
      await drag.moveTo(destination);
      await pumpDrawer(tester);
      expect(tester.getTopLeft(page(1)).dx, lessThan(first.dx));
      expect(c.order, isEmpty); // No persistence while hovering.
      await drag.moveTo(const Offset(-100, -100));
      await drag.up();
      await pumpDrawer(tester);
      expect(c.order, isEmpty);
      expect(page(0), findsOneWidget);
      expect(tester.getTopLeft(page(1)).dx, first.dx);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard lifts only the accessory and preserves its hit target',
    (tester) async {
      final controller = UiBottomTabDrawerController();
      addTearDown(controller.dispose);
      var taps = 0;
      final accessory = UiBottomTabAccessory(
        height: 48,
        child: GestureDetector(
          key: const Key('keyboard_accessory'),
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const Icon(Icons.search),
        ),
      );
      await tester.pumpWidget(host(controller, accessory: accessory));
      await pumpDrawer(tester);
      final dockBefore = tester.getCenter(handle);
      final search = find.byKey(const Key('keyboard_accessory'));
      final searchBefore = tester.getCenter(search);
      await tester.pumpWidget(
        host(controller, accessory: accessory, keyboard: 300),
      );
      await pumpDrawer(tester);
      expect(tester.getCenter(handle), dockBefore);
      expect(tester.getCenter(search).dy, lessThan(searchBefore.dy));
      expect(
        tester.getBottomRight(search).dy,
        lessThanOrEqualTo(600 - 300 - 8),
      );
      await tester.tap(search);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('ordering filters removed IDs and retains new destinations', () {
    final controller = UiBottomTabDrawerController(order: ['b', 'gone', 'b']);
    expect(controller.resolveOrder(['a', 'b', 'c']), ['b', 'a', 'c']);
    controller.dispose();
  });
  testWidgets(
    'secondary visits temporarily substitute a compact slot without saving order',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = UiBottomTabDrawerController();
      addTearDown(c.dispose);
      final visits = <int>[];
      var selected = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            c,
            selected: selected,
            onChanged: (index) {
              visits.add(index);
              setState(() => selected = index);
            },
          ),
        ),
      );
      await pumpDrawer(tester);
      expect(page(0).hitTestable(), findsOneWidget);
      expect(page(3).hitTestable(), findsOneWidget);
      expect(page(4).hitTestable(), findsNothing);
      await tester.tap(handle);
      await pumpDrawer(tester);
      expect(c.expanded, isTrue);
      expect(visits, isEmpty);
      expect(page(7).hitTestable(), findsOneWidget);
      await tester.tap(page(7));
      await pumpDrawer(tester);
      expect(visits, [7]);
      expect(c.expanded, isFalse);
      expect(c.order, isEmpty);
      expect(page(7).hitTestable(), findsOneWidget);
      expect(page(3).hitTestable(), findsNothing);
      await tester.tap(page(0));
      await pumpDrawer(tester);
      expect(page(3).hitTestable(), findsOneWidget);
      expect(page(7).hitTestable(), findsNothing);
      expect(c.order, isEmpty);
      await tester.tap(handle);
      await pumpDrawer(tester);
      expect(tester.getTopLeft(page(3)).dy, tester.getTopLeft(page(0)).dy);
      expect(
        tester.getTopLeft(page(7)).dy,
        greaterThan(tester.getTopLeft(page(3)).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'deep linked secondary selection preserves a custom saved order',
    (tester) async {
      final saved = [
        'page2',
        'page0',
        'page4',
        'page1',
        'page3',
        'page5',
        'page6',
        'page7',
      ];
      final c = UiBottomTabDrawerController(order: saved);
      addTearDown(c.dispose);
      for (final selected in [7, 6, 2]) {
        await tester.pumpWidget(host(c, selected: selected));
        await pumpDrawer(tester);
        expect(c.order, saved);
        expect(page(selected).hitTestable(), findsOneWidget);
        expect(
          page(1).hitTestable(),
          selected == 2 ? findsOneWidget : findsNothing,
        );
      }
      c.open();
      await pumpDrawer(tester);
      expect(tester.getTopLeft(page(1)).dy, tester.getTopLeft(page(2)).dy);
      expect(c.order, saved);
    },
  );

  testWidgets(
    'customization reorders with accessible taps and never navigates',
    (tester) async {
      final c = UiBottomTabDrawerController()..open();
      addTearDown(c.dispose);
      final visits = <int>[];
      await tester.pumpWidget(host(c, onChanged: visits.add));
      await pumpDrawer(tester);
      expect(find.text('Customize'), findsNothing);
      final before = tester.getTopLeft(page(0));
      await tester.longPress(page(0));
      await pumpDrawer(tester);
      final check = find.byKey(const Key('ui_drawer_finish_customizing'));
      expect(
        tester.getCenter(check).dx,
        greaterThan(tester.getCenter(page(7)).dx),
      );
      expect(
        tester.getCenter(check).dy,
        greaterThan(tester.getBottomRight(page(7)).dy),
      );
      expect(
        find.byWidgetPredicate((widget) => widget is UiDropRegion),
        findsNothing,
      );
      final transforms = find.descendant(
        of: page(0),
        matching: find.byType(Transform),
      );
      final rotation = tester
          .widget<Transform>(transforms.last)
          .transform
          .clone();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Transform>(transforms.last).transform,
        isNot(rotation),
      );
      expect(tester.getTopLeft(page(0)).dx, before.dx);
      await tester.pumpWidget(host(c, onChanged: visits.add, reduced: true));
      await pumpDrawer(tester);
      final reducedRotation = tester
          .widget<Transform>(transforms.last)
          .transform
          .clone();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Transform>(transforms.last).transform,
        reducedRotation,
      );
      await tester.tap(page(0));
      await tester.pump();
      await tester.tap(page(7));
      await pumpDrawer(tester);
      expect(c.order, [
        'page1',
        'page2',
        'page3',
        'page4',
        'page5',
        'page6',
        'page7',
        'page0',
      ]);
      expect(visits, isEmpty);
      await tester.tap(find.byKey(const Key('ui_drawer_finish_customizing')));
      await pumpDrawer(tester);
      expect(c.customizing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dragging customization commits an insertion without selecting', (
    tester,
  ) async {
    final c = UiBottomTabDrawerController()..customize();
    addTearDown(c.dispose);
    final visits = <int>[];
    await tester.pumpWidget(host(c, onChanged: visits.add));
    await pumpDrawer(tester);
    final drag = await tester.startGesture(tester.getCenter(page(0)));
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(tester.getCenter(page(7)));
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await pumpDrawer(tester);
    expect(c.order, [
      'page1',
      'page2',
      'page3',
      'page4',
      'page5',
      'page6',
      'page7',
      'page0',
    ]);
    expect(visits, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extra rows remain fixed relative to the revealing surface', (
    tester,
  ) async {
    final c = UiBottomTabDrawerController();
    addTearDown(c.dispose);
    await tester.pumpWidget(host(c));
    await pumpDrawer(tester);
    final surface = find.byKey(const Key('ui_expanding_dock_surface'));
    Offset relative() =>
        tester.getTopLeft(page(4)) - tester.getTopLeft(surface);
    final before = relative();
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 180));
    expect(relative().dx, closeTo(before.dx, .01));
    expect(relative().dy, closeTo(before.dy, .01));
    await pumpDrawer(tester);
    expect(relative().dy, closeTo(before.dy, .01));
  });

  testWidgets(
    'handle follows global finger travel and reverses without jitter',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = UiBottomTabDrawerController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await pumpDrawer(tester);
      final surface = find.byKey(const Key('ui_expanding_dock_surface'));
      final icon = find
          .descendant(of: page(0), matching: find.byType(UiBox))
          .first;
      expect(
        tester.getCenter(icon).dy,
        closeTo(tester.getCenter(surface).dy, .01),
      );
      final origin = tester.getCenter(handle);
      final gesture = await tester.startGesture(origin);
      await gesture.moveTo(origin - const Offset(0, 30));
      await tester.pump();
      expect(tester.getCenter(handle).dy, closeTo(origin.dy - 30, .5));
      await gesture.moveTo(origin - const Offset(0, 55));
      await tester.pump();
      expect(tester.getCenter(handle).dy, closeTo(origin.dy - 55, .5));
      await gesture.moveTo(origin - const Offset(0, 40));
      await tester.pump();
      expect(tester.getCenter(handle).dy, closeTo(origin.dy - 40, .5));
      await gesture.cancel();
      await pumpDrawer(tester);
      expect(tester.getCenter(handle).dy, closeTo(origin.dy, .5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text RTL and reduced motion retain usable drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = UiBottomTabDrawerController();
    addTearDown(c.dispose);
    await tester.pumpWidget(host(c, scale: 2, rtl: true, reduced: true));
    await pumpDrawer(tester);
    await tester.tap(handle);
    await pumpDrawer(tester);
    expect(c.expanded, isTrue);
    expect(tester.takeException(), isNull);
    c.close();
    await pumpDrawer(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the dock body (not the pill) drives the deck', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = UiBottomTabDrawerController();
    addTearDown(c.dispose);
    var selected = -1;
    await tester.pumpWidget(host(c, onChanged: (i) => selected = i));
    await pumpDrawer(tester);
    final surface = find.byKey(const Key('ui_expanding_dock_surface'));
    final handleTop = tester.getTopLeft(handle).dy;

    // A plain tap on a tile still selects it.
    await tester.tap(page(1));
    await pumpDrawer(tester);
    expect(selected, 1);
    expect(c.expanded, isFalse);

    // A vertical drag starting on a tile, far from the pill, opens the deck.
    final origin = tester.getCenter(page(2));
    final gesture = await tester.startGesture(origin);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(tester.getTopLeft(handle).dy, lessThan(handleTop - 60));
    await gesture.up();
    await pumpDrawer(tester);
    expect(c.expanded, isTrue);
    expect(tester.getSize(surface).height, greaterThan(64));
    expect(tester.takeException(), isNull);
  });
}
