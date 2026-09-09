import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _reducedMotionHost(Widget child) {
  return MaterialApp(
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: appChild ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  for (final size in [const Size(393, 852), const Size(393, 500)]) {
    testWidgets('toolbar menu shares trigger height above the title at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UiApp(
          home: Padding(
            padding: const EdgeInsets.only(top: 59),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const Expanded(
                      child: Center(child: UiText('Show Details')),
                    ),
                    UiDropdownMenu(
                      trigger: const SizedBox(width: 44, height: 44),
                      items: [
                        UiMenuItem(label: 'Pin chat', onPressed: () {}),
                        UiMenuItem(label: 'Leave chat', onPressed: () {}),
                        UiMenuItem(label: 'Archive chat', onPressed: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final trigger = tester.getRect(find.byType(UiDropdownMenu));
      final title = tester.getRect(find.text('Show Details'));
      await tester.tap(find.byType(UiDropdownMenu));
      await tester.pumpAndSettle();
      final surface = tester.widget<UiFluidSurface>(
        find.byType(UiFluidSurface).first,
      );
      final stack = tester.getTopLeft(find.byType(UiMenuStack));
      final bounds = surface.geometry.rect.shift(stack);
      expect(bounds.top, closeTo(trigger.top, .01));
      expect(bounds.overlaps(title), isTrue);
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      expect(find.text('Archive chat').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('outside tap closes menu and activates underlying control', (
    tester,
  ) async {
    var outsidePressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              UiDropdownMenu(
                consumeOutsideTap: false,
                trigger: const Text('Open menu'),
                items: [UiMenuItem(label: 'Profile', onPressed: () {})],
              ),
              const Spacer(),
              TextButton(
                onPressed: () => outsidePressed = true,
                child: const Text('Outside action'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Profile'), findsNothing);

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Outside action'));
    await tester.pumpAndSettle();
    expect(outsidePressed, isTrue);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('default outside tap dismisses without activating the page', (
    tester,
  ) async {
    var hit = false;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            const UiDropdownMenu(
              trigger: Text('Open'),
              items: [UiMenuItem(label: 'Action')],
            ),
            const Spacer(),
            TextButton(
              onPressed: () => hit = true,
              child: const Text('Outside'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Outside')));
    await tester.pumpAndSettle();
    expect(hit, isFalse);
    expect(find.text('Action'), findsNothing);
  });

  testWidgets('ancestor scroll dismisses but internal menu scroll does not', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        ListView(
          controller: controller,
          children: [
            UiDropdownMenu(
              consumeOutsideTap: false,
              trigger: const Text('Open'),
              items: List.generate(40, (i) => UiMenuItem(label: 'Action $i')),
            ),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Action 2'), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('Action 4'), findsOneWidget);
    controller.jumpTo(30);
    await tester.pumpAndSettle();
    expect(find.text('Action 4'), findsNothing);
  });

  testWidgets(
    'submenu action closes the root before its async callback finishes',
    (tester) async {
      final completed = Completer<void>();
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            trigger: const Text('Open'),
            items: [
              UiMenuSubmenu(
                label: 'Nested',
                items: [
                  UiMenuItem(
                    label: 'Action',
                    onPressed: () => completed.future,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nested'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(find.text('Action').hitTestable(), findsNothing);
      completed.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system Back dismisses the menu before leaving its page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const UiDropdownMenu(
          trigger: Text('Open'),
          items: [UiMenuItem(label: 'Action')],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('keyboard can open a submenu and activate its action', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Open'),
          items: [
            UiMenuSubmenu(
              label: 'Nested',
              items: [
                UiMenuItem(label: 'Action', onPressed: () => selected = true),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Action'), findsNothing);
  });

  testWidgets('outside dismissal can be disabled explicitly', (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          dismissOnTapOutside: false,
          trigger: const Text('Dismissible menu'),
          items: [UiMenuItem(label: 'Profile', onPressed: () {})],
        ),
      ),
    );

    await tester.tap(find.text('Dismissible menu'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('dropdown closes when the trigger is tapped again', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Open menu'),
          items: [UiMenuItem(label: 'Profile', onPressed: () {})],
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Open menu')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('long press can drag to a menu item and select on release', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Quick actions'),
          items: [
            UiMenuItem(label: 'First', onPressed: () => selected = 'First'),
            UiMenuItem(label: 'Second', onPressed: () => selected = 'Second'),
          ],
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Quick actions')),
    );
    await tester.pump(kLongPressTimeout);
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, 'Second');
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('long press release outside the menu does not select an item', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Quick actions'),
          items: [UiMenuItem(label: 'First', onPressed: () => selected = true)],
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Quick actions')),
    );
    await tester.pump(kLongPressTimeout);
    await tester.pumpAndSettle();
    await gesture.moveTo(const Offset(8, 8));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selected, isFalse);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('dropdown entrance resolves immediately with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _reducedMotionHost(
        UiDropdownMenu(
          trigger: const Text('Open menu'),
          items: [UiMenuItem(label: 'Profile', onPressed: () {})],
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(morph.controller.value, 1);
    expect(morph.controller.isAnimating, isFalse);
  });

  testWidgets('keyboard navigation activates focused row with Enter', (
    tester,
  ) async {
    var selected = '';
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Actions'),
          items: [
            UiMenuItem(label: 'First', onPressed: () => selected = 'First'),
            UiMenuItem(label: 'Second', onPressed: () => selected = 'Second'),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected, 'Second');
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('destructive and disabled rows expose semantics hints', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('More'),
          items: [
            UiMenuItem(label: 'Delete', destructive: true, onPressed: () {}),
            UiMenuItem(label: 'Archive', enabled: false, onPressed: () {}),
          ],
        ),
      ),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    final destructiveNode = tester.getSemantics(find.text('Delete'));
    expect(destructiveNode.hint, contains('destructive'));

    final disabledNode = tester.getSemantics(find.text('Archive'));
    expect(disabledNode.hint, contains('disabled'));
  });

  testWidgets('fully fitting content has no scroll extent', (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Fit menu'),
          items: [
            UiMenuItem(label: 'Profile', onPressed: () {}),
            UiMenuItem(label: 'Billing', onPressed: () {}),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Fit menu'));
    await tester.pumpAndSettle();

    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .maxScrollExtent,
      0,
    );
  });

  testWidgets('menu sizes to its widest item and keeps contiguous rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          minWidth: 0,
          trigger: const SizedBox(width: 20, child: Text('Open')),
          items: [
            UiMenuItem(label: 'A', onPressed: () {}),
            UiMenuItem(
              label: 'A wider menu item',
              shortcut: const UiMenuShortcut('⌘K'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final surface = find.byWidgetPredicate(
      (widget) =>
          widget is UiFluidSurface && widget.border.style == BorderStyle.solid,
    );
    final wideText = tester.getRect(find.text('A wider menu item'));
    final menuRect = tester.getRect(surface);
    expect(menuRect.width, greaterThan(wideText.width));
    expect(menuRect.width, lessThanOrEqualTo(320));

    final firstRow = tester.getRect(
      find
          .ancestor(of: find.text('A'), matching: find.byType(UiPressable))
          .first,
    );
    final secondRow = tester.getRect(
      find
          .ancestor(
            of: find.text('A wider menu item'),
            matching: find.byType(UiPressable),
          )
          .first,
    );
    expect(secondRow.top - firstRow.bottom, closeTo(0, 0.01));
  });

  testWidgets(
    'content-sized menu does not exceed the available viewport width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(180, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          UiDropdownMenu(
            minWidth: 0,
            maxWidth: 400,
            trigger: const Text('Open narrow menu'),
            items: [
              UiMenuItem(
                label: 'An item much wider than the available viewport',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Open narrow menu'));
      await tester.pumpAndSettle();

      final surface = find.byWidgetPredicate(
        (widget) =>
            widget is UiFluidSurface &&
            widget.border.style == BorderStyle.solid,
      );
      expect(tester.getRect(surface).width, lessThanOrEqualTo(180));
    },
  );

  testWidgets(
    'menu stays inside the app viewport and scrolls only when cramped',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: UiDropdownMenu(
                    trigger: const Text('Edge menu'),
                    items: [
                      for (var i = 0; i < 12; i++)
                        UiMenuItem(label: 'Action $i', onPressed: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edge menu'));
      await tester.pumpAndSettle();

      final surface = find.byWidgetPredicate(
        (widget) =>
            widget is UiFluidSurface &&
            widget.border.style == BorderStyle.solid,
      );
      expect(surface, findsOneWidget);
      final rect = tester.getRect(surface);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(240));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );

  testWidgets('menu uses theme surface tokens', (tester) async {
    await tester.pumpWidget(
      _host(
        UiDropdownMenu(
          trigger: const Text('Styled menu'),
          items: [UiMenuItem(label: 'Profile', onPressed: () {})],
        ),
      ),
    );

    await tester.tap(find.text('Styled menu'));
    await tester.pumpAndSettle();

    final tokens = UiThemeTokens.of(tester.element(find.text('Profile')));
    final surface = tester.widget<UiFluidSurface>(
      find.byWidgetPredicate(
        (widget) =>
            widget is UiFluidSurface &&
            widget.border.style == BorderStyle.solid,
      ),
    );
    expect(surface.geometry.radius, tokens.radius.lg.x);
    expect(surface.border.width, tokens.menu.borderWidth);
    final morph = tester.widget<UiFluidMorph>(find.byType(UiFluidMorph));
    expect(morph.backdropBlurSigma, tokens.menu.backdropBlurSigma);
    expect(morph.color.a, closeTo(tokens.menu.surfaceOpacity, .01));
  });

  testWidgets('open menu follows its trigger while the page scrolls', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 120),
              Align(
                alignment: Alignment.centerLeft,
                child: UiDropdownMenu(
                  scrollBehavior: UiMenuScrollBehavior.followAnchor,
                  trigger: const Text('Scrolling trigger'),
                  items: [
                    UiMenuItem(label: 'Scrolling action', onPressed: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scrolling trigger'));
    await tester.pumpAndSettle();
    final menuBefore = tester.getTopLeft(find.text('Scrolling action')).dy;

    controller.jumpTo(60);
    await tester.pump();
    await tester.pump();

    final menuAfter = tester.getTopLeft(find.text('Scrolling action')).dy;
    expect(menuAfter - menuBefore, closeTo(-60, 0.01));
    expect(find.text('Scrolling action'), findsOneWidget);
  });

  testWidgets('dropdowns paint and receive input above navigation chrome', (
    tester,
  ) async {
    var menuHit = false;
    var navigationHit = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiLayeredOverlayHost(
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 20,
                  child: UiDropdownMenu(
                    trigger: const Text('Layered menu'),
                    items: [
                      UiMenuItem(
                        label: 'Menu action',
                        onPressed: () => menuHit = true,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 44,
                  width: 220,
                  height: 44,
                  child: UiLayeredOverlayPortal(
                    layer: UiOverlayLayer.navigationChrome,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => navigationHit = true,
                      child: const ColoredBox(color: Color(0xFF000000)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Layered menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu action').hitTestable());
    await tester.pumpAndSettle();

    expect(navigationHit, isFalse);
    expect(menuHit, isTrue);
  });
}
