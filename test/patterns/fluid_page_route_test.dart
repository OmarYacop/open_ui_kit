import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart' as foundation;
import 'package:open_ui_kit/open_ui_kit.dart';
import 'package:open_ui_kit/patterns/navigation.dart' as navigation;

Widget _app(Widget home, {bool reduceMotion = false}) => UiApp(
  home: reduceMotion
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: home,
          ),
        )
      : home,
);

Opacity _closedOpacity(WidgetTester tester) => tester.widget<Opacity>(
  find
      .descendant(
        of: find.byType(UiFluidOpenContainer),
        matching: find.byType(Opacity),
      )
      .first,
);

void main() {
  group('UiFluidRouteMotion', () {
    test('sampled rect stays inside the viewport with a positive size', () {
      const motion = UiFluidRouteMotion();
      const viewport = Rect.fromLTWH(0, 0, 390, 844);
      const destination = UiFluidGeometry(viewport, 0);
      const sources = [
        Rect.fromLTWH(20, 100, 160, 200),
        Rect.fromLTWH(300, 800, 80, 40),
        Rect.fromLTWH(-30, -20, 100, 60),
        Rect.fromLTWH(0, 0, 390, 844),
        Rect.fromLTWH(380, 400, 200, 1),
        Rect.fromLTWH(195, 422, 1, 1),
      ];
      for (final source in sources) {
        for (final monotonic in const [false, true]) {
          for (var step = 0; step <= 100; step++) {
            final frame = motion.sample(
              source: UiFluidGeometry(source, 0),
              destination: destination,
              progress: step / 100,
              monotonic: monotonic,
              bounds: viewport,
            );
            final rect = frame.geometry.rect;
            final reason = '$source monotonic=$monotonic step=$step';
            expect(rect.isFinite, isTrue, reason: reason);
            expect(rect.width, greaterThan(0), reason: reason);
            expect(rect.height, greaterThan(0), reason: reason);
            expect(rect.left, greaterThanOrEqualTo(0), reason: reason);
            expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
            expect(rect.right, lessThanOrEqualTo(390), reason: reason);
            expect(rect.bottom, lessThanOrEqualTo(844), reason: reason);
            expect(frame.sourceOpacity, inInclusiveRange(0, 1), reason: reason);
            expect(
              frame.destinationOpacity,
              inInclusiveRange(0, 1),
              reason: reason,
            );
          }
          final end = motion.sample(
            source: UiFluidGeometry(source, 0),
            destination: destination,
            progress: 1,
            monotonic: monotonic,
            bounds: viewport,
          );
          expect(end.geometry.rect, viewport);
          expect(end.destinationOpacity, 1);
        }
      }
    });

    test('closing lands exactly on the source and ramps the scrim early', () {
      const motion = UiFluidRouteMotion();
      const source = Rect.fromLTWH(40, 500, 120, 80);
      final start = motion.sample(
        source: const UiFluidGeometry(source, 0),
        destination: const UiFluidGeometry(Rect.fromLTWH(0, 0, 390, 844), 0),
        progress: 0,
        monotonic: true,
      );
      expect(start.geometry.rect, source);
      expect(start.sourceOpacity, 1);
      expect(start.destinationOpacity, 0);
      expect(motion.scrimOpacity(0), 0);
      expect(motion.scrimOpacity(.2), 1);
      expect(motion.scrimOpacity(.1), closeTo(.5, .001));
    });
  });

  group('UiFluidOpenContainer', () {
    Widget container() => Center(
      child: SizedBox(
        width: 160,
        height: 120,
        child: UiFluidOpenContainer(
          closedBuilder: (context, open) =>
              UiButton(label: 'Card', onPressed: open),
          pageBuilder: (context) => Center(
            child: UiButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );

    testWidgets('closed embedded content retains its themed card surface', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        final tokens = dark ? UiThemeTokens.dark : UiThemeTokens.light;
        await tester.pumpWidget(
          UiApp(
            mode: dark ? UiThemeMode.dark : UiThemeMode.light,
            home: container(),
          ),
        );
        await tester.pumpAndSettle();
        final box = tester.widget<UiBox>(
          find
              .descendant(
                of: find.byType(UiFluidOpenContainer),
                matching: find.byType(UiBox),
              )
              .first,
        );
        expect(box.background, tokens.colors.surface);
        expect(box.border, Border.all(color: tokens.colors.border));
        expect(box.boxShadow, tokens.shadows.sm);
        expect(box.borderRadius, tokens.radius.xlAll);
        expect(box.clipBehavior, Clip.antiAlias);
      }
    });

    testWidgets('pushes, hides the closed child while open and restores it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(container()));
      await tester.tap(find.text('Card'));
      await tester.pump();
      expect(_closedOpacity(tester).opacity, 0);
      await tester.pump(const Duration(milliseconds: 40));
      // The in-flight copy is the only visible source instance; it hands
      // off to the page content during the gather (first ~17%).
      expect(find.byKey(const Key('ui_fluid_route_source')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
      expect(find.byKey(const Key('ui_fluid_route_source')), findsNothing);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
      expect(_closedOpacity(tester).opacity, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion snaps straight to the open page', (
      tester,
    ) async {
      await tester.pumpWidget(_app(container(), reduceMotion: true));
      await tester.tap(find.text('Card'));
      await tester.pump();
      final destination = tester.widget<UiFluidSurface>(
        find.byKey(const Key('ui_fluid_route_destination')),
      );
      final size = tester.getSize(find.byType(Navigator));
      expect(destination.geometry.rect, Offset.zero & size);
      expect(destination.opacity, 1);
      expect(find.text('Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('pushUiFluidPage', () {
    testWidgets('grows from the keyed source and pops cleanly', (tester) async {
      final sourceKey = GlobalKey();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: UiButton(
                key: sourceKey,
                label: 'Open',
                onPressed: () => context.pushUiFluidPage<void>(
                  (_) => const Center(child: Text('Detail')),
                  sourceKey: sourceKey,
                ),
              ),
            ),
          ),
        ),
      );
      final sourceRect = tester.getRect(find.byKey(sourceKey));
      await tester.tap(find.text('Open'));
      // Route overlay entries appear one frame after the push in this shell.
      await tester.pump();
      await tester.pump();
      final surface = tester.widget<UiFluidSurface>(
        find.byKey(const Key('ui_fluid_route_destination')),
      );
      expect(surface.geometry.rect.center.dx, closeTo(sourceRect.center.dx, 1));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('UiOpenContainer fluidZoom', () {
    testWidgets('flies with the fluid plate and returns without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Center(
            child: SizedBox(
              width: 160,
              height: 120,
              child: UiOpenContainer(
                style: UiContainerTransformStyle.fluidZoom,
                closedBuilder: (context, open) =>
                    const Center(child: Text('Tile')),
                pageBuilder: (context) => Center(
                  child: UiButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const Key('ui_fluid_zoom_plate')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const Key('ui_fluid_zoom_plate')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
      expect(find.text('Tile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('fluid route APIs are exported from the focused barrels', () {
    expect(const foundation.UiFluidRouteMotion().scrimRamp, .2);
    expect(
      navigation.UiFluidPageRoute.defaultTransitionDuration,
      const Duration(milliseconds: 612),
    );
  });
}
