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
    // SizedBox.expand inside a Stack lays out to full parent size, so
    // the page has non-zero bounds (Container(color:) alone would be
    // unbounded inside AnimatedSwitcher's Stack and render invisibly).
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFFEFEFEF),
        child: Center(child: Text(label)),
      ),
    );
  }
}

Widget _host(Widget child, {TargetPlatform? platform}) {
  return MaterialApp(
    theme: UiThemeData.light().copyWith(
      platform: platform ?? TargetPlatform.iOS,
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  // Helper: override the platform for a single test. The var MUST be
  // cleared before the test body returns — the framework runs
  // `debugAssertAllFoundationVarsUnset` before our tearDown does, so
  // a classic `addTearDown` isn't early enough. Callers wrap the
  // test body in `runWith` to get the clear-on-exit semantics.
  Future<T> runWith<T>(
    TargetPlatform p,
    Future<T> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = p;
    try {
      return await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('UiNavigationHost edge-swipe pop (PR-E)', () {
    testWidgets(
        'horizontal drag from the left edge pops the stack on iOS-auto',
        (tester) async {
      await runWith(TargetPlatform.iOS, () async {
      final controller =
          UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);
      controller.push(_detail, args: 1);
      await tester.pump();

      await tester.pumpWidget(
        _host(UiNavigationHost(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('detail-1'), findsOneWidget);
      expect(controller.canPop, isTrue);

      // Drag from deep-inside the edge strip (edge-width default 22,
      // start at x=6) rightward far enough to pass the 64pt threshold.
      final hostRect =
          tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(
        hostRect.left + 6,
        hostRect.center.dy,
      );
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.canPop, isFalse);
      expect(find.text('home'), findsOneWidget);
      });
    });

    testWidgets(
        'no edge-swipe on platforms where it is not a native convention',
        (tester) async {
      await runWith(TargetPlatform.android, () async {
      final controller =
          UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);
      controller.push(_detail, args: 2);
      await tester.pump();

      await tester.pumpWidget(
        _host(
          UiNavigationHost(controller: controller),
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      final hostRect =
          tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(
        hostRect.left + 6,
        hostRect.center.dy,
      );
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Stack unchanged.
      expect(find.text('detail-2'), findsOneWidget);
      expect(controller.canPop, isTrue);
      });
    });

    testWidgets('edge-swipe is a no-op when the stack is at the root',
        (tester) async {
      await runWith(TargetPlatform.iOS, () async {
      final controller = UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(UiNavigationHost(controller: controller)),
      );
      await tester.pumpAndSettle();

      final hostRect = tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(hostRect.left + 6, hostRect.center.dy);
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Root is untouched; no crash.
      expect(find.text('home'), findsOneWidget);
      expect(controller.canPop, isFalse);
      });
    });

    testWidgets(
        'a tiny drag (distance below threshold, no velocity) does not pop',
        (tester) async {
      await runWith(TargetPlatform.iOS, () async {
      final controller =
          UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);
      controller.push(_detail, args: 3);
      await tester.pump();

      await tester.pumpWidget(
        _host(UiNavigationHost(controller: controller)),
      );
      await tester.pumpAndSettle();

      // 20pt total travel — below the 64pt distance threshold; the
      // slow step cadence keeps velocity under the 400 threshold too.
      final hostRect = tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(hostRect.left + 6, hostRect.center.dy);
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(4, 0));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('detail-3'), findsOneWidget);
      expect(controller.canPop, isTrue);
      });
    });

    testWidgets('enableEdgeSwipePop = false disables the gesture on iOS',
        (tester) async {
      await runWith(TargetPlatform.iOS, () async {
      final controller =
          UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);
      controller.push(_detail, args: 4);
      await tester.pump();

      await tester.pumpWidget(
        _host(
          UiNavigationHost(
            controller: controller,
            enableEdgeSwipePop: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hostRect = tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(hostRect.left + 6, hostRect.center.dy);
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('detail-4'), findsOneWidget);
      expect(controller.canPop, isTrue);
      });
    });

    testWidgets('enableEdgeSwipePop = true forces the gesture on Android',
        (tester) async {
      await runWith(TargetPlatform.android, () async {
      final controller =
          UiNavigationController(routes: [_home, _detail]);
      addTearDown(controller.dispose);
      controller.push(_detail, args: 5);
      await tester.pump();

      await tester.pumpWidget(
        _host(
          UiNavigationHost(
            controller: controller,
            enableEdgeSwipePop: true,
          ),
          platform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      final hostRect = tester.getRect(find.byType(UiNavigationHost));
      final startPoint = Offset(hostRect.left + 6, hostRect.center.dy);
      final gesture = await tester.startGesture(startPoint);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(16, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(controller.canPop, isFalse);
      });
    });
  });
}
