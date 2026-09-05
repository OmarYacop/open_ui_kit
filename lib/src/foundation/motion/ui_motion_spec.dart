import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';
import 'ui_motion_tokens.dart';

/// Named duration slots from [UiMotionTokens].
enum UiMotionSpeed { instant, faster, fast, standard, slow, xslow }

/// A duration source that can be resolved from semantic theme tokens or an
/// explicit authored value.
///
/// Custom values still collapse to zero when the platform requests reduced
/// motion. Use plain [Duration] only for non-visual time such as cache TTLs,
/// polling intervals, or how long a toast remains readable.
@immutable
class UiMotionDuration {
  const UiMotionDuration.token(this.speed) : customDuration = null;

  const UiMotionDuration.custom(Duration duration)
    : speed = null,
      customDuration = duration;

  final UiMotionSpeed? speed;
  final Duration? customDuration;

  Duration resolve(BuildContext context) {
    final motion = UiThemeTokens.motionOf(context);
    final custom = customDuration;
    if (custom == null) {
      return UiMotionSpec.resolveDuration(motion, speed!);
    }
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduced ? Duration.zero : custom;
  }

  Duration resolveFromTokens(
    UiMotionTokens tokens, {
    bool reducedMotion = false,
  }) {
    if (reducedMotion) return Duration.zero;
    final custom = customDuration;
    return custom ?? UiMotionSpec.resolveDuration(tokens, speed!);
  }

  static const instant = UiMotionDuration.token(UiMotionSpeed.instant);
  static const faster = UiMotionDuration.token(UiMotionSpeed.faster);
  static const fast = UiMotionDuration.token(UiMotionSpeed.fast);
  static const standard = UiMotionDuration.token(UiMotionSpeed.standard);
  static const slow = UiMotionDuration.token(UiMotionSpeed.slow);
  static const xslow = UiMotionDuration.token(UiMotionSpeed.xslow);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiMotionDuration &&
          other.speed == speed &&
          other.customDuration == customDuration;

  @override
  int get hashCode => Object.hash(speed, customDuration);
}

/// A complete, theme-resolved contract for an interruptible transition.
///
/// Open UI components use this instead of hard-coded durations and curves.
/// External consumers can resolve the same contract with [resolve], configure
/// their controller with [configure], and transform its progress with
/// [transform].
@immutable
class UiMotionSpec {
  const UiMotionSpec({
    required this.duration,
    required this.reverseDuration,
    required this.curve,
    required this.reverseCurve,
  });

  final Duration duration;
  final Duration reverseDuration;
  final Curve curve;
  final Curve reverseCurve;

  bool get isReduced =>
      duration == Duration.zero && reverseDuration == Duration.zero;

  /// Resolves timing and easing from the active Open UI theme.
  ///
  /// [UiThemeTokens.of] already applies the platform's reduced-motion
  /// preference, so this returns zero-duration, linear motion when animations
  /// are disabled in [MediaQuery].
  factory UiMotionSpec.resolve(
    BuildContext context, {
    UiMotionSpeed duration = UiMotionSpeed.standard,
    UiMotionSpeed reverseDuration = UiMotionSpeed.fast,
    Curve? curve,
    Curve? reverseCurve,
  }) {
    final motion = UiThemeTokens.motionOf(context);
    return UiMotionSpec.fromTokens(
      motion,
      duration: duration,
      reverseDuration: reverseDuration,
      curve: curve,
      reverseCurve: reverseCurve,
    );
  }

  /// Resolves explicit authored timing while preserving reduced-motion
  /// behavior. Prefer [resolve] when semantic speed tokens are sufficient.
  factory UiMotionSpec.resolveCustom(
    BuildContext context, {
    required Duration duration,
    Duration? reverseDuration,
    Curve? curve,
    Curve? reverseCurve,
  }) {
    final tokens = UiThemeTokens.motionOf(context);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final resolvedCurve = curve ?? tokens.standardCurve;
    if (reduced) {
      return const UiMotionSpec(
        duration: Duration.zero,
        reverseDuration: Duration.zero,
        curve: Curves.linear,
        reverseCurve: Curves.linear,
      );
    }
    return UiMotionSpec(
      duration: duration,
      reverseDuration: reverseDuration ?? duration,
      curve: resolvedCurve,
      reverseCurve: reverseCurve ?? resolvedCurve.flipped,
    );
  }

  /// Resolves token-or-custom duration values into one motion contract.
  factory UiMotionSpec.resolveTiming(
    BuildContext context, {
    UiMotionDuration duration = UiMotionDuration.standard,
    UiMotionDuration reverseDuration = UiMotionDuration.fast,
    Curve? curve,
    Curve? reverseCurve,
  }) {
    final tokens = UiThemeTokens.motionOf(context);
    final resolvedCurve = curve ?? tokens.standardCurve;
    return UiMotionSpec(
      duration: duration.resolve(context),
      reverseDuration: reverseDuration.resolve(context),
      curve: resolvedCurve,
      reverseCurve: reverseCurve ?? resolvedCurve.flipped,
    );
  }

  factory UiMotionSpec.fromTokens(
    UiMotionTokens tokens, {
    UiMotionSpeed duration = UiMotionSpeed.standard,
    UiMotionSpeed reverseDuration = UiMotionSpeed.fast,
    Curve? curve,
    Curve? reverseCurve,
  }) {
    final resolvedCurve = curve ?? tokens.standardCurve;
    return UiMotionSpec(
      duration: resolveDuration(tokens, duration),
      reverseDuration: resolveDuration(tokens, reverseDuration),
      curve: resolvedCurve,
      reverseCurve: reverseCurve ?? resolvedCurve.flipped,
    );
  }

  /// Resolves a semantic speed against a concrete motion-token set.
  ///
  /// This is useful for component sub-phases that need the same token-or-custom
  /// timing model as a full [UiMotionSpec].
  static Duration resolveDuration(UiMotionTokens tokens, UiMotionSpeed speed) {
    return switch (speed) {
      UiMotionSpeed.instant => tokens.instant,
      UiMotionSpeed.faster => tokens.faster,
      UiMotionSpeed.fast => tokens.fast,
      UiMotionSpeed.standard => tokens.standard,
      UiMotionSpeed.slow => tokens.slow,
      UiMotionSpeed.xslow => tokens.xslow,
    };
  }

  void configure(AnimationController controller) {
    controller
      ..duration = duration
      ..reverseDuration = reverseDuration;
  }

  /// Applies the correct curve for the controller's current direction.
  double transform(double value, {required bool reversing}) {
    final normalized = value.clamp(0.0, 1.0);
    return (reversing ? reverseCurve : curve).transform(normalized);
  }
}
