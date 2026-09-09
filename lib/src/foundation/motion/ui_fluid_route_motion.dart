import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'ui_fluid_motion.dart';

double _ease(double t) {
  final p = t.clamp(0.0, 1.0);
  return p * p * (3 - 2 * p);
}

/// Experimental: samples fluid morph frames from an externally clocked
/// progress such as a route's `AnimationController` or a Hero flight.
///
/// [UiFluidMorphFrame.sample] expects the press-and-hold prelude of a
/// [UiFluidController]. Routes have no held press: this helper maps the raw
/// `0..1` progress onto the contraction-and-spring portion of that timeline,
/// so the surface departs from the source rect on the very first frame.
///
/// Closing, and any user-driven scrub (edge-swipe back, sheet drag), samples
/// a monotonic ease instead of the spring, so the geometry never overshoots
/// under the finger or re-exposes the source before it lands.
@immutable
class UiFluidRouteMotion {
  const UiFluidRouteMotion({
    this.springStrength = .12,
    this.contraction = .9,
    this.scrimRamp = .2,
  }) : assert(springStrength >= 0),
       assert(contraction > 0 && contraction <= 1),
       assert(scrimRamp > 0 && scrimRamp <= 1);

  /// Overshoot scale passed to [uiFluidSpring]; full-screen destinations
  /// tolerate very little because the rect is clamped to the viewport.
  final double springStrength;

  /// Minimum source scale during the brief gather before expansion. Use `1`
  /// to skip contraction entirely.
  final double contraction;

  /// Fraction of progress over which a scrim reaches its full opacity.
  final double scrimRamp;

  /// Scrim opacity multiplier for [progress].
  double scrimOpacity(double progress) => _ease(progress / scrimRamp);

  /// Samples the frame for [progress] from [source] toward [destination].
  ///
  /// [progress] is always the position along the source-to-destination
  /// path (`0` at the source, `1` at the destination), regardless of the
  /// route's direction. Pass [monotonic] while closing or scrubbing. When
  /// [bounds] is given, the returned rect never leaves it. [monotonicCurve]
  /// shapes the closing geometry; pass [Curves.linear] when the clock itself
  /// is already shaped (a spring simulation continuing a released drag).
  UiFluidMorphFrame sample({
    required UiFluidGeometry source,
    required UiFluidGeometry destination,
    required double progress,
    bool monotonic = false,
    Rect? bounds,
    Curve monotonicCurve = Curves.easeOutCubic,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final UiFluidMorphFrame frame;
    if (monotonic) {
      // Ease-out in closing time: fast departure from the page, gentle
      // landing on the source. Content hands off like a menu close: the
      // destination leaves within the first 22%, the source returns 25–50%.
      final closing = 1 - p;
      final geometryProgress = 1 - monotonicCurve.transform(closing);
      frame = UiFluidMorphFrame(
        UiFluidGeometry.lerp(source, destination, geometryProgress),
        _ease((closing - .25) / .25),
        1 - _ease(closing / .22),
      );
    } else {
      frame = UiFluidMorphFrame.sample(
        source: source,
        destination: destination,
        progress: .2 + .8 * p,
        contraction: contraction,
        pressExpansion: 0,
        springStrength: springStrength,
      );
    }
    final rect = constrainRect(frame.geometry.rect, bounds);
    if (rect == frame.geometry.rect) return frame;
    return UiFluidMorphFrame(
      UiFluidGeometry(
        rect,
        frame.geometry.radius,
        corners: frame.geometry.corners,
      ),
      frame.sourceOpacity,
      frame.destinationOpacity,
    );
  }

  /// Keeps [rect] inside [bounds] with a strictly positive, finite size.
  static Rect constrainRect(Rect rect, Rect? bounds) {
    var left = rect.left, top = rect.top, right = rect.right;
    var bottom = rect.bottom;
    if (bounds != null) {
      left = math.max(left, bounds.left);
      top = math.max(top, bounds.top);
      right = math.min(right, bounds.right);
      bottom = math.min(bottom, bounds.bottom);
    }
    if (!(right - left).isFinite || right - left < 1) right = left + 1;
    if (!(bottom - top).isFinite || bottom - top < 1) bottom = top + 1;
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
