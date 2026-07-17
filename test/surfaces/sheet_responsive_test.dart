import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

// `UiSheetScope.show` pushes onto the root navigator, so the route's
// MediaQuery comes from the view. We override `tester.view` and reset
// it in `addTearDown` to keep each test hermetic.
void useViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('UiSheetScope.adaptiveMaxWidth (PR-3)', () {
    testWidgets('phone width → null (edge-to-edge)', (tester) async {
      useViewSize(tester, const Size(400, 800));
      double? observed;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (ctx) {
              observed = UiSheetScope.adaptiveMaxWidth(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(observed, isNull);
    });

    testWidgets('tablet width → 560', (tester) async {
      useViewSize(tester, const Size(720, 1024));
      double? observed;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (ctx) {
              observed = UiSheetScope.adaptiveMaxWidth(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(observed, 560);
    });

    testWidgets('desktop width → 720', (tester) async {
      useViewSize(tester, const Size(1200, 1024));
      double? observed;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (ctx) {
              observed = UiSheetScope.adaptiveMaxWidth(ctx);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(observed, 720);
    });
  });

  group('UiSheetScope.show maxWidth rendering (PR-3)', () {
    // The presented sheet is pushed on the root navigator by `show`;
    // to measure its bounds we find the presenter's UiSheet widget.
    Future<void> openSheet(
      WidgetTester tester, {
      required Size size,
      double? maxWidth,
    }) async {
      useViewSize(tester, size);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (ctx) => UiButton(
              label: 'open',
              onPressed: () {
                UiSheetScope.show<void>(
                  ctx,
                  snap: const UiSheetSnap.half(),
                  maxWidth: maxWidth,
                  builder: (_, controller) => const UiSheet(
                    child: SizedBox(
                      height: 200,
                      child: Text('sheet-content'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'maxWidth: null keeps the sheet edge-to-edge (legacy phone '
        'behaviour preserved)', (tester) async {
      await openSheet(
        tester,
        size: const Size(400, 800),
        maxWidth: null,
      );
      final sheetRect = tester.getRect(find.byType(UiSheet));
      expect(sheetRect.width, closeTo(400, 0.5));
    });

    testWidgets(
        'maxWidth: 560 on a tablet-size host caps and centers the sheet',
        (tester) async {
      await openSheet(
        tester,
        size: const Size(900, 1024),
        maxWidth: 560,
      );
      final sheetRect = tester.getRect(find.byType(UiSheet));
      expect(sheetRect.width, lessThanOrEqualTo(560.1));
      expect(sheetRect.center.dx, closeTo(450, 1));
    });

    testWidgets(
        'maxWidth wider than the viewport falls back to the viewport width',
        (tester) async {
      await openSheet(
        tester,
        size: const Size(400, 800),
        maxWidth: 2000,
      );
      final sheetRect = tester.getRect(find.byType(UiSheet));
      expect(sheetRect.width, lessThanOrEqualTo(400.1));
    });
  });
}
