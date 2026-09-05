import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  group('UiEffectsTokens', () {
    test('adaptive uses the Open UI effects budget on every platform', () {
      final effects = UiEffectsTokens.adaptive.resolve();
      final expectedLevel = switch (UiEffectsBuildConfig.effectsLevel) {
        'reduced' => UiEffectsLevel.reduced,
        _ => UiEffectsLevel.full,
      };
      final expectsBlur =
          expectedLevel == UiEffectsLevel.full &&
          UiEffectsBuildConfig.enableBackdropFilters;

      expect(effects.level, expectedLevel);
      expect(effects.allowsBackdropBlur, expectsBlur);
      expect(
        effects.scaleBlur(16),
        expectsBlur
            ? 16 * (UiEffectsBuildConfig.blurScalePercent.clamp(0, 100) / 100)
            : 0,
      );
      expect(effects.animateBlur, expectedLevel == UiEffectsLevel.full);
    });

    test('an explicit reduced budget wins', () {
      final effects = UiEffectsTokens.reduced.resolve();

      expect(effects.level, UiEffectsLevel.reduced);
      expect(effects.allowsBackdropBlur, isFalse);
    });

    test('a custom reduced budget can retain scaled static blur', () {
      const custom = UiEffectsTokens(
        level: UiEffectsLevel.reduced,
        enableBackdropBlur: true,
        blurScale: 0.25,
        animateBlur: false,
      );
      final effects = custom.resolve();
      final expectsBlur =
          UiEffectsBuildConfig.enableBackdropFilters &&
          UiEffectsBuildConfig.effectsLevel != 'reduced';

      expect(effects.level, UiEffectsLevel.reduced);
      expect(effects.allowsBackdropBlur, expectsBlur);
      expect(
        effects.scaleBlur(16),
        expectsBlur
            ? 4 * (UiEffectsBuildConfig.blurScalePercent.clamp(0, 100) / 100)
            : 0,
      );
      expect(effects.animateBlur, isFalse);
    });

    testWidgets('accessibility preferences reduce motion and effects', (
      tester,
    ) async {
      late UiThemeTokens resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: UiTheme(
            tokens: UiThemeData.light(effects: UiEffectsTokens.full),
            child: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                accessibleNavigation: true,
              ),
              child: Builder(
                builder: (context) {
                  resolved = UiThemeTokens.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(resolved.effects.level, UiEffectsLevel.reduced);
      expect(resolved.effects.allowsBackdropBlur, isFalse);
      expect(resolved.motion.standard, Duration.zero);
    });

    testWidgets('bottom tab blur follows the theme effects budget', (
      tester,
    ) async {
      Widget host(UiEffectsTokens effects) {
        return MaterialApp(
          home: UiTheme(
            tokens: UiThemeData.light(effects: effects),
            child: Scaffold(
              body: UiBottomTabBar(
                items: const [
                  UiBottomTabItem(label: 'Home', icon: Icon(Icons.home)),
                  UiBottomTabItem(label: 'Search', icon: Icon(Icons.search)),
                ],
                currentIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(UiEffectsTokens.reduced));
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(host(UiEffectsTokens.full));
      await tester.pumpAndSettle();
      expect(
        find.byType(BackdropFilter),
        UiEffectsBuildConfig.enableBackdropFilters
            ? findsOneWidget
            : findsNothing,
      );
    });
  });
}
