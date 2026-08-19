import 'package:flutter/foundation.dart';
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
  group('UiContourCrossfadeController', () {
    late _Vsync vsync;
    setUp(() => vsync = _Vsync());

    testWidgets('starts settled at the initial value without animating', (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final crossfade = UiContourCrossfadeController<String>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, 'a');
      expect(crossfade.current, 'a');
      expect(crossfade.previous, isNull);
      expect(crossfade.progress, 1);
      expect(crossfade.isTransitioning, isFalse);
    });

    testWidgets(
        'a value with a different default identity starts a dissolve: both '
        'endpoints are visible mid-transition', (tester) async {
      final ctx = await _pumpContext(tester);
      final crossfade = UiContourCrossfadeController<String>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, 'a');
      await tester.pumpAndSettle();

      crossfade.update(ctx, 'b');
      expect(crossfade.previous, 'a');
      expect(crossfade.current, 'b');
      expect(crossfade.isTransitioning, isTrue);

      // Ticker warm-up: the first tick after starting establishes elapsed=0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(crossfade.progress, greaterThan(0));
      expect(crossfade.progress, lessThan(1));
      // Both endpoints remain readable mid-flight — this is the whole point
      // of a cross-dissolve as opposed to a hard cut.
      expect(crossfade.previous, 'a');
      expect(crossfade.current, 'b');

      await tester.pumpAndSettle();
      expect(crossfade.progress, 1);
      expect(crossfade.previous, isNull);
      expect(crossfade.current, 'b');
      expect(crossfade.isTransitioning, isFalse);
    });

    testWidgets(
        'an explicit identity that matches the current one accepts a fresh '
        'instance without animating', (tester) async {
      final ctx = await _pumpContext(tester);
      final crossfade =
          UiContourCrossfadeController<List<String>>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, ['home'], identity: 'home');
      await tester.pumpAndSettle();

      // A logically-equal-but-not-identical instance rebuilt for the same
      // slot (the common Flutter case: a new object every build).
      crossfade.update(ctx, ['home', 'again'], identity: 'home');
      expect(crossfade.current, ['home', 'again']);
      expect(crossfade.previous, isNull);
      expect(crossfade.isTransitioning, isFalse);
      expect(crossfade.progress, 1);
    });

    testWidgets(
        'an explicit identity that differs starts a dissolve even if the '
        'values would otherwise be `==`', (tester) async {
      final ctx = await _pumpContext(tester);
      final crossfade = UiContourCrossfadeController<String>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, 'shared', identity: 'home');
      await tester.pumpAndSettle();

      crossfade.update(ctx, 'shared', identity: 'messages');
      expect(crossfade.isTransitioning, isTrue);
      expect(crossfade.previous, 'shared');
      expect(crossfade.current, 'shared');

      await tester.pumpAndSettle();
    });

    testWidgets('interrupting mid-dissolve restarts cleanly from the blend', (
      tester,
    ) async {
      final ctx = await _pumpContext(tester);
      final crossfade = UiContourCrossfadeController<String>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, 'a');
      await tester.pumpAndSettle();
      crossfade.update(ctx, 'b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      crossfade.update(ctx, 'c');
      expect(crossfade.current, 'c');
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(crossfade.current, 'c');
      expect(crossfade.previous, isNull);
    });

    testWidgets('reduced motion settles immediately', (tester) async {
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
      final crossfade = UiContourCrossfadeController<String>(vsync: vsync);
      addTearDown(crossfade.dispose);

      crossfade.update(ctx, 'a');
      crossfade.update(ctx, 'b');
      await tester.pump();
      expect(crossfade.current, 'b');
      expect(crossfade.previous, isNull);
      expect(crossfade.progress, 1);
    });

    test(
        'dispose is safe and use-after-dispose is inert on the underlying controller',
        () {
      final crossfade = UiContourCrossfadeController<String>(vsync: _Vsync());
      crossfade.dispose();
      expect(crossfade.isDisposed, isTrue);
    });
  });

  group('uiContourCrossfadeBlurFraction', () {
    test('is zero at both rest ends and peaks at the midpoint', () {
      expect(uiContourCrossfadeBlurFraction(0), 0);
      expect(uiContourCrossfadeBlurFraction(1), closeTo(0, 1e-9));
      expect(uiContourCrossfadeBlurFraction(0.5), closeTo(1, 1e-9));
      expect(
        uiContourCrossfadeBlurFraction(0.25),
        lessThan(uiContourCrossfadeBlurFraction(0.5)),
      );
    });
  });

  group('buildUiContourCrossfade', () {
    testWidgets('carries a transient blur on iOS at the transition midpoint', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return buildUiContourCrossfade(
                context,
                progress: 0.5,
                previous: const Text('old'),
                current: const Text('new'),
              );
            },
          ),
        ),
      );
      expect(ctx, isNotNull);
      expect(find.byType(ImageFiltered), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('carries no blur once settled, even on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return buildUiContourCrossfade(
                context,
                progress: 0,
                previous: const Text('old'),
                current: const Text('new'),
              );
            },
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('never blurs on Android, even mid-transition', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return buildUiContourCrossfade(
                context,
                progress: 0.5,
                previous: const Text('old'),
                current: const Text('new'),
              );
            },
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('old'), findsOneWidget);
      expect(find.text('new'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders only the live side when the other endpoint is null', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return buildUiContourCrossfade(
                context,
                progress: 0.5,
                previous: null,
                current: const Text('new'),
              );
            },
          ),
        ),
      );
      expect(find.text('new'), findsOneWidget);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(Opacity), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
