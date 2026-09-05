import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

Widget host(Widget child,
        {bool reduced = false, double width = 600, double scale = 1}) =>
    Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
            data: MediaQueryData(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(scale)),
            child: UiTheme(
                tokens: UiThemeTokens.light,
                child: DefaultTextStyle(
                    style: const TextStyle(fontSize: 14),
                    child: Center(
                        child: SizedBox(
                            width: width, height: 500, child: child))))));
void main() {
  testWidgets('page layout preserves a body with both panes at tablet width',
      (tester) async {
    await tester.pumpWidget(host(const UiPageLayout(
        filters: Text('Filters'),
        secondary: Text('Details'),
        body: SizedBox(key: ValueKey('body')))));
    final error = tester.takeException();
    final size = tester.getSize(find.byKey(const ValueKey('body')));
    expect(error, isNull);
    expect(size.width, greaterThanOrEqualTo(320));
  });
}
