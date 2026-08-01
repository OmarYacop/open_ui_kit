import 'package:flutter/widgets.dart';

import '../motion/ui_motion_tokens.dart';
import '../effects/ui_effects_tokens.dart';
import '../tokens/ui_color_tokens.dart';
import '../tokens/ui_radius_tokens.dart';
import '../tokens/ui_shadow_tokens.dart';
import '../tokens/ui_spacing_tokens.dart';
import '../tokens/ui_typography_tokens.dart';
import 'ui_brand.dart';
import 'ui_theme_extensions.dart';

/// Helpers for building framework-neutral [UiThemeTokens].
class UiThemeData {
  UiThemeData._();

  /// Light theme with neutral Open UI Kit tokens.
  static UiThemeTokens light({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
    UiEffectsTokens? effects,
  }) {
    return UiThemeTokens(
      colors: colors ?? UiColorTokens.light,
      spacing: spacing ?? UiSpacingTokens.standard,
      radius: radius ?? UiRadiusTokens.standard,
      shadows: shadows ?? UiShadowTokens.standard,
      typography: typography ?? UiTypographyTokens.standard,
      motion: motion ?? UiMotionTokens.defaults,
      effects: effects ?? UiEffectsTokens.adaptive,
      brightness: Brightness.light,
    );
  }

  /// Dark theme with neutral Open UI Kit tokens.
  static UiThemeTokens dark({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
    UiEffectsTokens? effects,
  }) {
    return UiThemeTokens(
      colors: colors ?? UiColorTokens.dark,
      spacing: spacing ?? UiSpacingTokens.standard,
      radius: radius ?? UiRadiusTokens.standard,
      shadows: shadows ?? UiShadowTokens.standard,
      typography: typography ?? UiTypographyTokens.standard,
      motion: motion ?? UiMotionTokens.defaults,
      effects: effects ?? UiEffectsTokens.adaptive,
      brightness: Brightness.dark,
    );
  }

  /// Build [UiThemeTokens] from a [UiBrand] runtime config.
  ///
  /// Single bootstrap seam for branded apps — pass the brand in, get a
  /// themed app out. Callers should *not* branch on brand id anywhere
  /// below this call; plumb everything through [UiBrand] instead so
  /// leaf widgets stay brand-agnostic.
  static UiThemeTokens fromBrand(
    UiBrand brand, {
    Brightness brightness = Brightness.light,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
    UiEffectsTokens? effects,
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
            effects: effects,
          )
        : light(
            colors: colors,
            spacing: spacing,
            radius: radius,
            shadows: shadows,
            typography: typography,
            motion: motion,
            effects: effects,
          );
  }

  /// Shorthand for resolving tokens from the nearest [UiTheme].
  static UiThemeTokens of(BuildContext context) => UiThemeTokens.of(context);
}
