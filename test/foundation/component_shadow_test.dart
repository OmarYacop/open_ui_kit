import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  testWidgets('UiComponentShadow resolves theme-aware defaults', (
    tester,
  ) async {
    await tester.pumpWidget(
      const UiApp(
        mode: UiThemeMode.dark,
        home: Center(
          child: UiComponentShadow(
            shape: BoxShape.circle,
            child: SizedBox.square(dimension: 20),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = decorated.decoration as BoxDecoration;
    final tokens = UiThemeTokens.dark;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.boxShadow, [
      BoxShadow(
        color: tokens.colors.background.withValues(alpha: 0.96),
        blurRadius: tokens.spacing.x3,
        spreadRadius: tokens.spacing.x1,
      ),
    ]);
  });
}
