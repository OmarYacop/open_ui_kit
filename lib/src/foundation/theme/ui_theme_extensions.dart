import 'package:flutter/material.dart';

import '../motion/ui_motion_tokens.dart';
import '../tokens/ui_color_tokens.dart';
import '../tokens/ui_radius_tokens.dart';
import '../tokens/ui_shadow_tokens.dart';
import '../tokens/ui_spacing_tokens.dart';
import '../tokens/ui_typography_tokens.dart';

/// Aggregate ThemeExtension that exposes all Open UI Kit tokens.
///
/// Attach via `ThemeData.extensions` so any widget downstream can resolve
/// tokens with [UiThemeTokens.of].
@immutable
class UiThemeTokens extends ThemeExtension<UiThemeTokens> {
  const UiThemeTokens({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.shadows,
    required this.typography,
    required this.motion,
    this.brightness = Brightness.light,
  });

  final UiColorTokens colors;
  final UiSpacingTokens spacing;
  final UiRadiusTokens radius;
  final UiShadowTokens shadows;
  final UiTypographyTokens typography;
  final UiMotionTokens motion;
  final Brightness brightness;

  static UiThemeTokens light = UiThemeTokens(
    colors: UiColorTokens.light,
    spacing: UiSpacingTokens.standard,
    radius: UiRadiusTokens.standard,
    shadows: UiShadowTokens.standard,
    typography: UiTypographyTokens.standard,
    motion: UiMotionTokens.defaults,
    brightness: Brightness.light,
  );

  static UiThemeTokens dark = UiThemeTokens(
    colors: UiColorTokens.dark,
    spacing: UiSpacingTokens.standard,
    radius: UiRadiusTokens.standard,
    shadows: UiShadowTokens.standard,
    typography: UiTypographyTokens.standard,
    motion: UiMotionTokens.defaults,
    brightness: Brightness.dark,
  );

  /// Resolve the Open UI Kit tokens attached to the ambient theme.
  /// Falls back to [light] if not present.
  static UiThemeTokens of(BuildContext context) {
    return UiTheme.maybeOf(context) ??
        Theme.of(context).extension<UiThemeTokens>() ??
        light;
  }

  /// Non-throwing lookup.
  static UiThemeTokens? maybeOf(BuildContext context) {
    return UiTheme.maybeOf(context) ??
        Theme.of(context).extension<UiThemeTokens>();
  }

  @override
  UiThemeTokens copyWith({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
    Brightness? brightness,
  }) {
    return UiThemeTokens(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      shadows: shadows ?? this.shadows,
      typography: typography ?? this.typography,
      motion: motion ?? this.motion,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  UiThemeTokens lerp(ThemeExtension<UiThemeTokens>? other, double t) {
    if (other is! UiThemeTokens) return this;
    return UiThemeTokens(
      colors: UiColorTokens.lerp(colors, other.colors, t),
      spacing: UiSpacingTokens.lerp(spacing, other.spacing, t),
      radius: UiRadiusTokens.lerp(radius, other.radius, t),
      shadows: UiShadowTokens.lerp(shadows, other.shadows, t),
      typography: UiTypographyTokens.lerp(typography, other.typography, t),
      motion: UiMotionTokens.lerp(motion, other.motion, t),
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// Material-free [InheritedWidget] host for [UiThemeTokens].
///
/// Provided by [UiApp] so any widget can resolve design tokens without a
/// Material `Theme` ancestor. [UiThemeTokens.of] checks this first, then falls
/// back to a Material `Theme` extension for interop with `MaterialApp`-hosted
/// screens (e.g. widget tests).
class UiTheme extends InheritedWidget {
  const UiTheme({super.key, required this.tokens, required super.child});

  final UiThemeTokens tokens;

  static UiThemeTokens? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UiTheme>()?.tokens;
  }

  @override
  bool updateShouldNotify(UiTheme oldWidget) => tokens != oldWidget.tokens;
}
