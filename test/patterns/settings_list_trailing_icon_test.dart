import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Bare icons must adapt to the theme: custom trailing widgets in settings
/// rows inherit a themed icon color, and `UiApp` supplies an app-wide
/// `IconTheme` so icons outside kit slots never fall back to opaque black.
void main() {
  testWidgets('custom trailing icon in a settings row is themed', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        lightTokens: UiThemeTokens.dark,
        darkTokens: UiThemeTokens.dark,
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        home: UiSettingsList(
          groups: [
            UiSettingsGroup(
              items: [
                UiSettingsItem(
                  id: 'english',
                  label: 'English',
                  trailing: const Icon(IconData(0x2713), key: Key('check')),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final iconContext = tester.element(find.byKey(const Key('check')));
    expect(
      IconTheme.of(iconContext).color,
      UiThemeTokens.dark.colors.textPrimary,
    );
  });

  testWidgets('UiApp themes bare icons with the token foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      UiApp(
        lightTokens: UiThemeTokens.dark,
        darkTokens: UiThemeTokens.dark,
        localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
        home: const Center(child: Icon(IconData(0x2192), key: Key('arrow'))),
      ),
    );
    await tester.pumpAndSettle();
    final iconContext = tester.element(find.byKey(const Key('arrow')));
    expect(
      IconTheme.of(iconContext).color,
      UiThemeTokens.dark.colors.textPrimary,
    );
  });
}
