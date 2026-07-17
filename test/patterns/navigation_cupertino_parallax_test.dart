import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

final _home = UiRouteSpec<void, void>(
  id: 'home',
  title: 'Home',
  builder: (_, __) => const _PageScaffold(label: 'home'),
);
final _detail = UiRouteSpec<dynamic, String>(
  id: 'detail',
  title: 'Detail',
  builder: (_, args) => _PageScaffold(label: 'detail-$args'),
);

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFFEFEFEF),
        child: Center(child: Text(label)),
      ),
    );
  }
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: child),
  );
}

Future<T> _runWith<T>(
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

UiNavigationController _controllerAtDetail() {
  final c = UiNavigationController(routes: [_home, _detail]);
  c.push(_detail, args: 1);
  return c;
}

/// Walk up from `leafFinder`'s element to the nearest ancestor
/// `Transform` widget with a non-zero horizontal translation. The
/// parallax paints the outgoing page inside one Transform and the
/// incoming page inside another, so this returns each route's live
/// x-offset without reaching into private state.
double _firstHorizontalTranslationAncestor(
  WidgetTester tester,
  Finder leafFinder,
) {
  final element = tester.element(leafFinder);
  double? found;
  element.visitAncestorElements((e) {
    final w = e.widget;
    if (w is Transform) {
      final m = w.transform;
      final x = m.getTranslation().x;
      if (x.abs() > 0.0001) {
        found = x;
        return false; // stop at first non-zero translate ancestor
      }
    }
    return true;
  });
  return found ?? 0.0;
}

void main() {
  group('Cupertino parallax back transition (PR-7)', () {
    testWidgets('gesture progress updates both `from` and `to` transforms',
        (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start a drag from the edge strip but don't release — stays
        // mid-gesture so both the outgoing and incoming pages remain
        // mounted inside the parallax stack.
        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(25, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Both labels are rendered inside the parallax stack.
        expect(find.text('detail-1'), findsOneWidget);
        expect(find.text('home'), findsOneWidget);

        final fromDx = _firstHorizontalTranslationAncestor(
          tester,
          find.text('detail-1'),
        );
        final toDx = _firstHorizontalTranslationAncestor(
          tester,
          find.text('home'),
        );

        // Outgoing route translates rightward; incoming route
        // starts offset leftward (negative) and moves toward 0.
        expect(fromDx, greaterThan(0),
            reason: 'outgoing page should translate rightward with progress');
        expect(toDx, lessThan(0),
            reason: 'incoming page starts at negative offset and '
                'approaches zero as progress grows');
        // Parallax ratio keeps the incoming page travelling slower
        // than the outgoing one — |toDx| < fromDx at the same
        // progress.
        expect(toDx.abs(), lessThan(fromDx.abs()));
        expect(progress.value, greaterThan(0));

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'cancel under threshold returns both pages to their pre-gesture '
        'positions', (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Small drag well under the 64pt distance threshold.
        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 3; i++) {
          await gesture.moveBy(const Offset(6, 0));
          await tester.pump(const Duration(milliseconds: 40));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        // Detail page still mounted (stack unchanged); progress fully
        // back to 0.
        expect(controller.canPop, isTrue);
        expect(find.text('detail-1'), findsOneWidget);
        expect(progress.value, 0.0);
      });
    });

    testWidgets(
        'complete past threshold pops the route and settles to the '
        'previous page', (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(16, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.canPop, isFalse,
            reason: 'threshold drag should commit the pop');
        expect(find.text('home'), findsOneWidget);
        expect(find.text('detail-1'), findsNothing);
        expect(progress.value, 0.0,
            reason: 'drive resets silently after the commit');
      });
    });

    testWidgets('root stack does not install the edge region (no-op swipe)',
        (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = UiNavigationController(routes: [_home, _detail]);
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(25, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(controller.canPop, isFalse);
        expect(progress.value, 0.0);
      });
    });
  });

  group('Cupertino parallax platform gating (PR-7)', () {
    testWidgets(
        'iOS: default auto resolution renders the previous page during drag',
        (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(UiNavigationHost(controller: controller)),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Both pages are mounted simultaneously during the drag —
        // signature of the Cupertino parallax branch.
        expect(find.text('home'), findsOneWidget);
        expect(find.text('detail-1'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'Android: default auto resolution does NOT render the previous '
        'page (slide only; Android keeps non-Cupertino behaviour)',
        (tester) async {
      await _runWith(TargetPlatform.android, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              // Auto on Android resolves to slide, but the base
              // swipe-pop is platform-gated off by default — force it
              // on to isolate the transition-style behaviour.
              enableEdgeSwipePop: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Slide-only: the previous page is NOT mounted beneath the
        // current one.
        expect(find.text('detail-1'), findsOneWidget);
        expect(find.text('home'), findsNothing);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'explicit `backSwipeTransition: cupertino` forces parallax on Android',
        (tester) async {
      await _runWith(TargetPlatform.android, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              enableEdgeSwipePop: true,
              backSwipeTransition: UiBackSwipeTransition.cupertino,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Forcing cupertino on Android mounts the previous page.
        expect(find.text('home'), findsOneWidget);
        expect(find.text('detail-1'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'outgoing page is painted on an opaque backdrop — pages that do '
        'not install their own background still read as a slide, not a '
        'cross-fade', (tester) async {
      // Regression guard for the "top page looks transparent during
      // swipe" bug. Builds the routes as RAW widget trees with no
      // background paint of their own. During the parallax the
      // outgoing page MUST still hide the incoming page completely
      // (except for the 30 % reveal strip).
      final bareHome = UiRouteSpec<void, void>(
        id: 'bare-home',
        title: 'Home',
        builder: (_, __) => const Center(child: Text('bare-home')),
      );
      final bareDetail = UiRouteSpec<dynamic, void>(
        id: 'bare-detail',
        title: 'Detail',
        builder: (_, __) => const Center(child: Text('bare-detail')),
      );

      await _runWith(TargetPlatform.iOS, () async {
        final controller =
            UiNavigationController(routes: [bareHome, bareDetail]);
        addTearDown(controller.dispose);
        controller.push(bareDetail);

        await tester.pumpWidget(
          _host(UiNavigationHost(controller: controller)),
        );
        await tester.pumpAndSettle();

        // Halfway through a drag.
        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(30, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Each route is wrapped with an opaque ColoredBox/DecoratedBox
        // painted with the theme's page-background colour. Count the
        // ancestor opaque wrappers — there should be exactly two
        // (one per route) when the parallax is active.
        final bg = UiColorTokens.light.background;

        bool hasOpaqueAncestor(Finder leaf) {
          final element = tester.element(leaf);
          var found = false;
          element.visitAncestorElements((e) {
            final w = e.widget;
            if (w is ColoredBox && w.color == bg) {
              found = true;
              return false;
            }
            if (w is DecoratedBox) {
              final d = w.decoration;
              if (d is BoxDecoration && d.color == bg) {
                found = true;
                return false;
              }
            }
            return true;
          });
          return found;
        }

        expect(hasOpaqueAncestor(find.text('bare-detail')), isTrue,
            reason: 'outgoing page must be wrapped in an opaque backdrop '
                'so it does not read as transparent during the swipe');
        expect(hasOpaqueAncestor(find.text('bare-home')), isTrue,
            reason: 'incoming page also renders on an opaque backdrop');

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'explicit `backSwipeTransition: slide` forces slide-only on iOS',
        (tester) async {
      await _runWith(TargetPlatform.iOS, () async {
        final controller = _controllerAtDetail();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              backSwipeTransition: UiBackSwipeTransition.slide,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(rect.left + 6, rect.center.dy),
        );
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        // Slide-only on iOS: previous page is NOT mounted underneath.
        expect(find.text('detail-1'), findsOneWidget);
        expect(find.text('home'), findsNothing);

        await gesture.up();
        await tester.pumpAndSettle();
      });
    });
  });
}
