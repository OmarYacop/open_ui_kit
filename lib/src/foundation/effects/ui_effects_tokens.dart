import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The visual-effects budget used by Open UI Kit components.
enum UiEffectsLevel {
  /// Use Open UI's balanced default budget.
  adaptive,

  /// Avoid continuous backdrop sampling and shorten effect animations.
  reduced,

  /// Enable the complete glass and visual-effects treatment.
  full,
}

/// Compile-time controls for excluding expensive visual effects.
///
/// Pass these values to `flutter run` or `flutter build`:
///
/// ```console
/// --dart-define=OPEN_UI_ENABLE_BACKDROP_FILTERS=false
/// --dart-define=OPEN_UI_EFFECTS_LEVEL=reduced
/// ```
abstract final class UiEffectsBuildConfig {
  static const bool enableBackdropFilters = bool.fromEnvironment(
    'OPEN_UI_ENABLE_BACKDROP_FILTERS',
    defaultValue: true,
  );

  static const String effectsLevel = String.fromEnvironment(
    'OPEN_UI_EFFECTS_LEVEL',
    defaultValue: 'adaptive',
  );

  static const int blurScalePercent = int.fromEnvironment(
    'OPEN_UI_BLUR_SCALE_PERCENT',
    defaultValue: 100,
  );
}

/// Tokenized limits for computationally expensive visual effects.
@immutable
class UiEffectsTokens {
  const UiEffectsTokens({
    this.level = UiEffectsLevel.adaptive,
    this.enableBackdropBlur = true,
    this.blurScale = 1,
    this.animateBlur = true,
  }) : assert(blurScale >= 0),
       assert(blurScale <= 1);

  static const adaptive = UiEffectsTokens();

  static const reduced = UiEffectsTokens(
    level: UiEffectsLevel.reduced,
    enableBackdropBlur: false,
    blurScale: 0.25,
    animateBlur: false,
  );

  static const full = UiEffectsTokens(level: UiEffectsLevel.full);

  final UiEffectsLevel level;
  final bool enableBackdropBlur;
  final double blurScale;
  final bool animateBlur;

  bool get allowsBackdropBlur =>
      UiEffectsBuildConfig.enableBackdropFilters && enableBackdropBlur;

  double scaleBlur(double requestedSigma) {
    if (!allowsBackdropBlur || requestedSigma <= 0) return 0;
    return requestedSigma * blurScale;
  }

  UiEffectsTokens resolve({
    bool disableAnimations = false,
    bool accessibleNavigation = false,
  }) {
    final hasCompileTimeLevel =
        UiEffectsBuildConfig.effectsLevel == 'full' ||
        UiEffectsBuildConfig.effectsLevel == 'reduced';
    final compileTimeLevel = switch (UiEffectsBuildConfig.effectsLevel) {
      'full' => UiEffectsLevel.full,
      'reduced' => UiEffectsLevel.reduced,
      _ => level,
    };
    final resolvedLevel = compileTimeLevel == UiEffectsLevel.adaptive
        ? UiEffectsLevel.full
        : compileTimeLevel;
    final platformDefaults = resolvedLevel == UiEffectsLevel.full
        ? full
        : reduced;
    final useResolvedLevelDefaults =
        hasCompileTimeLevel || level == UiEffectsLevel.adaptive;
    final resolvedEnableBackdropBlur =
        enableBackdropBlur &&
        (!useResolvedLevelDefaults || platformDefaults.enableBackdropBlur);
    final resolvedBlurScale = useResolvedLevelDefaults
        ? blurScale * platformDefaults.blurScale
        : blurScale;
    final resolvedAnimateBlur =
        animateBlur &&
        (!useResolvedLevelDefaults || platformDefaults.animateBlur);
    final accessibilityRequiresReducedEffects =
        disableAnimations || accessibleNavigation;
    final buildBlurScale =
        (UiEffectsBuildConfig.blurScalePercent.clamp(0, 100)) / 100;

    return UiEffectsTokens(
      level: accessibilityRequiresReducedEffects
          ? UiEffectsLevel.reduced
          : resolvedLevel,
      enableBackdropBlur:
          !accessibilityRequiresReducedEffects && resolvedEnableBackdropBlur,
      blurScale: accessibilityRequiresReducedEffects
          ? 0
          : resolvedBlurScale * buildBlurScale,
      animateBlur: !accessibilityRequiresReducedEffects && resolvedAnimateBlur,
    );
  }

  UiEffectsTokens copyWith({
    UiEffectsLevel? level,
    bool? enableBackdropBlur,
    double? blurScale,
    bool? animateBlur,
  }) {
    return UiEffectsTokens(
      level: level ?? this.level,
      enableBackdropBlur: enableBackdropBlur ?? this.enableBackdropBlur,
      blurScale: blurScale ?? this.blurScale,
      animateBlur: animateBlur ?? this.animateBlur,
    );
  }

  static UiEffectsTokens lerp(UiEffectsTokens a, UiEffectsTokens b, double t) {
    return UiEffectsTokens(
      level: t < 0.5 ? a.level : b.level,
      enableBackdropBlur: t < 0.5 ? a.enableBackdropBlur : b.enableBackdropBlur,
      blurScale: a.blurScale + (b.blurScale - a.blurScale) * t,
      animateBlur: t < 0.5 ? a.animateBlur : b.animateBlur,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiEffectsTokens &&
          level == other.level &&
          enableBackdropBlur == other.enableBackdropBlur &&
          blurScale == other.blurScale &&
          animateBlur == other.animateBlur;

  @override
  int get hashCode =>
      Object.hash(level, enableBackdropBlur, blurScale, animateBlur);
}
