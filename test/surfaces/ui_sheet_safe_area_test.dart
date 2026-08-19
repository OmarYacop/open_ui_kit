import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  // The sheet's own bottom corners are square, so it sits flush with the
  // screen edge — regression coverage for a bug where a caller's fixed
  // bottom padding was the only thing standing between its content and the
  // home indicator / gesture bar, clipping into the sheet's rounded corners.
  group('UiSheet bottom safe area', () {
    testWidgets(
      'body padding grows to at least the bottom safe inset when there is no footer',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: UiSheet(
                padding: EdgeInsets.all(8),
                child: Text('body', key: ValueKey('body')),
              ),
            ),
          ),
        );

        final bodyPadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('body')),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(bodyPadding.padding.resolve(TextDirection.ltr).bottom, 34);
      },
    );

    testWidgets(
      'caller bottom padding larger than the safe inset is preserved',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: UiSheet(
                padding: EdgeInsets.only(bottom: 60),
                child: Text('body', key: ValueKey('body')),
              ),
            ),
          ),
        );

        final bodyPadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('body')),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(bodyPadding.padding.resolve(TextDirection.ltr).bottom, 60);
      },
    );

    testWidgets(
      'a footer keeps its own padding untouched and gets a trailing safe-area spacer',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: UiSheet(
                padding: const EdgeInsets.all(8),
                footer: const SizedBox(
                  key: ValueKey('footer'),
                  height: 44,
                ),
                child: const Text('body', key: ValueKey('body')),
              ),
            ),
          ),
        );

        final bodyPadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('body')),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(bodyPadding.padding.resolve(TextDirection.ltr).bottom, 8);

        final sheetHeight = tester.getSize(find.byType(UiSheet)).height;
        final footerBottom = tester.getBottomLeft(
          find.byKey(const ValueKey('footer')),
        );
        final sheetBottom = tester.getBottomLeft(find.byType(UiSheet));
        expect(sheetBottom.dy - footerBottom.dy, greaterThanOrEqualTo(34));
        expect(sheetHeight, greaterThan(0));
      },
    );
  });
}
