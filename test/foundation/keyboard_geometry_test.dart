import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart';
import 'package:open_ui_kit/patterns/layout.dart';

void main() {
  test('keyboard geometry reserves the larger animation endpoint', () {
    const showing = UiKeyboardGeometry(
      currentInset: 120,
      sourceInset: 0,
      targetInset: 300,
      progress: 0.4,
      isAnimating: true,
      isVisible: true,
    );
    const hiding = UiKeyboardGeometry(
      currentInset: 120,
      sourceInset: 300,
      targetInset: 0,
      progress: 0.6,
      isAnimating: true,
      isVisible: true,
    );

    expect(showing.reservedInset, 300);
    expect(showing.followerTranslation, 180);
    expect(hiding.reservedInset, 300);
    expect(hiding.followerTranslation, 180);
  });

  testWidgets('keyboard dock tracks current inset without relaying out child',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> pump(UiKeyboardGeometry geometry) {
      return tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UiKeyboardGeometryOverride(
            geometry: geometry,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: UiKeyboardDock(
                child: SizedBox(
                  key: const Key('composer'),
                  width: 390,
                  height: 56,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pump(
      const UiKeyboardGeometry(
        currentInset: 120,
        sourceInset: 0,
        targetInset: 300,
        isAnimating: true,
        isVisible: true,
      ),
    );
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 580);

    await pump(
      const UiKeyboardGeometry(
        currentInset: 240,
        sourceInset: 0,
        targetInset: 300,
        isAnimating: true,
        isVisible: true,
      ),
    );
    expect(tester.getBottomLeft(find.byKey(const Key('composer'))).dy, 460);
    expect(tester.getSize(find.byKey(const Key('composer'))).height, 56);
  });

  testWidgets('keyboard replacement holds composer while the IME retreats',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UiKeyboardGeometryOverride(
          geometry: const UiKeyboardGeometry(
            currentInset: 120,
            sourceInset: 300,
            targetInset: 0,
            isAnimating: true,
            isVisible: true,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: UiKeyboardDock(
              replacementVisible: true,
              replacementExtent: 300,
              replacement: const SizedBox(key: Key('replacement')),
              child: const SizedBox(
                key: Key('replacement-composer'),
                width: 390,
                height: 56,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getBottomLeft(find.byKey(const Key('replacement-composer'))).dy,
      400,
    );
    expect(tester.getSize(find.byKey(const Key('replacement'))).height, 300);
  });

  testWidgets('keyboard replacement is clipped during its height transition',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget dock(bool visible) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: UiKeyboardDock(
              replacementVisible: visible,
              replacementExtent: 300,
              replacement: const SizedBox(
                key: Key('transitioning-replacement'),
                height: 300,
              ),
              child: const SizedBox(width: 390, height: 56),
            ),
          ),
        );

    await tester.pumpWidget(dock(false));
    await tester.pumpWidget(dock(true));
    await tester.pump(const Duration(milliseconds: 80));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('transitioning-replacement'))).height,
      300,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard geometry accessors rebuild only for their aspect',
      (tester) async {
    final geometry = ValueNotifier<UiKeyboardGeometry>(
      const UiKeyboardGeometry(
        currentInset: 120,
        sourceInset: 0,
        targetInset: 300,
        progress: 0.4,
        isAnimating: true,
        isVisible: true,
      ),
    );
    var currentInsetBuilds = 0;
    var reservedInsetBuilds = 0;
    var visibilityBuilds = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<UiKeyboardGeometry>(
        valueListenable: geometry,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Builder(
              builder: (context) {
                UiKeyboardGeometry.currentInsetOf(context);
                currentInsetBuilds++;
                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) {
                UiKeyboardGeometry.reservedInsetOf(context);
                reservedInsetBuilds++;
                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) {
                UiKeyboardGeometry.isVisibleOf(context);
                visibilityBuilds++;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        builder: (context, value, child) {
          return UiKeyboardGeometryOverride(
            geometry: value,
            child: child!,
          );
        },
      ),
    );

    geometry.value = const UiKeyboardGeometry(
      currentInset: 240,
      sourceInset: 0,
      targetInset: 300,
      progress: 0.8,
      isAnimating: true,
      isVisible: true,
    );
    await tester.pump();

    expect(currentInsetBuilds, 2);
    expect(reservedInsetBuilds, 1);
    expect(visibilityBuilds, 1);
  });

  testWidgets('page body inset accessors rebuild only for their edge',
      (tester) async {
    final insets = ValueNotifier<EdgeInsets>(
      const EdgeInsets.fromLTRB(1, 2, 3, 4),
    );
    var topBuilds = 0;
    var bottomBuilds = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<EdgeInsets>(
        valueListenable: insets,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Builder(
              builder: (context) {
                UiPageBodyInsets.topOf(context);
                topBuilds++;
                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) {
                UiPageBodyInsets.bottomOf(context);
                bottomBuilds++;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        builder: (context, value, child) {
          return UiPageBodyInsets(insets: value, child: child!);
        },
      ),
    );

    insets.value = const EdgeInsets.fromLTRB(1, 8, 3, 4);
    await tester.pump();

    expect(topBuilds, 2);
    expect(bottomBuilds, 1);
  });

  testWidgets('page and keyboard dock consume the keyboard exactly once',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UiKeyboardGeometryOverride(
          geometry: const UiKeyboardGeometry(
            currentInset: 300,
            sourceInset: 300,
            targetInset: 300,
            isVisible: true,
          ),
          child: UiPageScaffold(
            scrollFade: false,
            safeViewportMode: UiSafeViewportMode.top,
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                UiKeyboardDock(
                  child: SizedBox(
                    key: const Key('page-composer'),
                    height: 56,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getBottomLeft(find.byKey(const Key('page-composer'))).dy,
      400,
    );
  });

  testWidgets('page can resize its body to the visible keyboard viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UiKeyboardGeometryOverride(
          geometry: const UiKeyboardGeometry(
            currentInset: 300,
            sourceInset: 300,
            targetInset: 300,
            isVisible: true,
          ),
          child: UiPageScaffold(
            scrollFade: false,
            safeViewportMode: UiSafeViewportMode.none,
            resizeBodyForKeyboard: true,
            body: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                key: const Key('keyboard-resized-page-body'),
                height: constraints.maxHeight,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const Key('keyboard-resized-page-body')))
          .height,
      400,
    );
  });

  testWidgets('iOS reduced motion settles immediately at the target inset',
      (tester) async {
    final events = StreamController<dynamic>();
    addTearDown(events.close);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UiKeyboardGeometryScope(
          eventStream: events.stream,
          reduceMotionOverride: true,
          child: const _GeometryProbe(),
        ),
      ),
    );
    events.add({
      'platform': 'ios',
      'currentInset': 0,
      'sourceInset': 0,
      'targetInset': 300,
      'progress': 0,
      'durationMs': 250,
      'curve': 'easeInOut',
      'isAnimating': true,
      'isVisible': true,
    });
    await tester.pumpAndSettle();

    expect(find.text('300.0:false'), findsOneWidget);
  });
}

class _GeometryProbe extends StatelessWidget {
  const _GeometryProbe();

  @override
  Widget build(BuildContext context) {
    final geometry = UiKeyboardGeometry.of(context);
    return Text('${geometry.currentInset}:${geometry.isAnimating}');
  }
}
