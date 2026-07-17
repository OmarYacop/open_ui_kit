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
    theme: UiThemeData.light().copyWith(platform: TargetPlatform.iOS),
    home: Scaffold(body: child),
  );
}

Future<T> _runIOS<T>(Future<T> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

UiNavigationController _controllerWithDetail() {
  final c = UiNavigationController(routes: [_home, _detail]);
  c.push(_detail, args: 1);
  return c;
}

void main() {
  group('UiNavigationHost interactive edge-swipe (PR-4)', () {
    testWidgets(
        'progress notifier tracks the live drag (monotonic from 0→target)',
        (tester) async {
      await _runIOS(() async {
        final controller = _controllerWithDetail();
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        final readings = <double>[];
        progress.addListener(() => readings.add(progress.value));

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Live-drag halfway across the viewport (~300pt out of 800)
        // without releasing. Progress should rise monotonically.
        final hostRect = tester.getRect(find.byType(UiNavigationHost));
        final start = Offset(hostRect.left + 6, hostRect.center.dy);
        final gesture = await tester.startGesture(start);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(30, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }

        expect(readings, isNotEmpty,
            reason: 'drag updates should fire the progress notifier');
        expect(progress.value, greaterThan(0.2),
            reason: 'halfway through the viewport progress should be >0.2');
        expect(progress.value, lessThanOrEqualTo(1.0));
        // Monotonic during a one-way drag.
        for (var i = 1; i < readings.length; i++) {
          expect(readings[i], greaterThanOrEqualTo(readings[i - 1]));
        }

        // Release below the distance threshold would cancel; here we
        // already exceeded threshold, so release completes. Clean up.
        await gesture.up();
        await tester.pumpAndSettle();
      });
    });

    testWidgets(
        'release below threshold animates progress back to 0 and does NOT pop',
        (tester) async {
      await _runIOS(() async {
        final controller = _controllerWithDetail();
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

        final hostRect = tester.getRect(find.byType(UiNavigationHost));
        final start = Offset(hostRect.left + 6, hostRect.center.dy);
        final gesture = await tester.startGesture(start);
        // Small drag: 20pt total, below the 64pt distance threshold.
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(4, 0));
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(progress.value, greaterThan(0));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(progress.value, 0.0,
            reason: 'cancel returns progress to 0');
        expect(find.text('detail-1'), findsOneWidget,
            reason: 'stack untouched when the drag cancels');
        expect(controller.canPop, isTrue);
      });
    });

    testWidgets(
        'release past the distance threshold drives progress to 1 and pops',
        (tester) async {
      await _runIOS(() async {
        final controller = _controllerWithDetail();
        addTearDown(controller.dispose);
        final progress = ValueNotifier<double>(0);
        addTearDown(progress.dispose);

        double peak = 0;
        progress.addListener(() {
          if (progress.value > peak) peak = progress.value;
        });

        await tester.pumpWidget(
          _host(
            UiNavigationHost(
              controller: controller,
              edgeSwipeProgress: progress,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final hostRect = tester.getRect(find.byType(UiNavigationHost));
        final start = Offset(hostRect.left + 6, hostRect.center.dy);
        final gesture = await tester.startGesture(start);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(16, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(peak, closeTo(1.0, 0.02),
            reason: 'the complete-animation should drive progress to 1');
        expect(controller.canPop, isFalse,
            reason: 'stack popped after the interactive complete');
        expect(find.text('home'), findsOneWidget);
      });
    });

    testWidgets(
        'fast fling past both thresholds completes the pop', (tester) async {
      // VelocityTracker smoothing in the widget-test pointer stream
      // makes a pure "velocity-only" assertion flaky. This test
      // exercises the combined OR-threshold: a 120pt flick delivered
      // across 10 samples in 20ms both crosses the 64pt distance
      // threshold and exceeds the 400 pts/sec velocity threshold. It
      // verifies the completion path fires, not which branch caught
      // it.
      await _runIOS(() async {
        final controller = _controllerWithDetail();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(UiNavigationHost(controller: controller)),
        );
        await tester.pumpAndSettle();

        final hostRect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(hostRect.left + 6, hostRect.center.dy),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(12, 0));
          await tester.pump(const Duration(milliseconds: 2));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(controller.canPop, isFalse);
        expect(find.text('home'), findsOneWidget);
      });
    });

    testWidgets(
        'drag below threshold on root stack is a no-op (no progress, no pop)',
        (tester) async {
      await _runIOS(() async {
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

        final hostRect = tester.getRect(find.byType(UiNavigationHost));
        final gesture = await tester.startGesture(
          Offset(hostRect.left + 6, hostRect.center.dy),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(16, 0));
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(progress.value, 0.0,
            reason: 'no edge-swipe region installed at root, so progress stays at 0');
        expect(controller.canPop, isFalse);
        expect(find.text('home'), findsOneWidget);
      });
    });
  });
}
