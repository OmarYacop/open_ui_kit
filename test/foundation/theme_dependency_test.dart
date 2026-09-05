import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/foundation.dart';

void main() {
  testWidgets('focused token accessors rebuild only for their token group', (
    tester,
  ) async {
    final tokens = ValueNotifier<UiThemeTokens>(UiThemeTokens.light);
    var colorBuilds = 0;
    var spacingBuilds = 0;

    await tester.pumpWidget(
      ValueListenableBuilder<UiThemeTokens>(
        valueListenable: tokens,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Builder(
              builder: (context) {
                UiThemeTokens.colorsOf(context);
                colorBuilds++;
                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) {
                UiThemeTokens.spacingOf(context);
                spacingBuilds++;
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        builder: (context, value, child) {
          return UiTheme(tokens: value, child: child!);
        },
      ),
    );

    expect(colorBuilds, 1);
    expect(spacingBuilds, 1);

    tokens.value = tokens.value.copyWith(
      spacing: tokens.value.spacing.copyWith(x1: 8),
    );
    await tester.pump();

    expect(colorBuilds, 1);
    expect(spacingBuilds, 2);

    tokens.value = tokens.value.copyWith(
      colors: tokens.value.colors.copyWith(primary: const Color(0xFF123456)),
    );
    await tester.pump();

    expect(colorBuilds, 2);
    expect(spacingBuilds, 2);
  });
}
