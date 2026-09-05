import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  for (final size in UiSize.values) {
    for (final variant in UiInputVariant.values) {
      testWidgets('$size $variant preserves compact sizing and scales text', (
        tester,
      ) async {
        Future<void> pump(double scale) => tester.pumpWidget(
          UiApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Center(
              child: SizedBox(
                width: 320,
                child: UiInput(size: size, variant: variant, hint: 'Name'),
              ),
            ),
          ),
        );
        await pump(1);
        final before = tester.getRect(find.byType(EditableText));
        final outer = tester.getRect(find.byType(UiInput));
        expect(outer.height, UiButtonMetrics.minHeight(size));
        final topInset = before.top - outer.top;
        final bottomInset = outer.bottom - before.bottom;
        await pump(2);
        final after = tester.getRect(find.byType(EditableText));
        final enlarged = tester.getRect(find.byType(UiInput));
        expect(enlarged.height, greaterThan(outer.height));
        if (variant == UiInputVariant.standard) {
          expect(after.top - enlarged.top, closeTo(topInset, .01));
          expect(enlarged.bottom - after.bottom, closeTo(bottomInset, .01));
        } else {
          expect(enlarged.height, after.height);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('trailing target does not receive extra text inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: UiInput(
              trailing: SizedBox(width: 44, height: 44),
              hint: 'Name',
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(UiInput)).height, 46);
  });
}
