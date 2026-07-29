import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../effects/ui_effects_tokens.dart';
import '../motion/ui_motion_tokens.dart';
import '../tokens/ui_color_tokens.dart';
import '../tokens/ui_radius_tokens.dart';
import '../tokens/ui_shadow_tokens.dart';
import '../tokens/ui_spacing_tokens.dart';
import '../tokens/ui_typography_tokens.dart';

/// Independently tracked parts of [UiThemeTokens].
enum UiThemeAspect {
  colors,
  spacing,
  radius,
  shadows,
  typography,
  motion,
  effects,
  brightness,
}

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
    this.effects = UiEffectsTokens.adaptive,
    this.brightness = Brightness.light,
  });

  final UiColorTokens colors;
  final UiSpacingTokens spacing;
  final UiRadiusTokens radius;
  final UiShadowTokens shadows;
  final UiTypographyTokens typography;
  final UiMotionTokens motion;
  final UiEffectsTokens effects;
  final Brightness brightness;

  static UiThemeTokens light = UiThemeTokens(
    colors: UiColorTokens.light,
    spacing: UiSpacingTokens.standard,
    radius: UiRadiusTokens.standard,
    shadows: UiShadowTokens.standard,
    typography: UiTypographyTokens.standard,
    motion: UiMotionTokens.defaults,
    effects: UiEffectsTokens.adaptive,
    brightness: Brightness.light,
  );

  static UiThemeTokens dark = UiThemeTokens(
    colors: UiColorTokens.dark,
    spacing: UiSpacingTokens.standard,
    radius: UiRadiusTokens.standard,
    shadows: UiShadowTokens.standard,
    typography: UiTypographyTokens.standard,
    motion: UiMotionTokens.defaults,
    effects: UiEffectsTokens.adaptive,
    brightness: Brightness.dark,
  );

  /// Resolve the Open UI Kit tokens attached to the ambient theme.
  /// Falls back to [light] if not present.
  static UiThemeTokens of(BuildContext context) {
    final tokens = UiTheme.maybeOf(context) ??
        Theme.of(context).extension<UiThemeTokens>() ??
        light;
    return _respectMotionPreferences(context, tokens);
  }

  /// Non-throwing lookup.
  static UiThemeTokens? maybeOf(BuildContext context) {
    final tokens = UiTheme.maybeOf(context) ??
        Theme.of(context).extension<UiThemeTokens>();
    if (tokens == null) return null;
    return _respectMotionPreferences(context, tokens);
  }

  /// Resolves only color tokens and rebuilds when colors change.
  static UiColorTokens colorsOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.colors).colors;

  /// Resolves only spacing tokens and rebuilds when spacing changes.
  static UiSpacingTokens spacingOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.spacing).spacing;

  /// Resolves only radius tokens and rebuilds when radii change.
  static UiRadiusTokens radiusOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.radius).radius;

  /// Resolves only shadow tokens and rebuilds when shadows change.
  static UiShadowTokens shadowsOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.shadows).shadows;

  /// Resolves only typography tokens and rebuilds when typography changes.
  static UiTypographyTokens typographyOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.typography).typography;

  /// Resolves motion tokens and only the accessibility preference they use.
  static UiMotionTokens motionOf(BuildContext context) {
    final motion = _ofAspect(context, UiThemeAspect.motion).motion;
    return (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
        ? motion.reduce()
        : motion;
  }

  /// Resolves effects and only the accessibility preferences they use.
  static UiEffectsTokens effectsOf(BuildContext context) {
    final effects = _ofAspect(context, UiThemeAspect.effects).effects;
    return effects.resolve(
      platform: defaultTargetPlatform,
      disableAnimations: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      accessibleNavigation:
          MediaQuery.maybeAccessibleNavigationOf(context) ?? false,
    );
  }

  /// Resolves only brightness and rebuilds when brightness changes.
  static Brightness brightnessOf(BuildContext context) =>
      _ofAspect(context, UiThemeAspect.brightness).brightness;

  static UiThemeTokens _ofAspect(
    BuildContext context,
    UiThemeAspect aspect,
  ) {
    return UiTheme.maybeOf(context, aspect: aspect) ??
        Theme.of(context).extension<UiThemeTokens>() ??
        light;
  }

  static UiThemeTokens _respectMotionPreferences(
    BuildContext context,
    UiThemeTokens tokens,
  ) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    return tokens.copyWith(
      motion: disableAnimations ? tokens.motion.reduce() : tokens.motion,
      effects: tokens.effects.resolve(
        platform: defaultTargetPlatform,
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
      ),
    );
  }

  @override
  UiThemeTokens copyWith({
    UiColorTokens? colors,
    UiSpacingTokens? spacing,
    UiRadiusTokens? radius,
    UiShadowTokens? shadows,
    UiTypographyTokens? typography,
    UiMotionTokens? motion,
    UiEffectsTokens? effects,
    Brightness? brightness,
  }) {
    return UiThemeTokens(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      shadows: shadows ?? this.shadows,
      typography: typography ?? this.typography,
      motion: motion ?? this.motion,
      effects: effects ?? this.effects,
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
      effects: UiEffectsTokens.lerp(effects, other.effects, t),
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
class UiTheme extends InheritedModel<UiThemeAspect> {
  const UiTheme({super.key, required this.tokens, required super.child});

  final UiThemeTokens tokens;

  static UiThemeTokens? maybeOf(
    BuildContext context, {
    UiThemeAspect? aspect,
  }) {
    return InheritedModel.inheritFrom<UiTheme>(
      context,
      aspect: aspect,
    )?.tokens;
  }

  @override
  bool updateShouldNotify(UiTheme oldWidget) => tokens != oldWidget.tokens;

  @override
  bool updateShouldNotifyDependent(
    UiTheme oldWidget,
    Set<UiThemeAspect> dependencies,
  ) {
    final old = oldWidget.tokens;
    return dependencies.any(
      (aspect) => switch (aspect) {
        UiThemeAspect.colors => tokens.colors != old.colors,
        UiThemeAspect.spacing => tokens.spacing != old.spacing,
        UiThemeAspect.radius => tokens.radius != old.radius,
        UiThemeAspect.shadows => tokens.shadows != old.shadows,
        UiThemeAspect.typography => tokens.typography != old.typography,
        UiThemeAspect.motion => tokens.motion != old.motion,
        UiThemeAspect.effects => tokens.effects != old.effects,
        UiThemeAspect.brightness => tokens.brightness != old.brightness,
      },
    );
  }
}
