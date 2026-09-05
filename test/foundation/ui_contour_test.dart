import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

class _Vsync extends TestVSync {}

void main() {
  group('UiContourPhysics', () {
    test('deformation amplitude is clamped and peaks mid-transition', () {
      final physics = UiContourPhysics.control;
      final start = physics.deformationAmplitude(0);
      final mid = physics.deformationAmplitude(0.5);
      final end = physics.deformationAmplitude(1);
      expect(start, 0);
      expect(end, 0);
      expect(mid, greaterThan(0));
      expect(
        mid,
        lessThanOrEqualTo(physics.maxStretch + physics.maxCompression),
      );
    });

    test('none physics applies no deformation and no overshoot', () {
      expect(UiContourPhysics.none.maxStretch, 0);
      expect(UiContourPhysics.none.deformationAmplitude(0.5), 0);
    });

    testWidgets('resolve collapses to none under reduced motion', (
      tester,
    ) async {
      late UiContourPhysics resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                resolved = UiContourPhysics.resolve(
                  context,
                  UiContourPhysics.control,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(resolved, UiContourPhysics.none);
    });

    testWidgets('resolve keeps the preset under standard motion', (
      tester,
    ) async {
      late UiContourPhysics resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = UiContourPhysics.resolve(
                context,
                UiContourPhysics.control,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, UiContourPhysics.control);
    });
  });

  group('UiContourController', () {
    late _Vsync vsync;

    setUp(() {
      vsync = _Vsync();
    });

    testWidgets(
      'open/close reach settled endpoints without resetting mid-flight',
      (tester) async {
        final controller = UiContourController(
          vsync: vsync,
          physics: UiContourPhysics.chrome,
        );
        addTearDown(controller.dispose);

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(controller.phase, UiContourPhase.collapsed);
        expect(controller.value, 0);

        controller.open(ctx);
        expect(controller.phase, UiContourPhase.opening);
        await tester.pumpAndSettle();
        expect(controller.phase, UiContourPhase.expanded);
        expect(controller.value, 1);
        expect(controller.isSettled, isTrue);

        controller.close(ctx);
        expect(controller.phase, UiContourPhase.closing);
        await tester.pumpAndSettle();
        expect(controller.phase, UiContourPhase.collapsed);
        expect(controller.value, 0);
        expect(controller.isSettled, isTrue);
      },
    );

    testWidgets(
      'regression: geometry does not reach near-full value within the first '
      'quarter of the duration (no snap-then-idle)',
      (tester) async {
        final controller = UiContourController(vsync: vsync);
        addTearDown(controller.dispose);

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        const duration = Duration(milliseconds: 200);
        controller.open(ctx, duration: const UiMotionDuration.custom(duration));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        // The previous physics curve reached ~1.0 by ~30ms of a 200ms
        // duration. A restrained curve should still be well short of
        // fully settled at 15% elapsed.
        expect(controller.value, lessThan(0.6));

        await tester.pump(const Duration(milliseconds: 70));
        // By the midpoint the transition should be clearly progressing,
        // not already flat.
        expect(controller.value, greaterThan(0.3));
        expect(controller.value, lessThan(1));

        await tester.pumpAndSettle();
        expect(controller.value, 1);
      },
    );

    testWidgets(
      'reversal mid-flight continues from the current value, not from an endpoint',
      (tester) async {
        final controller = UiContourController(
          vsync: vsync,
          physics: UiContourPhysics.chrome,
        );
        addTearDown(controller.dispose);

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        controller.open(
          ctx,
          duration: const UiMotionDuration.custom(Duration(milliseconds: 200)),
        );
        // The tick that starts a ticker establishes its baseline (elapsed 0);
        // a zero-duration warm-up pump consumes that baseline tick so the
        // following timed pump reports real elapsed progress.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final midValue = controller.value;
        expect(midValue, greaterThan(0));
        expect(midValue, lessThan(1));

        controller.close(
          ctx,
          duration: const UiMotionDuration.custom(Duration(milliseconds: 200)),
        );
        expect(controller.phase, UiContourPhase.reversing);
        // One frame later the value must have moved from midValue, not
        // jumped back to 1 (no reset-then-reverse).
        await tester.pump();
        expect(controller.value, lessThanOrEqualTo(midValue + 0.001));

        await tester.pump(const Duration(milliseconds: 30));
        expect(controller.value, lessThan(midValue));

        await tester.pumpAndSettle();
        expect(controller.phase, UiContourPhase.collapsed);
        expect(controller.value, 0);
      },
    );

    testWidgets('rapid re-trigger does not corrupt state', (tester) async {
      final controller = UiContourController(
        vsync: vsync,
        physics: UiContourPhysics.control,
      );
      addTearDown(controller.dispose);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        controller.open(ctx);
        await tester.pump(const Duration(milliseconds: 8));
        controller.close(ctx);
        await tester.pump(const Duration(milliseconds: 8));
      }
      await tester.pumpAndSettle();
      expect(controller.phase, UiContourPhase.collapsed);
      expect(controller.value, 0);
    });

    testWidgets(
      'markSourceUnavailable jumps to collapsed without stale geometry',
      (tester) async {
        final controller = UiContourController(
          vsync: vsync,
          physics: UiContourPhysics.control,
        );
        addTearDown(controller.dispose);

        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        controller.open(ctx);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(controller.value, greaterThan(0));

        controller.markSourceUnavailable();
        expect(controller.value, 0);
        expect(controller.phase, UiContourPhase.sourceUnavailable);
      },
    );

    testWidgets(
      'reduced motion settles immediately without waiting for elapsed time',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  ctx = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        final controller = UiContourController(
          vsync: vsync,
          physics: UiContourPhysics.resolve(ctx, UiContourPhysics.control),
        );
        addTearDown(controller.dispose);

        controller.open(ctx);
        // A single pump (no elapsed duration) must be enough because reduced
        // motion collapses duration to zero.
        await tester.pump();
        expect(controller.value, 1);
        expect(controller.phase, UiContourPhase.expanded);
      },
    );

    test('dispose is safe to call twice and use-after-dispose asserts', () {
      final controller = UiContourController(
        vsync: vsync,
        physics: UiContourPhysics.control,
      );
      controller.dispose();
      expect(controller.dispose, returnsNormally);
      expect(controller.isDisposed, isTrue);
    });
  });
}
