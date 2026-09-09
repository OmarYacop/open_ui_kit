import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// A fluid page can be carried by a drag anywhere on it (media-viewer
/// style): past the threshold it flies back into its source, otherwise it
/// settles back. Scrollables keep scrolling; only an over-scroll past the
/// top carries the page.
void main() {
  Widget host({required Widget page}) => UiApp(
    home: Center(
      child: SizedBox(
        width: 160,
        height: 120,
        child: UiFluidOpenContainer(
          closedBuilder: (_, open) => UiButton(label: 'Card', onPressed: open),
          pageBuilder: (_) => page,
        ),
      ),
    ),
  );

  Rect destinationRect(WidgetTester tester) => tester
      .widget<UiFluidSurface>(
        find.byKey(const Key('ui_fluid_route_destination')),
      )
      .geometry
      .rect;

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  }

  testWidgets('a long drag carries the page and dismisses on release', (
    tester,
  ) async {
    await tester.pumpWidget(host(page: const Center(child: Text('Detail'))));
    await open(tester);
    final full = destinationRect(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Detail')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(12, 160));
    await tester.pump();
    final carried = destinationRect(tester);
    expect(carried.height, lessThan(full.height));
    expect(carried.center.dy, greaterThan(full.center.dy + 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
    expect(find.text('Card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short drag settles the page back in place', (tester) async {
    await tester.pumpWidget(host(page: const Center(child: Text('Detail'))));
    await open(tester);
    final full = destinationRect(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Detail')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(destinationRect(tester).height, lessThan(full.height));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
    expect(destinationRect(tester), full);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrollable content scrolls; over-scroll past the top dismisses',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          page: ListView(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            children: [
              const SizedBox(height: 40, child: Text('Detail')),
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('Row $i')),
            ],
          ),
        ),
      );
      await open(tester);
      final full = destinationRect(tester);

      // Scroll down into the list: an ordinary upward drag scrolls.
      await tester.drag(find.text('Row 3'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(destinationRect(tester), full);
      expect(find.text('Detail', skipOffstage: false), findsOneWidget);

      // Back at the top, pulling further carries the page and dismisses.
      controller.jumpTo(0);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Row 1')),
      );
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 240));
      await tester.pump();
      expect(destinationRect(tester).height, lessThan(full.height));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Row 1'), findsNothing);
      expect(find.text('Card'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a sideways drag carries the page too, even over a list', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        page: ListView(
          children: [
            const SizedBox(height: 40, child: Text('Detail')),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('Row $i')),
          ],
        ),
      ),
    );
    await open(tester);
    final full = destinationRect(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row 2')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(120, 30));
    await tester.pump();
    final carried = destinationRect(tester);
    expect(carried.width, lessThan(full.width));
    expect(carried.center.dx, greaterThan(full.center.dx + 80));
    expect(carried.center.dy, greaterThan(full.center.dy + 10));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Row 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release continues from the carried frame, never from rest', (
    tester,
  ) async {
    await tester.pumpWidget(host(page: const Center(child: Text('Detail'))));
    await open(tester);
    final full = destinationRect(tester);
    final source = tester.getRect(find.text('Card'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Detail')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    final released = destinationRect(tester);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final next = destinationRect(tester);
    // Smaller than the page, not far from the released frame, and heading
    // toward the source rather than snapping back to full screen.
    expect(next.height, lessThan(full.height * .8));
    expect((next.center - released.center).distance, lessThan(80));
    expect(
      (next.center - source.center).distance,
      lessThanOrEqualTo((released.center - source.center).distance + 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
