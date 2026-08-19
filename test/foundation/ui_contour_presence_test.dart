import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

class _Vsync extends TestVSync {}

Future<BuildContext> _pumpContext(WidgetTester tester) async {
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
  return ctx;
}

void main() {
  group('UiContourPresenceController', () {
    late _Vsync vsync;
    setUp(() => vsync = _Vsync());

    testWidgets(
        'starts present without animating when constructed with a non-null initial value',
        (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, 'a');
      expect(presence.value, 'a');
      expect(presence.phase, UiContourPhase.expanded);
      expect(presence.progress, 1);
    });

    testWidgets('starts absent when constructed with a null initial value', (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, null);
      expect(presence.value, isNull);
      expect(presence.phase, UiContourPhase.collapsed);
    });

    testWidgets(
        'retains the last value while animating out, then clears once settled',
        (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, 'a');
      await tester.pump();

      presence.update(ctx, null);
      // Immediately after requesting removal, the value must still be the
      // last one — this is the whole point of the abstraction.
      expect(presence.value, 'a');
      expect(presence.phase, UiContourPhase.closing);

      await tester.pumpAndSettle();
      expect(presence.value, isNull);
      expect(presence.phase, UiContourPhase.collapsed);
    });

    testWidgets('progress animates smoothly (not a snap) across the removal', (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, 'a');
      await tester.pump();
      presence.update(ctx, null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(presence.progress, greaterThan(0));
      expect(presence.progress, lessThan(1));

      await tester.pumpAndSettle();
      expect(presence.progress, 0);
    });

    testWidgets(
        'a value appearing for the first time (was null, now non-null) animates in',
        (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, null);
      await tester.pump();

      presence.update(ctx, 'a');
      expect(presence.value, 'a');
      expect(presence.phase, UiContourPhase.opening);
      expect(presence.progress, lessThan(1));

      // The tick that starts a ticker establishes its baseline (elapsed 0);
      // a zero-duration warm-up pump consumes that baseline tick so the
      // following timed pump reports real elapsed progress.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(presence.progress, greaterThan(0));
      expect(presence.progress, lessThan(1));

      await tester.pumpAndSettle();
      expect(presence.progress, 1);
      expect(presence.value, 'a');
    });

    testWidgets(
        'switching directly from one non-null value to a different non-null value does not flicker null',
        (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, 'a');
      await tester.pumpAndSettle();

      presence.update(ctx, 'b');
      expect(presence.value, 'b');
      await tester.pump(const Duration(milliseconds: 16));
      expect(presence.value, 'b');
      await tester.pumpAndSettle();
      expect(presence.value, 'b');
      expect(presence.phase, UiContourPhase.expanded);
    });

    testWidgets(
        'onRemove transforms the retained value before it starts fading out', (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<List<String>>(
        vsync: vsync,
      );
      addTearDown(presence.dispose);

      presence.update(ctx, ['expanded']);
      await tester.pump();

      presence.update(ctx, null, onRemove: (v) => ['collapsed']);
      expect(presence.value, ['collapsed']);
      expect(presence.phase, UiContourPhase.closing);
      await tester.pumpAndSettle();
    });

    testWidgets('rapid toggling does not corrupt state', (tester) async {
      final ctx = await _pumpContext(tester);
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      for (var i = 0; i < 6; i++) {
        presence.update(ctx, i.isEven ? 'a' : null);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion settles immediately on removal', (
      tester,
    ) async {
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
      final presence = UiContourPresenceController<String>(vsync: vsync);
      addTearDown(presence.dispose);

      presence.update(ctx, 'a');
      presence.update(ctx, null);
      await tester.pump();
      expect(presence.value, isNull);
      expect(presence.progress, 0);
    });

    test(
        'dispose is safe and use-after-dispose is inert on the underlying controller',
        () {
      final presence = UiContourPresenceController<String>(vsync: _Vsync());
      presence.dispose();
      expect(presence.isDisposed, isTrue);
    });
  });
}
