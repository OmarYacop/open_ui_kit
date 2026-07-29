import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart';
import 'package:open_ui_kit/patterns/navigation.dart';

void main() {
  test('iOS zoom source radius follows compact geometry and clamps', () {
    final phoneTile = UiContainerTransformGeometry.iosSourceBorderRadius(
      const Size(170, 202),
    );
    final wideTile = UiContainerTransformGeometry.iosSourceBorderRadius(
      const Size(300, 356),
    );

    expect(phoneTile.topLeft.x, closeTo(61.2, 0.001));
    expect(wideTile.topLeft.x, 72);
  });

  test('center-pull path leads scale symmetrically in both directions', () {
    final opening = UiContainerTransformGeometry.centerPullProgress(0.25);
    final closing = UiContainerTransformGeometry.centerPullProgress(0.75);

    expect(opening, greaterThan(0.25));
    expect(closing, lessThan(0.75));
    expect(opening, closeTo(1 - closing, 0.0001));
    expect(UiContainerTransformGeometry.centerPullProgress(0), 0);
    expect(UiContainerTransformGeometry.centerPullProgress(1), 1);
  });

  testWidgets('iOS zoom infers the screen radius from safe-area geometry', (
    tester,
  ) async {
    late BorderRadius resolved;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewPadding: EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: Builder(
          builder: (context) {
            resolved =
                UiContainerTransformGeometry.iosScreenBorderRadius(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved.topLeft.x, closeTo(55.46, 0.01));
  });

  testWidgets(
      'content occlusion supports tokens and reduced-motion custom timing', (
    tester,
  ) async {
    late UiContentOcclusionSpec tokenSpec;
    late UiContentOcclusionSpec reducedCustomSpec;

    await tester.pumpWidget(
      UiApp(
        home: Builder(
          builder: (context) {
            tokenSpec = UiContentOcclusionSpec.resolve(
              context,
              switchTime: UiMotionSpeed.standard,
              duration: UiMotionSpeed.faster,
            );
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reducedCustomSpec = UiContentOcclusionSpec.custom(
                    context,
                    switchTime: const Duration(milliseconds: 175),
                    duration: const Duration(milliseconds: 65),
                  );
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(tokenSpec.switchTime, UiMotionTokens.defaults.standard);
    expect(tokenSpec.duration, UiMotionTokens.defaults.faster);
    expect(reducedCustomSpec.switchTime, Duration.zero);
    expect(reducedCustomSpec.duration, Duration.zero);
  });

  testWidgets('container transform expands and reverses with safe semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 64,
              child: UiOpenContainer(
                sourceBorderRadius: BorderRadius.circular(20),
                closedBuilder: (_, open) => GestureDetector(
                  onTap: open,
                  child: const ColoredBox(
                    color: Color(0xffeeeeee),
                    child: Center(child: Text('Open details')),
                  ),
                ),
                flightBuilder: (_) => const ColoredBox(
                  color: Color(0xffeeeeee),
                  child: Center(child: Text('Open details')),
                ),
                pageBuilder: (_) => const ColoredBox(
                  color: Color(0xffffffff),
                  child: Center(child: Text('Details page')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceRect = tester.getRect(find.text('Open details').first);
    await tester.tap(find.text('Open details').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final surface = find.byKey(
      const Key('ui_container_transform_surface'),
    );
    expect(surface, findsOneWidget);
    final middleRect = tester.getRect(surface);
    expect(middleRect.width, greaterThan(sourceRect.width));
    expect(middleRect.width, lessThan(800));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text('Details page'), findsOneWidget);

    Navigator.of(tester.element(find.text('Details page'))).pop();
    await tester.pump(const Duration(milliseconds: 80));
    expect(surface, findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Open details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('container transform honors reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiThemeData.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: UiOpenContainer(
            closedBuilder: (_, open) => GestureDetector(
              onTap: open,
              child: const Text('Open'),
            ),
            pageBuilder: (_) => const Text('Destination'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.text('Destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive iOS backdrop uses a cheap tint in reduced effects', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        lightTokens: UiThemeTokens.light.copyWith(
          effects: UiEffectsTokens.reduced,
        ),
        home: Center(
          child: SizedBox(
            width: 120,
            height: 160,
            child: UiOpenContainer(
              style: UiContainerTransformStyle.iosZoom,
              closedBuilder: (_, __) => const ColoredBox(
                color: Color(0xffeeeeee),
                child: Center(child: Text('Open tint')),
              ),
              pageBuilder: (_) => const ColoredBox(
                color: Color(0xffffffff),
                child: Center(child: Text('Tint destination')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open tint'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('ui_container_backdrop_tint')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ui_container_backdrop_tint')), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'iOS zoom keeps one transformed window and reverses without a flash',
    (tester) async {
      final totalDuration = UiMotionTokens.defaults.slow;
      final contentSwitchTime = UiMotionTokens.defaults.standard;
      const contentDuration = Duration(milliseconds: 80);
      const preContentGap = Duration(milliseconds: 80);

      await tester.pumpWidget(
        UiApp(
          lightTokens: UiThemeTokens.light.copyWith(
            effects: UiEffectsTokens.full,
          ),
          home: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              width: 140,
              height: 180,
              child: UiOpenContainer(
                style: UiContainerTransformStyle.iosZoom,
                sourceFlightLayout: UiContainerSourceFlightLayout.responsive,
                surfaceColor: const Color(0xffeeeeee),
                destinationSurfaceColor: const Color(0xffffffff),
                contentOcclusion: UiContentOcclusionSpec(
                  switchTime: contentSwitchTime,
                  duration: contentDuration,
                  peakOpacity: 0.9,
                ),
                closedBuilder: (_, __) => const ColoredBox(
                  color: Color(0xffeeeeee),
                  child: Center(child: Text('Open zoom')),
                ),
                pageBuilder: (_) => const ColoredBox(
                  color: Color(0xffffffff),
                  child: Center(child: Text('Zoom destination')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open zoom').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final plate = find.byKey(const Key('ui_ios_zoom_plate'));
      final plateDecoration = tester.widget<DecoratedBox>(plate);
      final plateRadius = (plateDecoration.decoration as BoxDecoration)
          .borderRadius! as BorderRadius;
      expect(plateRadius.topLeft.x, greaterThan(40));
      expect(
        tester.getSize(
          find.byKey(const Key('ui_ios_zoom_destination_content')),
        ),
        const Size(800, 600),
      );
      expect(
        tester.getSize(find.byKey(const Key('ui_ios_zoom_source_content'))),
        tester.getSize(find.byKey(const Key('ui_container_transform_surface'))),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('ui_container_transform_surface')),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 79));

      final surface = find.byKey(
        const Key('ui_container_transform_surface'),
      );
      expect(surface, findsOneWidget);
      expect(find.byType(Hero), findsNWidgets(2));
      expect(find.byType(UiContainerTransformTransition), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
      final forwardSourceOpacity = tester.widget<Opacity>(
        find.byKey(const Key('ui_ios_zoom_source_opacity')),
      );
      final forwardDestinationOpacity = tester.widget<Opacity>(
        find.byKey(const Key('ui_ios_zoom_destination_opacity')),
      );
      expect(forwardSourceOpacity.opacity, 1);
      expect(forwardDestinationOpacity.opacity, 0);
      expect(
        find.byKey(const Key('ui_ios_zoom_content_cover')),
        findsNothing,
      );
      final middleRect = tester.getRect(
        find.byKey(const Key('ui_ios_zoom_shadow')),
      );
      expect(middleRect.width, greaterThan(140));
      expect(middleRect.width, lessThan(800));
      expect(
        tester.getSize(find.byKey(const Key('ui_ios_zoom_source_content'))),
        middleRect.size,
      );
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 120));
      final switchingDestinationOpacity = tester.widget<Opacity>(
        find.byKey(const Key('ui_ios_zoom_destination_opacity')),
      );
      expect(
        find.byKey(const Key('ui_ios_zoom_source_opacity')),
        findsNothing,
      );
      expect(switchingDestinationOpacity.opacity, 1);
      final forwardCover = tester.widget<Opacity>(
        find.byKey(const Key('ui_ios_zoom_content_cover')),
      );
      expect(forwardCover.opacity, 0.9);
      expect(
        (forwardCover.child! as ColoredBox).color,
        const Color(0xffffffff),
      );

      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const Key('ui_ios_zoom_source_opacity')),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const Key('ui_ios_zoom_destination_opacity')),
            )
            .opacity,
        1,
      );
      expect(
        find.byKey(const Key('ui_ios_zoom_content_cover')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const Key('ui_ios_zoom_shadow'))).width,
        lessThan(800),
      );

      await tester.pumpAndSettle();
      expect(find.text('Zoom destination'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        find.byKey(const Key('ui_container_backdrop_tint')),
        findsNothing,
      );

      Navigator.of(tester.element(find.text('Zoom destination'))).pop();
      await tester.pump();
      await tester.pump(
        totalDuration - contentSwitchTime - preContentGap,
      );
      expect(surface, findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        find.byKey(const Key('ui_ios_zoom_source_opacity')),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const Key('ui_ios_zoom_destination_opacity')),
            )
            .opacity,
        1,
      );

      await tester.pump(preContentGap);
      final reverseCover = tester.widget<Opacity>(
        find.byKey(const Key('ui_ios_zoom_content_cover')),
      );
      expect(reverseCover.opacity, 0.9);
      expect(
        (reverseCover.child! as ColoredBox).color,
        const Color(0xffeeeeee),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open zoom'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
