import 'package:flutter/material.dart';

import '../motion/ui_motion_tokens.dart';
import '../tokens/ui_color_tokens.dart';
import '../tokens/ui_radius_tokens.dart';
import '../tokens/ui_shadow_tokens.dart';
import '../tokens/ui_spacing_tokens.dart';
import '../tokens/ui_typography_tokens.dart';
import 'ui_brand.dart';
import 'ui_theme_extensions.dart';

/// Helpers for building a [ThemeData] preloaded with [UiThemeTokens].
///
/// Consumers typically wire this into `MaterialApp.theme` / `darkTheme` so
/// the Open UI Kit widgets can read tokens via `UiThemeTokens.of(context)`.
class UiThemeData {
  UiThemeData._();

  /// Light theme with neutral Open UI Kit tokens.
  static ThemeData light({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
  }) {
    final tokens = UiThemeTokens(
      colors: colors ?? UiColorTokens.light,
      spacing: spacing ?? UiSpacingTokens.standard,
      radius: radius ?? UiRadiusTokens.standard,
      shadows: shadows ?? UiShadowTokens.standard,
      typography: typography ?? UiTypographyTokens.standard,
      motion: motion ?? UiMotionTokens.defaults,
      brightness: Brightness.light,
    );
    return _build(tokens);
  }

  /// Dark theme with neutral Open UI Kit tokens.
  static ThemeData dark({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
  }) {
    final tokens = UiThemeTokens(
      colors: colors ?? UiColorTokens.dark,
      spacing: spacing ?? UiSpacingTokens.standard,
      radius: radius ?? UiRadiusTokens.standard,
      shadows: shadows ?? UiShadowTokens.standard,
      typography: typography ?? UiTypographyTokens.standard,
      motion: motion ?? UiMotionTokens.defaults,
      brightness: Brightness.dark,
    );
    return _build(tokens);
  }

  /// Build a [ThemeData] from a [UiBrand] runtime config.
  ///
  /// Single bootstrap seam for branded apps — pass the brand in, get a
  /// themed app out. Callers should *not* branch on brand id anywhere
  /// below this call; plumb everything through [UiBrand] instead so
  /// leaf widgets stay brand-agnostic.
  static ThemeData fromBrand(
    UiBrand brand, {
    Brightness brightness = Brightness.light,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
  }) {
    final colors = brand.colorTokens(brightness);
    return brightness == Brightness.dark
        ? dark(
            colors: colors,
            spacing: spacing,
            radius: radius,
            shadows: shadows,
            typography: typography,
            motion: motion,
          )
        : light(
            colors: colors,
            spacing: spacing,
            radius: radius,
            shadows: shadows,
            typography: typography,
            motion: motion,
          );
  }

  /// Shorthand for resolving tokens from the nearest [Theme].
  static UiThemeTokens of(BuildContext context) => UiThemeTokens.of(context);

  static ThemeData _build(UiThemeTokens tokens) {
    final c = tokens.colors;
    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: ColorScheme(
        brightness: tokens.brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.secondary,
        onSecondary: c.onSecondary,
        error: c.danger,
        onError: c.onDanger,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}
