import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('sheet slots use roomier large-surface padding by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const UiSheet(
          header: UiSheetHeader(title: 'Sheet title'),
          footer: UiSheetFooter(children: [Text('Action')]),
          child: Text('Body'),
        ),
      ),
    );

    final paddings = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(UiSheet),
            matching: find.byType(Padding),
          ),
        )
        .map((padding) => padding.padding)
        .toList();

    expect(paddings, contains(const EdgeInsets.all(24)));
    expect(
      paddings,
      contains(const EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
    );
    expect(
      paddings,
      contains(const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 24)),
    );
  });

  testWidgets('sheet opens and returns typed result on controller dismiss', (
    tester,
  ) async {
    Future<String?>? pending;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Open sheet',
              onPressed: () {
                pending = UiSheetScope.show<String>(
                  context,
                  builder: (ctx, controller) => UiSheet(
                    child: UiButton(
                      label: 'Done',
                      onPressed: () => controller.dismiss('saved'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(await pending, 'saved');
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('sheet barrier dismisses when enabled', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Sheet',
              onPressed: () {
                UiSheetScope.show<void>(
                  context,
                  builder: (_, __) => const UiSheet(
                    child: SizedBox(height: 120, child: Text('Modal body')),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Modal body'), findsOneWidget);

    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(find.text('Modal body'), findsNothing);
  });

  testWidgets('sheet snap variants respect different max-height envelopes', (
    tester,
  ) async {
    Future<void> openWithSnap(UiSheetSnap snap) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              return UiButton(
                label: 'Open',
                onPressed: () {
                  UiSheetScope.show<void>(
                    context,
                    snap: snap,
                    builder: (_, __) => const UiSheet(
                      child: SizedBox(height: 2000, child: Text('Tall body')),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    await openWithSnap(const UiSheetSnap.half());
    final halfHeight = tester.getRect(find.byType(UiSheet)).height;

    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();

    await openWithSnap(const UiSheetSnap.full());
    final fullHeight = tester.getRect(find.byType(UiSheet)).height;

    expect(fullHeight, greaterThan(halfHeight));
  });

  group('UiPersistentSheet', () {
    testWidgets(
        'mounts at initial snap and leaves the host body interactive '
        '(no modal barrier)', (tester) async {
      var hostTaps = 0;
      final controller = UiPersistentSheetController(initialIndex: 0);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => hostTaps++,
                  child: const ColoredBox(color: Color(0xFFEEEEEE)),
                ),
              ),
              Positioned.fill(
                child: UiPersistentSheet(
                  controller: controller,
                  snaps: const [
                    UiSheetSnap.fraction(0.2),
                    UiSheetSnap.fraction(0.8),
                  ],
                  child: const UiSheet(
                    child: SizedBox(
                      height: 2000,
                      child: Text('Persistent body'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sheet is visible at initial peek.
      expect(find.text('Persistent body'), findsOneWidget);

      // Host area that the sheet doesn't cover is still tappable — the
      // persistent sheet must NOT install a modal barrier.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(hostTaps, 1);
    });

    testWidgets('controller.expand / collapse moves the sheet between snaps', (
      tester,
    ) async {
      final controller = UiPersistentSheetController(initialIndex: 0);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 800,
            child: UiPersistentSheet(
              controller: controller,
              snaps: const [
                UiSheetSnap.fraction(0.2),
                UiSheetSnap.fraction(0.8),
              ],
              child: const UiSheet(
                child: SizedBox(height: 2000, child: Text('Body')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final peekHeight =
          tester.getRect(find.byKey(persistentSheetSurfaceKey)).height;

      controller.expand();
      await tester.pumpAndSettle();

      final expandedHeight =
          tester.getRect(find.byKey(persistentSheetSurfaceKey)).height;
      expect(expandedHeight, greaterThan(peekHeight));
      expect(controller.snapIndex, 1);
      expect(controller.isExpanded, isTrue);

      controller.collapse();
      await tester.pumpAndSettle();

      expect(controller.snapIndex, 0);
      expect(controller.isExpanded, isFalse);
    });

    testWidgets('upward drag past midpoint snaps to the larger snap', (
      tester,
    ) async {
      final controller = UiPersistentSheetController(initialIndex: 0);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 800,
            child: UiPersistentSheet(
              controller: controller,
              snaps: const [
                UiSheetSnap.fraction(0.2),
                UiSheetSnap.fraction(0.8),
              ],
              child: const UiSheet(
                child: SizedBox(height: 2000, child: Text('Body')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.snapIndex, 0);

      // Drag up from the peek-sized surface (bottom ~120pt). Fraction
      // grows as the finger moves up, so we target the visible sheet
      // body, not the outer layout-filling UiPersistentSheet.
      final start = tester.getCenter(find.byKey(persistentSheetSurfaceKey));
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(0, -25));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.snapIndex, 1);
    });

    testWidgets('allowClose + onClose fire only on strong downward swipe', (
      tester,
    ) async {
      var closed = 0;
      final controller = UiPersistentSheetController(initialIndex: 1);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 800,
            child: UiPersistentSheet(
              controller: controller,
              allowClose: true,
              onClose: () => closed++,
              snaps: const [
                UiSheetSnap.fraction(0.2),
                UiSheetSnap.fraction(0.8),
              ],
              child: const UiSheet(
                child: SizedBox(height: 2000, child: Text('Body')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(closed, 0);

      // Small drag at snap 0 (peek) should not trigger close.
      controller.collapse();
      await tester.pumpAndSettle();
      final start = tester.getCenter(find.byKey(persistentSheetSurfaceKey));
      var gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 10));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(closed, 0);

      // Strong downward fling from peek dismisses.
      gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(closed, 1);
    });

    testWidgets('internal controller lifecycle does not throw on unmount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 400,
            child: UiPersistentSheet(
              snaps: const [UiSheetSnap.fraction(0.3)],
              child: const UiSheet(child: Text('Body')),
            ),
          ),
        ),
      );
      await tester.pump();
      // Replace subtree to trigger dispose.
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet body is exposed as a semantics container', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 400,
            child: UiPersistentSheet(
              snaps: const [UiSheetSnap.fraction(0.5)],
              child: const UiSheet(child: Text('Body')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final matchingSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Sheet',
      );
      expect(matchingSemantics, findsOneWidget);
    });
  });

  testWidgets('drawer opens and closes from barrier tap', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Open drawer',
              onPressed: () {
                UiDrawerScope.show<void>(
                  context,
                  builder: (_) => const UiDrawer(child: Text('Drawer content')),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();
    expect(find.text('Drawer content'), findsOneWidget);

    await tester.tapAt(const Offset(790, 10));
    await tester.pumpAndSettle();
    expect(find.text('Drawer content'), findsNothing);
  });

  testWidgets('drawer controller returns typed result', (tester) async {
    Future<String?>? pending;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Open controlled drawer',
              onPressed: () {
                pending = UiDrawerScope.show<String>(
                  context,
                  builder: (_) => const SizedBox.shrink(),
                  controlledBuilder: (_, controller) => UiDrawer(
                    child: UiButton(
                      label: 'Close drawer',
                      onPressed: () => controller.dismiss('closed'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open controlled drawer'));
    await tester.pumpAndSettle();
    expect(find.text('Close drawer'), findsOneWidget);

    await tester.tap(find.text('Close drawer'));
    await tester.pumpAndSettle();

    expect(await pending, 'closed');
    expect(find.text('Close drawer'), findsNothing);
  });

  testWidgets('drawer scope applies floating inset styling', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Open floating drawer',
              onPressed: () {
                UiDrawerScope.show<void>(
                  context,
                  variant: UiDrawerVariant.floating,
                  blurBackdrop: false,
                  builder: (_) =>
                      const UiDrawer(child: Text('Floating drawer content')),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open floating drawer'));
    await tester.pumpAndSettle();

    final textRect = tester.getRect(find.text('Floating drawer content'));
    expect(textRect.left, greaterThan(0));

    await tester.tapAt(const Offset(790, 10));
    await tester.pumpAndSettle();
    expect(find.text('Floating drawer content'), findsNothing);
  });

  testWidgets('drawer safe area wraps the outer surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(top: 44, bottom: 34),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiDrawer(width: 200, child: Text('Safe drawer content')),
            ),
          ),
        ),
      ),
    );

    final textRect = tester.getRect(find.text('Safe drawer content'));
    expect(textRect.top, greaterThanOrEqualTo(44));
  });

  testWidgets('structured drawer pins header and footer while body scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 420,
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiDrawer(
                width: 260,
                header: const UiDrawerHeader(title: 'Drawer title'),
                body: Column(
                  children: [
                    for (var index = 0; index < 30; index++)
                      SizedBox(height: 40, child: Text('Body item $index')),
                  ],
                ),
                footer: const UiDrawerFooter(child: Text('Drawer footer')),
              ),
            ),
          ),
        ),
      ),
    );

    final headerBefore = tester.getTopLeft(find.text('Drawer title'));
    final footerBefore = tester.getTopLeft(find.text('Drawer footer'));
    final bodyBefore = tester.getTopLeft(find.text('Body item 3'));

    await tester.drag(find.text('Body item 3'), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Drawer title')), headerBefore);
    expect(tester.getTopLeft(find.text('Drawer footer')), footerBefore);
    expect(
      tester.getTopLeft(find.text('Body item 3')).dy,
      lessThan(bodyBefore.dy),
    );
  });

  testWidgets('structured drawer regions use roomier default padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.centerLeft,
            child: UiDrawer(
              header: UiDrawerHeader(title: 'Drawer title'),
              body: UiDrawerSection(
                title: 'Section title',
                child: Text('Drawer body'),
              ),
              footer: UiDrawerFooter(child: Text('Drawer footer')),
            ),
          ),
        ),
      ),
    );

    final headerPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(UiDrawerHeader),
            matching: find.byType(Padding),
          )
          .first,
    );
    final sectionPaddings = tester
        .widgetList<Padding>(
          find.descendant(
            of: find.byType(UiDrawerSection),
            matching: find.byType(Padding),
          ),
        )
        .map((padding) => padding.padding)
        .toList();
    final footerPadding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(UiDrawerFooter),
            matching: find.byType(Padding),
          )
          .first,
    );

    expect(
      headerPadding.padding,
      const EdgeInsetsDirectional.fromSTEB(24, 20, 16, 16),
    );
    expect(
      sectionPaddings,
      contains(const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12)),
    );
    expect(
      sectionPaddings,
      contains(const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4)),
    );
    expect(footerPadding.padding, const EdgeInsets.all(12));
  });

  testWidgets('floating drawer reduces bottom safe-area gap near device edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 390,
              height: 844,
              child: Align(
                alignment: Alignment.centerLeft,
                child: UiDrawer(
                  width: 200,
                  variant: UiDrawerVariant.floating,
                  child: SizedBox.expand(child: Text('Floating safe drawer')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final clipRect = tester.getRect(
      find.descendant(
        of: find.byType(UiDrawer),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clipRect.bottom, greaterThan(820));
  });

  testWidgets('floating drawer and navigation rows use concentric radii', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: 640,
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiNavigationDrawer(
                title: 'More',
                variant: UiDrawerVariant.stacked,
                destinations: [
                  UiNavigationDrawerDestination(
                    label: 'Home',
                    selected: true,
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(UiDrawer),
        matching: find.byType(ClipRRect),
      ),
    );
    final outer = clip.borderRadius.resolve(TextDirection.ltr);
    final focus = tester.widget<UiFocusRing>(find.byType(UiFocusRing));
    final inner = focus.borderRadius!.resolve(TextDirection.ltr);

    expect(outer.topLeft.x, greaterThan(24));
    expect(inner.topLeft.x, closeTo(outer.topLeft.x - 8, 0.1));
  });

  testWidgets('navigation drawer renders numeric destination badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: UiNavigationDrawer(
            title: 'More',
            destinations: [
              UiNavigationDrawerDestination(
                label: 'Alerts',
                badgeCount: 5,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(UiNavigationCountBadge), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('navigation drawer rows use comfortable content padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: UiNavigationDrawer(
            title: 'More',
            destinations: [
              UiNavigationDrawerDestination(
                label: 'Home',
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    final rowBox = tester.widget<UiBox>(
      find.ancestor(of: find.text('Home'), matching: find.byType(UiBox)).first,
    );
    final rowAncestorPaddings = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.text('Home'),
            matching: find.byType(Padding),
          ),
        )
        .map((padding) => padding.padding)
        .toList();

    expect(
      rowBox.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
    expect(
      rowAncestorPaddings,
      contains(const EdgeInsets.symmetric(vertical: 4)),
    );
  });

  testWidgets('drawer infers edge radius from device safe-area signals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.centerLeft,
              child: UiDrawer(
                width: 200,
                child: Text('Rounded drawer content'),
              ),
            ),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.descendant(
        of: find.byType(UiDrawer),
        matching: find.byType(ClipRRect),
      ),
    );
    final radius = clip.borderRadius.resolve(TextDirection.ltr);

    expect(radius.topLeft.x, greaterThan(0));
    expect(radius.bottomLeft.x, greaterThan(0));
    expect(radius.topRight.x, 0);
    expect(radius.bottomRight.x, 0);
  });

  testWidgets(
    'stacked nested drawers push older drawers behind the front one',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              return UiButton(
                label: 'Open stack',
                onPressed: () {
                  UiDrawerScope.show<void>(
                    context,
                    side: UiDrawerSide.right,
                    variant: UiDrawerVariant.stacked,
                    blurBackdrop: false,
                    builder: (outerContext) => UiDrawer(
                      width: 280,
                      child: Column(
                        children: [
                          const Text('First stacked drawer'),
                          UiButton(
                            label: 'Open nested drawer',
                            onPressed: () {
                              UiDrawerScope.show<void>(
                                outerContext,
                                side: UiDrawerSide.right,
                                variant: UiDrawerVariant.stacked,
                                blurBackdrop: false,
                                builder: (_) => const UiDrawer(
                                  width: 280,
                                  child: Text('Second stacked drawer'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open stack'));
      await tester.pumpAndSettle();
      final firstBefore = tester.getRect(find.text('First stacked drawer'));

      await tester.tap(find.text('Open nested drawer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final firstDuringOpen = tester.getRect(find.text('First stacked drawer'));
      final secondDuringOpen = tester.getRect(
        find.text('Second stacked drawer'),
      );

      await tester.pumpAndSettle();

      final firstAfter = tester.getRect(find.text('First stacked drawer'));
      final second = tester.getRect(find.text('Second stacked drawer'));

      expect(firstDuringOpen.left, greaterThan(firstAfter.left));
      expect(secondDuringOpen.left, greaterThan(second.left));
      expect(firstAfter.left, lessThan(firstBefore.left));
      expect(second.left, greaterThan(firstAfter.left));

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final firstDuringClose = tester.getRect(
        find.text('First stacked drawer'),
      );
      final secondDuringClose = tester.getRect(
        find.text('Second stacked drawer'),
      );
      expect(find.text('Second stacked drawer'), findsOneWidget);
      expect(firstDuringClose.left, greaterThan(firstAfter.left));
      expect(secondDuringClose.left, greaterThan(second.left + 80));

      await tester.pumpAndSettle();
      expect(find.text('Second stacked drawer'), findsNothing);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('stacked nested left drawers share backdrop and expose depth', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            return UiButton(
              label: 'Open left stack',
              onPressed: () {
                UiDrawerScope.show<void>(
                  context,
                  side: UiDrawerSide.left,
                  variant: UiDrawerVariant.stacked,
                  blurBackdrop: true,
                  builder: (outerContext) => UiDrawer(
                    width: 280,
                    child: Column(
                      children: [
                        const Text('First left drawer'),
                        UiButton(
                          label: 'Open nested left drawer',
                          onPressed: () {
                            UiDrawerScope.show<void>(
                              outerContext,
                              side: UiDrawerSide.left,
                              variant: UiDrawerVariant.stacked,
                              blurBackdrop: true,
                              builder: (_) => const UiDrawer(
                                width: 280,
                                child: Text('Second left drawer'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open left stack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open nested left drawer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final firstDuringOpen = tester.getRect(find.text('First left drawer'));
    final secondDuringOpen = tester.getRect(find.text('Second left drawer'));

    await tester.pumpAndSettle();

    final firstDrawer = find.ancestor(
      of: find.text('First left drawer'),
      matching: find.byType(UiDrawer),
    );
    final secondDrawer = find.ancestor(
      of: find.text('Second left drawer'),
      matching: find.byType(UiDrawer),
    );
    final first = tester.getRect(firstDrawer);
    final second = tester.getRect(secondDrawer);

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(firstDuringOpen.right, lessThan(first.right));
    expect(secondDuringOpen.right, lessThan(second.right));
    expect(first.right, greaterThan(second.right));

    final shadowedDrawerSurfaces = tester
        .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(UiDrawer),
        matching: find.byType(DecoratedBox),
      ),
    )
        .where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          (decoration.boxShadow?.isNotEmpty ?? false);
    });
    expect(shadowedDrawerSurfaces.length, 1);

    await tester.tapAt(const Offset(780, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final firstDuringClose = tester.getRect(firstDrawer);
    final secondDuringClose = tester.getRect(secondDrawer);
    expect(find.text('Second left drawer'), findsOneWidget);
    expect(firstDuringClose.right, lessThan(first.right));
    expect(secondDuringClose.right, lessThan(second.right - 80));

    await tester.pumpAndSettle();
    expect(find.text('Second left drawer'), findsNothing);
    await tester.tapAt(const Offset(780, 20));
    await tester.pumpAndSettle();
  });

  testWidgets('sidebar supports keyboard focus and activation', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      _host(
        UiSidebar(
          items: [UiSidebarItem(label: 'Courses', onPressed: () => presses++)],
        ),
      ),
    );

    var activated = false;
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      if (presses > 0) {
        activated = true;
        break;
      }
    }

    expect(activated, isTrue);
  });
}

void _noop() {}
