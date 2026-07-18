import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void _usePhonePortrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('UiDrawerSide resolution (PR-2)', () {
    test('left / right are absolute in both directions', () {
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.left, TextDirection.ltr),
        isTrue,
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.left, TextDirection.rtl),
        isTrue,
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.right, TextDirection.ltr),
        isFalse,
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.right, TextDirection.rtl),
        isFalse,
      );
    });

    test('start / end follow Directionality', () {
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.start, TextDirection.ltr),
        isTrue,
        reason: 'start = left in LTR',
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.start, TextDirection.rtl),
        isFalse,
        reason: 'start = right in RTL',
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.end, TextDirection.ltr),
        isFalse,
        reason: 'end = right in LTR',
      );
      expect(
        UiDrawer.isLeftEdge(UiDrawerSide.end, TextDirection.rtl),
        isTrue,
        reason: 'end = left in RTL',
      );
    });
  });

  group('UiDrawerScope.show directional slide (PR-2)', () {
    Future<void> openDrawer(
      WidgetTester tester, {
      required UiDrawerSide side,
      required TextDirection dir,
    }) async {
      _usePhonePortrait(tester);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => UiButton(
              label: 'open',
              onPressed: () {
                UiDrawerScope.show<void>(
                  context,
                  side: side,
                  builder: (_) => const UiDrawer(
                    child: SizedBox(width: 200, child: Text('drawer-body')),
                  ),
                );
              },
            ),
          ),
          dir: dir,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('start-side drawer hugs the left edge in LTR', (tester) async {
      await openDrawer(
        tester,
        side: UiDrawerSide.start,
        dir: TextDirection.ltr,
      );
      final drawerBox = tester.getRect(find.text('drawer-body'));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        drawerBox.left,
        lessThan(screenWidth / 2),
        reason: 'LTR start-side drawer should hug the left edge',
      );
    });

    testWidgets('start-side drawer hugs the right edge in RTL', (tester) async {
      await openDrawer(
        tester,
        side: UiDrawerSide.start,
        dir: TextDirection.rtl,
      );
      final drawerBox = tester.getRect(find.text('drawer-body'));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        drawerBox.right,
        greaterThan(screenWidth / 2),
        reason: 'RTL start-side drawer should hug the right edge',
      );
    });

    testWidgets('absolute left-side drawer stays on the left even in RTL',
        (tester) async {
      await openDrawer(
        tester,
        side: UiDrawerSide.left,
        dir: TextDirection.rtl,
      );
      final drawerBox = tester.getRect(find.text('drawer-body'));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        drawerBox.left,
        lessThan(screenWidth / 2),
        reason: 'left-side drawer is absolute and must NOT flip under RTL',
      );
    });
  });
}
