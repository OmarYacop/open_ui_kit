import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets(
    'nested menus retain parents at 96%, isolate input and restore on Back',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: UiMenuStack(
                title: 'Actions',
                items: [
                  UiMenuItem(
                    label: 'Parent action',
                    onPressed: () => selected++,
                  ),
                  UiMenuSubmenu(
                    label: 'Organize',
                    items: [
                      UiMenuSubmenu(
                        label: 'Move',
                        items: [
                          UiMenuItem(
                            label: 'Work',
                            onPressed: () => selected++,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Organize'));
      await tester.pump();
      final opening = tester.widget<UiMenuTransition>(
        find.byType(UiMenuTransition),
      );
      expect(opening.controller.value, .34);
      expect(
        find.text('Organize'),
        findsOneWidget,
        reason: 'The trigger transfers its only visible label into the morph',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(opening.controller.isAnimating, isTrue);
      final earlyScales = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(UiMenuStack),
          matching: find.byType(Transform),
        ),
      );
      expect(
        earlyScales.any((t) => (t.transform.entry(0, 0) - .96).abs() < .001),
        isTrue,
      );
      await tester.pumpAndSettle();
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(UiMenuStack),
          matching: find.byType(Transform),
        ),
      );
      expect(
        transforms.any((t) => (t.transform.entry(0, 0) - .96).abs() < .001),
        isTrue,
      );

      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Work'));
      expect(selected, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      final restored = tester
          .widgetList<UiPressable>(find.byType(UiPressable))
          .singleWhere((pressable) => pressable.semanticsLabel == 'Organize');
      expect(restored.focusNode!.hasFocus, isTrue);
      await tester.tap(find.text('Parent action'));
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion, disabled rows, narrow large text and RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.5),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: SizedBox(
                width: 280,
                height: 360,
                child: UiMenuStack(
                  title: 'Actions',
                  items: const [
                    UiMenuSubmenu(
                      label: 'Unavailable',
                      enabled: false,
                      items: [],
                    ),
                    UiMenuSubmenu(
                      label: 'Organize',
                      items: [UiMenuItem(label: 'Loading', loading: true)],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<BackdropFilter>(find.byType(BackdropFilter))
          .where((filter) => filter.enabled),
      isEmpty,
    );
    await tester.tap(find.text('Unavailable'));
    await tester.pump();
    expect(find.byType(UiMenuTransition), findsNothing);
    await tester.tap(find.text('Organize'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<UiMenuTransition>(find.byType(UiMenuTransition))
          .controller
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Back closes an opening submenu and its parent can reverse it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const UiApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 400,
            child: UiMenuStack(
              title: 'Actions',
              items: [
                UiMenuSubmenu(
                  label: 'Organize',
                  items: [UiMenuItem(label: 'Item')],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Organize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final controller = tester
        .widget<UiMenuTransition>(find.byType(UiMenuTransition))
        .controller;
    expect(controller.isAnimating, isTrue);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is UiPressable && widget.semanticsLabel == 'Back',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.target, 0);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is UiPressable && widget.semanticsLabel == 'Organize',
      ),
    );
    expect(controller.target, 1);
    await tester.pumpAndSettle();
    expect(controller.value, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'parent trigger is reusable on the first closing frame; only parents are shaded',
    (tester) async {
      await tester.pumpWidget(
        const UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: UiMenuStack(
                title: 'Actions',
                items: [
                  UiMenuSubmenu(
                    label: 'Organize',
                    items: [UiMenuItem(label: 'Item')],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final rootTint = tester
          .widget<UiFluidSurface>(find.byType(UiFluidSurface))
          .foregroundColor;
      expect(rootTint.a, 0);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(
        tester
            .widgetList<BackdropFilter>(find.byType(BackdropFilter))
            .where((filter) => filter.enabled),
        hasLength(1),
      );
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<UiMenuTransition>(find.byType(UiMenuTransition))
          .controller;
      final morph = tester.widget<UiMenuTransition>(
        find.byType(UiMenuTransition),
      );
      expect(
        morph.destinationGeometry.rect.topLeft,
        morph.sourceGeometry.rect.topLeft,
      );
      expect(morph.overlayBuilder, isNotNull);
      final activeBlur = find.byWidgetPredicate(
        (widget) => widget is BackdropFilter && widget.enabled,
      );
      expect(activeBlur, findsNWidgets(2));
      for (final element in activeBlur.evaluate()) {
        expect(element.findAncestorWidgetOfExactType<ClipRRect>(), isNotNull);
      }
      final surfaces = tester
          .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
          .toList();
      expect(surfaces.first.foregroundColor.a, greaterThan(0));
      for (final surface in surfaces) {
        expect(
          surface.color.a,
          closeTo(UiMenuTokens.defaults.surfaceOpacity, .001),
        );
        expect(surface.backdropBlurSigma, 16);
        expect(surface.border.width, UiMenuTokens.defaults.borderWidth);
        expect(surface.border.color.a, closeTo(.18, .001));
      }
      expect(surfaces.last.foregroundColor.a, 0);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is UiPressable && widget.semanticsLabel == 'Back',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.transitionProgress, lessThan(.22));
      expect(controller.isAnimating, isTrue);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is UiPressable && widget.semanticsLabel == 'Organize',
        ),
      );
      expect(controller.target, 1);
      await tester.pumpAndSettle();
      expect(find.byType(UiMenuTransition), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is UiPressable && widget.semanticsLabel == 'Back',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(controller.isAnimating, isTrue);
      expect(find.text('Organize'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is UiPressable && widget.semanticsLabel == 'Organize',
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.value, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('closing preserves title bounds and returns opener paint once', (
    tester,
  ) async {
    final leadingKey = GlobalKey();
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 400,
            child: UiMenuStack(
              title: 'Actions',
              items: [
                UiMenuSubmenu(
                  label: 'Organize',
                  leading: SizedBox(key: leadingKey, width: 18, height: 18),
                  items: const [UiMenuItem(label: 'Item')],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final trigger = find.byWidgetPredicate(
      (w) => w is UiPressable && w.semanticsLabel == 'Organize',
    );
    final originalSize = tester.getSize(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final morph = tester.widget<UiMenuTransition>(
      find.byType(UiMenuTransition),
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is UiPressable && w.semanticsLabel == 'Back',
      ),
    );
    await tester.pump();
    final itemSize = tester.getRect(find.text('Item')).size;
    expect(
      morph.destinationGeometry.rect.height,
      lessThan(200),
      reason: 'A single item should size the menu, not fill the viewport',
    );
    var sawSurfaceMerge = false;
    var sawOvershoot = false;
    var previousHeight = morph.destinationGeometry.rect.height;
    for (var i = 0; i < 34; i++) {
      await tester.pump(const Duration(milliseconds: 8));
      expect(find.text('Organize'), findsOneWidget);
      expect(find.byKey(leadingKey), findsOneWidget);
      expect(tester.getSize(trigger), originalSize);
      expect(
        find.descendant(of: trigger, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: trigger, matching: find.text('Organize')),
        findsNothing,
      );
      final painted = tester
          .widgetList<UiFluidSurface>(
            find.descendant(
              of: find.byType(UiMenuTransition),
              matching: find.byType(UiFluidSurface),
            ),
          )
          .first;
      expect(
        tester.getRect(find.text('Item')).size,
        itemSize,
        reason: 'Clipping must not scale the rows',
      );
      expect(
        painted.opacity,
        1,
        reason: 'Rows retract by clipping, not an early fade',
      );
      expect(painted.fit, BoxFit.none);
      expect(
        painted.geometry.rect.height,
        lessThanOrEqualTo(previousHeight + .001),
      );
      expect(
        painted.geometry.rect.width,
        greaterThanOrEqualTo(morph.sourceGeometry.rect.width),
      );
      previousHeight = painted.geometry.rect.height;
      if (painted.geometry.rect.height > morph.sourceGeometry.rect.height &&
          painted.color.a < .1) {
        sawSurfaceMerge = true;
      }
      sawOvershoot |=
          painted.geometry.rect.height < morph.sourceGeometry.rect.height;
      expect(tester.takeException(), isNull);
    }
    expect(
      sawSurfaceMerge,
      isTrue,
      reason: 'Surface joins its parent before reaching the row',
    );
    expect(
      sawOvershoot,
      isFalse,
      reason: 'Closing must never clip the boundary below the title row',
    );
    await tester.pumpAndSettle();
    expect(find.byType(UiMenuTransition), findsNothing);
    expect(
      find.descendant(of: trigger, matching: find.text('Organize')),
      findsOneWidget,
    );
    expect(find.byKey(leadingKey), findsOneWidget);
    expect(tester.getSize(trigger), originalSize);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rapid Back closes successive levels without reopening; touch restoration stays plain',
    (tester) async {
      final focus = FocusManager.instance;
      final strategy = focus.highlightStrategy;
      focus.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      addTearDown(() => focus.highlightStrategy = strategy);
      await tester.pumpWidget(
        const UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: UiMenuStack(
                title: 'Actions',
                items: [
                  UiMenuSubmenu(
                    label: 'Organize',
                    items: [
                      UiMenuSubmenu(
                        label: 'Move',
                        items: [UiMenuItem(label: 'Item')],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      final controllers = tester
          .widgetList<UiMenuTransition>(find.byType(UiMenuTransition))
          .map((w) => w.controller)
          .toList();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controllers.every((c) => c.target == 0), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controllers.every((c) => c.target == 0), isTrue);
      await tester.pump(const Duration(milliseconds: 290));
      await tester.pump();
      expect(find.byType(UiMenuTransition), findsNothing);
      final row = find.byWidgetPredicate(
        (w) => w is UiPressable && w.semanticsLabel == 'Organize',
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: row,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color!.a, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outside and selection request dismissal without affecting internal scroll',
    (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: UiMenuStack(
                title: 'Actions',
                onDismiss: () => dismissals++,
                items: [
                  UiMenuSubmenu(
                    label: 'Organize',
                    items: [UiMenuItem(label: 'Item')],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(dismissals, 1);
      expect(find.byType(UiMenuTransition), findsNothing);
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Item'));
      await tester.pumpAndSettle();
      expect(dismissals, 2);
    },
  );
  testWidgets(
    'header tap closes only its submenu, never counts as an outside tap',
    (tester) async {
      var dismissals = 0;
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: UiMenuStack(
                title: 'Actions',
                onDismiss: () => dismissals++,
                items: const [
                  UiMenuSubmenu(
                    label: 'Organize',
                    items: [
                      UiMenuSubmenu(
                        label: 'Move',
                        items: [UiMenuItem(label: 'Item')],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Organize'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      final controllers = tester
          .widgetList<UiMenuTransition>(find.byType(UiMenuTransition))
          .map((w) => w.controller)
          .toList();
      final back = find
          .byWidgetPredicate(
            (w) => w is UiPressable && w.semanticsLabel == 'Back',
          )
          .hitTestable();
      await tester.tap(back);
      await tester.pump();
      expect(dismissals, 0, reason: 'A header press is inside the menu group');
      expect(
        controllers.first.target,
        1,
        reason: 'The parent must remain open',
      );
      expect(controllers.last.target, 0);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(back);
      await tester.pump();
      expect(controllers.every((c) => c.target == 0), isTrue);
      expect(dismissals, 0);
      await tester.pumpAndSettle();
      expect(find.byType(UiMenuTransition), findsNothing);
    },
  );
  testWidgets(
    'held selection scrolls at the edge and cancellation never activates',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        UiApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 220,
              child: UiMenuStack(
                title: 'Actions',
                items: List.generate(
                  20,
                  (i) => UiMenuItem(
                    label: 'Action $i',
                    onPressed: () => selected++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action 0')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final scroll = find.descendant(
        of: find.byType(UiMenuStack),
        matching: find.byType(SingleChildScrollView),
      );
      final bounds = tester.getRect(scroll);
      await gesture.moveTo(Offset(bounds.center.dx, bounds.bottom - 8));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        tester.widget<SingleChildScrollView>(scroll).controller!.offset,
        greaterThan(0),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
