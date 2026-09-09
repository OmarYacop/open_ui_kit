import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  const source = UiFluidGeometry(Rect.fromLTWH(240, 20, 80, 48), 24);
  const destination = UiFluidGeometry(Rect.fromLTWH(20, 20, 300, 240), 28);
  UiFluidMorphFrame frame(double t) => UiFluidMorphFrame.sample(
    source: source,
    destination: destination,
    progress: t,
  );

  test('V13 endpoints, contraction and early clipped-content timing', () {
    expect(frame(0).geometry.rect, source.rect);
    expect(frame(.2).geometry.rect.width, closeTo(89.6, .001));
    expect(frame(.34).geometry.rect.width, closeTo(54.4, .001));
    expect(frame(.5).destinationOpacity, greaterThan(0));
    expect(frame(.5).geometry.rect.width, lessThan(300));
    expect(frame(1).geometry.rect, destination.rect);
    expect(frame(1).destinationOpacity, 1);
  });

  test('every edge and size uses the same spring including overshoot', () {
    final compact = frame(.34).geometry.rect;
    var overshoot = false;
    for (var i = 0; i <= 100; i++) {
      final q = i / 100;
      final p = uiFluidSpring(q);
      overshoot |= p > 1;
      expect(
        frame(.34 + .66 * q).geometry.rect,
        rectMoreOrLessEquals(Rect.lerp(compact, destination.rect, p)!),
      );
    }
    expect(overshoot, isTrue);
  });

  testWidgets('content stays laid out, hidden actions cannot be tapped', (
    tester,
  ) async {
    final controller = UiFluidController(vsync: tester);
    addTearDown(controller.dispose);
    var taps = 0;
    await tester.pumpWidget(
      UiApp(
        home: SizedBox(
          width: 360,
          height: 400,
          child: UiFluidMorph(
            controller: controller,
            sourceGeometry: source,
            destinationGeometry: destination,
            color: const Color(0xffeeeeee),
            source: const Text('Source'),
            destination: GestureDetector(
              onTap: () => taps++,
              child: const Text('Destination'),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.text('Destination')), destination.rect.size);
    controller.value = .34;
    await tester.pump();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
    controller.value = .6;
    await tester.pump();
    await tester.tap(find.text('Destination'));
    expect(taps, 1);
  });

  testWidgets('reversal preserves current frame and reduced motion jumps', (
    tester,
  ) async {
    final controller = UiFluidController(vsync: tester);
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      UiApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    controller.open(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final before = controller.value;
    controller.close(context);
    expect(controller.value, before);
    await tester.pumpAndSettle();
    expect(controller.value, 0);
    await tester.pumpWidget(
      UiApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    controller.open(context);
    expect(controller.value, 1);
    expect(controller.isAnimating, isFalse);
  });
  testWidgets(
    'closing removes expanded content before revealing source label',
    (tester) async {
      final controller = UiFluidController(vsync: tester, value: 1);
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        UiApp(
          home: Builder(
            builder: (c) {
              context = c;
              return SizedBox(
                width: 360,
                height: 400,
                child: UiFluidMorph(
                  controller: controller,
                  sourceGeometry: source,
                  destinationGeometry: destination,
                  color: const Color(0xffeeeeee),
                  source: const Text('More'),
                  destination: const Text('Expanded'),
                ),
              );
            },
          ),
        ),
      );
      controller.close(context);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        final surfaces = tester
            .widgetList<UiFluidSurface>(find.byType(UiFluidSurface))
            .toList();
        expect(
          surfaces[0].opacity > 0 && surfaces[1].opacity > 0,
          isFalse,
          reason: 'Source and destination text must not compete while closing',
        );
        if (i == 6) {
          expect(surfaces[1].opacity, 0);
          expect(surfaces[1].interactive, isFalse);
        }
      }
      await tester.pumpAndSettle();
    },
  );
}
