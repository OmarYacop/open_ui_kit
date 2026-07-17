import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: child),
  );
}

// Helper that mounts a persistent sheet whose body is a tall scrollable
// list. `listController` is exposed so tests can inspect / drive the
// scroll position deterministically. The host is a 600pt tall column so
// snap fractions map to predictable pixel heights.
class _SheetHarness extends StatelessWidget {
  const _SheetHarness({
    required this.sheetController,
    required this.listController,
  });

  final UiPersistentSheetController sheetController;
  final ScrollController listController;
  static const List<UiSheetSnap> snaps = [
    UiSheetSnap.fraction(0.3),
    UiSheetSnap.fraction(0.9),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Colors.grey.shade200),
          ),
          Positioned.fill(
            child: UiPersistentSheet(
              controller: sheetController,
              snaps: snaps,
              child: UiSheet(
                child: ListView.builder(
                  controller: listController,
                  // ClampingScrollPhysics reports the full past-boundary
                  // pixel delta as an OverscrollNotification, so the
                  // PR-5 arbitration path gets the raw drag delta
                  // (BouncingScrollPhysics would exponentially damp the
                  // overscroll and make the test threshold-dependent).
                  // AlwaysScrollableScrollPhysics lets the list react
                  // to drag even when its extent is smaller than the
                  // viewport.
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: 40,
                  itemBuilder: (_, i) => SizedBox(
                    key: ValueKey('row-$i'),
                    height: 60,
                    child: Text('row-$i'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('UiPersistentSheet inner-scroll arbitration (PR-5)', () {
    testWidgets(
        'list not at an extent: drag scrolls the inner list, sheet snap '
        'index is unchanged', (tester) async {
      final sheetController =
          UiPersistentSheetController(initialIndex: 1); // max snap
      addTearDown(sheetController.dispose);
      final listController = ScrollController();
      addTearDown(listController.dispose);

      await tester.pumpWidget(
        _host(
          _SheetHarness(
            sheetController: sheetController,
            listController: listController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll the list to the middle so we are not at an extent.
      listController.jumpTo(200);
      await tester.pump();
      expect(listController.offset, 200);
      expect(sheetController.snapIndex, 1);

      // Drag up 80pt inside the list — the list should scroll
      // further; the sheet should stay pinned at its max snap.
      final listRect = tester.getRect(find.byType(ListView));
      final start = Offset(listRect.center.dx, listRect.center.dy);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -10));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Sheet is still at max snap.
      expect(sheetController.snapIndex, 1);
      // List scrolled forward (offset increased beyond the 200 jump).
      expect(listController.offset, greaterThan(200));
    });

    testWidgets(
        'at top + downward drag → overscroll handoff collapses the sheet',
        (tester) async {
      final sheetController =
          UiPersistentSheetController(initialIndex: 1); // max snap
      addTearDown(sheetController.dispose);
      final listController = ScrollController();
      addTearDown(listController.dispose);

      // Count overscroll notifications as they bubble through the
      // tree so a failure points at the right layer — arena (list
      // didn't hand off), arbitration (sheet didn't react), or snap
      // (drive moved but the snap index didn't commit).
      var overscrollCount = 0;

      await tester.pumpWidget(
        _host(
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is OverscrollNotification) overscrollCount++;
              return false;
            },
            child: _SheetHarness(
              sheetController: sheetController,
              listController: listController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(listController.offset, 0,
          reason: 'list starts at top of scroll extent');
      expect(sheetController.snapIndex, 1);

      // Drag DOWN on the list at its top. The list can't scroll
      // (already at min extent), so ClampingScrollPhysics emits
      // OverscrollNotifications with the raw past-boundary delta,
      // which the sheet absorbs and translates into a drive
      // adjustment.
      final listRect = tester.getRect(find.byType(ListView));
      final start = Offset(listRect.center.dx, listRect.top + 20);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(overscrollCount, greaterThan(0),
          reason: 'drag down at top MUST produce overscroll notifications — '
              'if 0, the list physics are absorbing the drag silently');
      // Sheet collapsed to the smaller snap (index 0).
      expect(sheetController.snapIndex, 0,
          reason: 'overscroll-down at top should collapse to the first snap');
      // List did NOT drift forward — its offset is still at or near 0.
      expect(listController.offset, lessThanOrEqualTo(1.0));
    });

    testWidgets(
        'at bottom + upward drag does NOT collapse the sheet below its '
        'current snap', (tester) async {
      final sheetController =
          UiPersistentSheetController(initialIndex: 1); // max snap
      addTearDown(sheetController.dispose);
      final listController = ScrollController();
      addTearDown(listController.dispose);

      await tester.pumpWidget(
        _host(
          _SheetHarness(
            sheetController: sheetController,
            listController: listController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Jump to the bottom of the list.
      listController.jumpTo(listController.position.maxScrollExtent);
      await tester.pump();
      expect(
        listController.offset,
        closeTo(listController.position.maxScrollExtent, 0.5),
      );

      // Drag UP at the bottom → the list can't scroll forward (already
      // at max extent). Overscroll in the forward direction maps to
      // "expand sheet"; since sheet is already at max snap, it stays.
      final listRect = tester.getRect(find.byType(ListView));
      final start =
          Offset(listRect.center.dx, listRect.bottom - 20);
      final gesture = await tester.startGesture(start);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Sheet still at max snap — the upward overscroll at the bottom
      // does not push the sheet below its current snap.
      expect(sheetController.snapIndex, 1);
    });

    testWidgets(
        'controller-driven snapTo from outside the scroll path still works',
        (tester) async {
      // Regression guard — PR-5 adds a scroll listener that touches
      // `_anim.value` directly. This test proves the controller →
      // animation channel is still wired up after the change.
      final sheetController =
          UiPersistentSheetController(initialIndex: 0);
      addTearDown(sheetController.dispose);
      final listController = ScrollController();
      addTearDown(listController.dispose);

      await tester.pumpWidget(
        _host(
          _SheetHarness(
            sheetController: sheetController,
            listController: listController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialHeight =
          tester.getRect(find.byKey(persistentSheetSurfaceKey)).height;

      sheetController.expand();
      await tester.pumpAndSettle();

      final expandedHeight =
          tester.getRect(find.byKey(persistentSheetSurfaceKey)).height;
      expect(expandedHeight, greaterThan(initialHeight));
      expect(sheetController.snapIndex, 1);
    });
  });
}
