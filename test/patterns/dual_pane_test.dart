import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: child,
        bottomNavigationBar: const Text('shell bottom bar'),
      ),
    ),
  );
}

// The framework runs `debugAssertAllFoundationVarsUnset` before a regular
// `addTearDown` callback fires, so the override must be cleared inside the
// test body itself — wrap it in this helper rather than tearing down late.
Future<T> _runWithPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('phone pushes detail above shell chrome', (tester) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          primaryBuilder: (context, selected, select) {
            return UiButton(label: 'Open detail', onPressed: () => select('a'));
          },
          detailBuilder: (context, selected, select) {
            return Column(
              children: [
                Text('detail:$selected'),
                UiButton(label: 'Back', onPressed: () => select(null)),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsOneWidget);
    expect(find.text('detail:a'), findsNothing);

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('detail:a'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('shell bottom bar'), findsOneWidget);
  });

  testWidgets('wide form factor shows both panes', (tester) async {
    final controller = UiDualPaneController<String>(selected: 'a');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          primaryBuilder: (context, selected, select) => const Text('primary'),
          detailBuilder: (context, selected, select) =>
              Text('detail:$selected'),
        ),
        size: const Size(1000, 800),
      ),
    );

    expect(find.text('primary'), findsOneWidget);
    expect(find.text('detail:a'), findsOneWidget);
  });

  testWidgets('tablet overlay mode preserves primary and focuses detail', (
    tester,
  ) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          tabletMode: UiDualPaneTabletMode.overlayDetail,
          primaryBuilder: (context, selected, select) =>
              UiButton(label: 'Open detail', onPressed: () => select('a')),
          detailBuilder: (context, selected, select) {
            if (selected == null) {
              return const Text('Select an item');
            }
            return Column(
              children: [
                Text('detail:$selected'),
                UiButton(label: 'Close detail', onPressed: () => select(null)),
              ],
            );
          },
        ),
        size: const Size(700, 1000),
      ),
    );

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('detail:a'), findsOneWidget);

    await tester.tap(find.text('Close detail'));
    await tester.pump();
    expect(
      find.text('detail:a'),
      findsOneWidget,
      reason: 'Overlay detail should remain mounted during reverse motion.',
    );
    expect(
      find.text('Select an item'),
      findsNothing,
      reason: 'The outgoing detail must not flash its empty state.',
    );
    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsNothing);
  });

  testWidgets('wide detail can stay collapsed until selection', (tester) async {
    final controller = UiDualPaneController<String>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        UiDualPane<String>(
          controller: controller,
          collapseDetailWithoutSelection: true,
          primaryBuilder: (context, selected, select) =>
              UiButton(label: 'Open detail', onPressed: () => select('a')),
          detailBuilder: (context, selected, select) =>
              Text('detail:$selected'),
        ),
        size: const Size(1200, 800),
      ),
    );

    expect(find.text('detail:null'), findsNothing);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsOneWidget,
    );
    final initialPrimaryWidth = tester
        .getSize(find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')))
        .width;

    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final animatingPrimaryWidth = tester
        .getSize(find.byKey(const ValueKey('ui-dual-pane-wide-primary')))
        .width;
    expect(animatingPrimaryWidth, lessThan(initialPrimaryWidth));

    await tester.pumpAndSettle();

    expect(find.text('detail:a'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsNothing,
    );
    final settledPrimaryWidth = tester
        .getSize(find.byKey(const ValueKey('ui-dual-pane-wide-primary')))
        .width;
    final settledDetailWidth = tester
        .getSize(find.byKey(const ValueKey('ui-dual-pane-wide-detail')))
        .width;
    expect(animatingPrimaryWidth, greaterThan(settledPrimaryWidth));
    expect(settledDetailWidth, greaterThan(settledPrimaryWidth));

    controller.clear();
    await tester.pump();

    expect(
      find.text('detail:a'),
      findsOneWidget,
      reason: 'The detail remains mounted while its reverse transition runs.',
    );

    await tester.pumpAndSettle();
    expect(find.text('detail:a'), findsNothing);
    expect(
      find.byKey(const ValueKey('ui-dual-pane-wide-primary-only')),
      findsOneWidget,
    );
  });

  group('phone edge-swipe pop', () {
    Widget dualPane(
      UiDualPaneController<String> controller, {
      UiNavigationTransitionStyle style = UiNavigationTransitionStyle.softShift,
    }) {
      return UiDualPane<String>(
        controller: controller,
        phoneTransitionStyle: style,
        primaryBuilder: (context, selected, select) {
          return UiButton(label: 'Open detail', onPressed: () => select('a'));
        },
        detailBuilder: (context, selected, select) {
          return Column(
            children: [
              Text('detail:$selected', key: const Key('detail-text')),
              UiButton(label: 'Back', onPressed: () => select(null)),
            ],
          );
        },
      );
    }

    // The gesture drives the route's own AnimationController: dragging
    // right by `fraction` of the screen width reduces `controller.value`
    // by roughly that fraction (see UiCupertinoBackGestureMixin).
    //
    // A single large moveBy() only ever produces the drag recognizer's
    // *start* event (consuming the whole delta as the touch-slop
    // crossing) and never a distinct onUpdate — the controller value
    // genuinely never moves. Small incremental steps are required for
    // `dragUpdate` (and so `route.controller.value`) to actually advance.
    Future<TestGesture> startDragFromEdge(
      WidgetTester tester, {
      required double fraction,
    }) async {
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final gesture = await tester.startGesture(const Offset(6, 400));
      const steps = 10;
      for (var i = 1; i <= steps; i++) {
        await gesture.moveBy(Offset(width * fraction / steps, 0));
        await tester.pump(const Duration(milliseconds: 4));
      }
      return gesture;
    }

    Future<void> dragFromEdge(
      WidgetTester tester, {
      required double fraction,
    }) async {
      final gesture = await startDragFromEdge(tester, fraction: fraction);
      await gesture.up();
    }

    testWidgets(
      'dragging past halfway from the left edge on iOS pops the pushed '
      'detail route',
      (tester) async {
        await _runWithPlatform(TargetPlatform.iOS, () async {
          final controller = UiDualPaneController<String>();
          addTearDown(controller.dispose);

          await tester.pumpWidget(_host(dualPane(controller)));
          await tester.tap(find.text('Open detail'));
          await tester.pumpAndSettle();
          expect(find.text('detail:a'), findsOneWidget);

          await dragFromEdge(tester, fraction: 0.6);
          await tester.pumpAndSettle();

          expect(find.text('Open detail'), findsOneWidget);
          expect(find.text('shell bottom bar'), findsOneWidget);
          expect(find.text('detail:a'), findsNothing);
        });
      },
    );

    testWidgets(
      'a short drag that stays under halfway snaps back without popping',
      (tester) async {
        await _runWithPlatform(TargetPlatform.iOS, () async {
          final controller = UiDualPaneController<String>();
          addTearDown(controller.dispose);

          await tester.pumpWidget(_host(dualPane(controller)));
          await tester.tap(find.text('Open detail'));
          await tester.pumpAndSettle();

          await dragFromEdge(tester, fraction: 0.15);
          await tester.pumpAndSettle();

          expect(find.text('detail:a'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      },
    );

    testWidgets(
      'mid-drag the outgoing page uses the same UiNavigationTransition a '
      'tap-triggered pop uses, driven by the real route animation',
      (tester) async {
        await _runWithPlatform(TargetPlatform.iOS, () async {
          final controller = UiDualPaneController<String>();
          addTearDown(controller.dispose);

          await tester.pumpWidget(_host(dualPane(controller)));
          await tester.tap(find.text('Open detail'));
          await tester.pumpAndSettle();

          final gesture = await startDragFromEdge(tester, fraction: 0.3);

          expect(find.byType(UiNavigationTransition), findsWidgets);
          // The real primary page underneath is genuinely present — Flutter's
          // own Navigator paints both routes correctly mid-transition, no
          // hand-built compositing needed.
          expect(find.text('Open detail'), findsOneWidget);

          await gesture.up();
          await tester.pumpAndSettle();
        });
      },
    );

    testWidgets(
      'a fade-styled pane does not horizontally track the drag — only '
      'opacity changes',
      (tester) async {
        await _runWithPlatform(TargetPlatform.iOS, () async {
          final controller = UiDualPaneController<String>();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            _host(
              dualPane(controller, style: UiNavigationTransitionStyle.fade),
            ),
          );
          await tester.tap(find.text('Open detail'));
          await tester.pumpAndSettle();

          final restLeft = tester
              .getRect(find.byKey(const Key('detail-text')))
              .left;

          final gesture = await startDragFromEdge(tester, fraction: 0.3);

          final draggedLeft = tester
              .getRect(find.byKey(const Key('detail-text')))
              .left;
          expect(draggedLeft, restLeft);

          await gesture.up();
          await tester.pumpAndSettle();
        });
      },
    );

    testWidgets('no edge-swipe gesture is installed on Android by default', (
      tester,
    ) async {
      await _runWithPlatform(TargetPlatform.android, () async {
        final controller = UiDualPaneController<String>();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_host(dualPane(controller)));
        await tester.tap(find.text('Open detail'));
        await tester.pumpAndSettle();

        await dragFromEdge(tester, fraction: 0.6);
        await tester.pumpAndSettle();

        // No gesture support on Android by default — the route is still
        // there; a real back-nav must come from the OS/back button, not
        // an app-level edge recognizer that would fight it.
        expect(find.text('detail:a'), findsOneWidget);
      });
    });

    testWidgets(
      'phoneEdgeSwipePop: true is a no-op on Android — the gesture only '
      'exists on iOS',
      (tester) async {
        await _runWithPlatform(TargetPlatform.android, () async {
          final controller = UiDualPaneController<String>();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            _host(
              UiDualPane<String>(
                controller: controller,
                phoneEdgeSwipePop: true,
                primaryBuilder: (context, selected, select) {
                  return UiButton(
                    label: 'Open detail',
                    onPressed: () => select('a'),
                  );
                },
                detailBuilder: (context, selected, select) =>
                    Text('detail:$selected'),
              ),
            ),
          );
          await tester.tap(find.text('Open detail'));
          await tester.pumpAndSettle();

          await dragFromEdge(tester, fraction: 0.6);
          await tester.pumpAndSettle();

          expect(find.text('detail:a'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      },
    );

    testWidgets('phoneEdgeSwipePop: false disables the gesture on iOS', (
      tester,
    ) async {
      await _runWithPlatform(TargetPlatform.iOS, () async {
        final controller = UiDualPaneController<String>();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            UiDualPane<String>(
              controller: controller,
              phoneEdgeSwipePop: false,
              primaryBuilder: (context, selected, select) {
                return UiButton(
                  label: 'Open detail',
                  onPressed: () => select('a'),
                );
              },
              detailBuilder: (context, selected, select) =>
                  Text('detail:$selected'),
            ),
          ),
        );
        await tester.tap(find.text('Open detail'));
        await tester.pumpAndSettle();

        await dragFromEdge(tester, fraction: 0.6);
        await tester.pumpAndSettle();

        expect(find.text('detail:a'), findsOneWidget);
      });
    });
  });
}
