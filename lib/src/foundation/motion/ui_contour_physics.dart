import 'package:flutter/widgets.dart';

import '../effects/ui_effects_tokens.dart';
import '../theme/ui_theme_extensions.dart';

/// How a [UiContourPhysics] response may deform past its resting geometry.
enum UiContourOvershootPolicy {
  /// The response never exceeds its resting value. Used for chrome and
  /// destructive/high-stakes actions.
  none,

  /// The response may deform by a small, clamped amount before settling.
  /// Used for ordinary controls and surfaces.
  subtle,
}

/// A tokenized amplitude family for Open UI Kit's restrained material
/// motion.
///
/// This governs only *optional, decorative* surface deformation layered on
/// top of geometry that is already correct — never the geometry timeline
/// itself. An earlier revision used this to generate the transition
/// [Curve]; that conflated a physical spring response (calibrated in
/// seconds) with a normalized 0..1 progress fraction, which made the curve
/// saturate within the first ~15% of any duration regardless of tuning —
/// a snap-then-idle bug, not a tuning problem. Geometry progress now always
/// uses a plain, restrained curve resolved from `UiMotionSpec` (see
/// `UiContourController`); `UiContourPhysics` is reserved for a future
/// velocity-derived deformation layer, applied only to decorative surface
/// transforms and never to layout bounds (see `doc/contour.md`).
///
/// Do not construct ad hoc instances at call sites. Use [control],
/// [surface], or [chrome], or resolve a component-appropriate preset
/// through [UiContourPhysics.resolve].
@immutable
class UiContourPhysics {
  const UiContourPhysics({
    required this.maxStretch,
    required this.maxCompression,
    required this.overshootPolicy,
    required this.settleThreshold,
  })  : assert(maxStretch >= 0 && maxStretch <= 0.5),
        assert(maxCompression >= 0 && maxCompression <= 0.5),
        assert(settleThreshold >= 0 && settleThreshold <= 1);

  /// Small controls: buttons, chips, icon triggers. Low amplitude.
  static const control = UiContourPhysics(
    maxStretch: 0.04,
    maxCompression: 0.03,
    overshootPolicy: UiContourOvershootPolicy.subtle,
    settleThreshold: 0.995,
  );

  /// Larger content surfaces: sheets, expanded cards. Calmer than [control].
  static const surface = UiContourPhysics(
    maxStretch: 0.025,
    maxCompression: 0.02,
    overshootPolicy: UiContourOvershootPolicy.subtle,
    settleThreshold: 0.995,
  );

  /// Persistent application chrome: navigation bars, tab indicators,
  /// destructive/high-stakes confirmation. No deformation.
  static const chrome = UiContourPhysics(
    maxStretch: 0,
    maxCompression: 0,
    overshootPolicy: UiContourOvershootPolicy.none,
    settleThreshold: 0.999,
  );

  /// No deformation at all. Used under reduced motion and the disabled/
  /// accessibility-safe effects tier.
  static const none = UiContourPhysics(
    maxStretch: 0,
    maxCompression: 0,
    overshootPolicy: UiContourOvershootPolicy.none,
    settleThreshold: 1,
  );

  /// Maximum fractional deformation past resting geometry while opening,
  /// clamped. Decorative only — never applied to layout bounds.
  final double maxStretch;

  /// Maximum fractional deformation while settling/closing, clamped.
  final double maxCompression;

  final UiContourOvershootPolicy overshootPolicy;

  /// The progress value, once reached, past which the response is
  /// considered visually settled.
  final double settleThreshold;

  /// Resolves the appropriate preset for the current context, collapsing to
  /// [none] under reduced motion or the disabled/accessibility-safe effects
  /// tier so decorative deformation never survives those constraints.
  static UiContourPhysics resolve(
    BuildContext context,
    UiContourPhysics preset,
  ) {
    final effects = UiThemeTokens.effectsOf(context);
    if (effects.level == UiEffectsLevel.reduced) return none;
    return preset;
  }

  /// Amplitude (0..1) of decorative deformation for a given transition
  /// [progress], clamped to [maxStretch]/[maxCompression]. Never read this
  /// as a layout fraction — it is for a bounded, localized visual transform
  /// only (see the class doc).
  double deformationAmplitude(double progress) {
    final p = progress.clamp(0.0, 1.0);
    final rising = p < 0.5 ? p * 2 : (1 - p) * 2;
    final amplitude = rising.clamp(0.0, 1.0) * (maxStretch + maxCompression);
    return amplitude.clamp(0.0, maxStretch + maxCompression);
  }

  /// Whether [progress] has settled per [settleThreshold], from either
  /// direction (open toward 1, close toward 0).
  bool isSettled(double progress, {required bool opening}) {
    return opening
        ? progress >= settleThreshold
        : progress <= (1 - settleThreshold);
  }
}
