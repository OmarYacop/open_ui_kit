import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  // Use a plain MaterialApp with no `locale` override + an explicit
  // Directionality wrapper. Going through the Arabic locale would
  // require the full GlobalMaterialLocalizations dependency which the
  // kit's tests deliberately avoid; the Directionality ancestor is
  // what every kit component actually reads, so this exercises the
  // same code path.
  return MaterialApp(
    theme: UiThemeData.light(),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('RTL layout — PR-F sanity checks', () {
    testWidgets(
        'pagination loading caption sits on the reading-end of the '
        'control row in both directions', (tester) async {
      Widget build(TextDirection dir) => _host(
            UiPagination(
              currentPage: 1,
              totalPages: 5,
              loading: true,
              onPageChanged: (_) {},
            ),
            dir: dir,
          );

      await tester.pumpWidget(build(TextDirection.ltr));
      await tester.pumpAndSettle();
      final ltrLoadingX = tester.getTopLeft(find.text('Loading…')).dx;
      final ltrFirstChipX = tester.getTopLeft(find.text('1')).dx;
      expect(
        ltrLoadingX,
        greaterThan(ltrFirstChipX),
        reason: 'LTR: loading caption should sit right of the first chip',
      );

      await tester.pumpWidget(build(TextDirection.rtl));
      await tester.pumpAndSettle();
      final rtlLoadingX = tester.getTopLeft(find.text('Loading…')).dx;
      final rtlFirstChipX = tester.getTopLeft(find.text('1')).dx;
      expect(
        rtlLoadingX,
        lessThan(rtlFirstChipX),
        reason: 'RTL: loading caption should sit left of the first chip '
            '(reading end is on the left)',
      );
    });
  });
}
