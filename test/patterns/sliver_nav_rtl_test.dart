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

void main() {
  group('UiSliverNavigationBar _ShrinkingTitle RTL (PR-2)', () {
    // Large-title mode renders the shrinking hero title via
    // `PositionedDirectional` so the title block stays anchored to the
    // reading-start edge in LTR and RTL.
    Future<void> pumpHero(
      WidgetTester tester, {
      required TextDirection dir,
    }) async {
      const spec = UiNavigationSpec(title: 'Library');
      await tester.pumpWidget(
        _host(
          CustomScrollView(
            slivers: const [
              UiSliverNavigationBar(spec: spec),
              SliverToBoxAdapter(child: SizedBox(height: 800)),
            ],
          ),
          dir: dir,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('title anchors to the left edge in LTR', (tester) async {
      await pumpHero(tester, dir: TextDirection.ltr);
      final titleBox = tester.getRect(find.text('Library').first);
      final headerBox = tester.getRect(find.byType(CustomScrollView));
      // Title's left edge is near the leading padding (spacing.x4 = 16),
      // far less than the header centre.
      expect(titleBox.left, lessThan(headerBox.center.dx));
    });

    testWidgets('title anchors to the right edge in RTL', (tester) async {
      await pumpHero(tester, dir: TextDirection.rtl);
      final titleBox = tester.getRect(find.text('Library').first);
      final headerBox = tester.getRect(find.byType(CustomScrollView));
      // In RTL the hero title's *start* is the right edge. The
      // right-most pixel of the title block should sit close to the
      // header's right edge, well past the centre.
      expect(titleBox.right, greaterThan(headerBox.center.dx));
    });
  });
}
