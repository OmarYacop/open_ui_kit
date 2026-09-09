import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'ui_motion_spec.dart';

/// Experimental geometry shared by fluid morph and split compositions.
@immutable
class UiFluidGeometry {
  const UiFluidGeometry(this.rect, this.radius, {this.corners})
    : assert(radius >= 0);

  final BorderRadius? corners;

  /// Full corner geometry; the existing scalar radius remains the fallback.
  BorderRadius get borderRadius => corners ?? BorderRadius.circular(radius);

  final Rect rect;
  final double radius;

  static UiFluidGeometry lerp(
    UiFluidGeometry a,
    UiFluidGeometry b,
    double t, {
    Offset bend = Offset.zero,
    // Optional outline clock for morphs whose rect may spring past its target.
    double? cornerProgress,
  }) {
    assert(a.rect.isFinite && b.rect.isFinite);
    assert(a.rect.width > 0 && a.rect.height > 0);
    assert(b.rect.width > 0 && b.rect.height > 0);
    // Extreme large-to-small transitions must not overshoot through zero size.
    // Bound the shared fraction, rather than clamping individual edges.
    var p = t;
    if (a.rect.width > b.rect.width) {
      p = math.min(p, (a.rect.width - .001) / (a.rect.width - b.rect.width));
    }
    if (a.rect.height > b.rect.height) {
      p = math.min(p, (a.rect.height - .001) / (a.rect.height - b.rect.height));
    }
    // Travel and size share progress; the bow has zero displacement and
    // tangent at both endpoints, without a separate settling animation.
    final bow = p <= 0 || p >= 1
        ? 0.0
        : math.pow(math.sin(math.pi * p), 2).toDouble();
    final corners = BorderRadius.lerp(
      a.borderRadius,
      b.borderRadius,
      cornerProgress ?? p,
    )!;
    Radius nonnegative(Radius r) =>
        Radius.elliptical(math.max(0, r.x), math.max(0, r.y));
    return UiFluidGeometry(
      Rect.lerp(a.rect, b.rect, p)!.shift(bend * bow),
      math.max(0, lerpDouble(a.radius, b.radius, cornerProgress ?? p)!),
      corners: BorderRadius.only(
        topLeft: nonnegative(corners.topLeft),
        topRight: nonnegative(corners.topRight),
        bottomLeft: nonnegative(corners.bottomLeft),
        bottomRight: nonnegative(corners.bottomRight),
      ),
    );
  }
}

double _ease(double t) {
  final p = t.clamp(0.0, 1.0);
  return p * p * (3 - 2 * p);
}

/// Authored normalized response. Geometry shares this one settling clock.
double uiFluidSpring(double progress, {double strength = 1}) {
  final q = progress.clamp(0.0, 1.0);
  final clock = q < .1 ? q * q * (.2 - q) / .01 : q;
  final spring = 1 - math.exp(-6 * clock) * math.cos(5 * clock);
  final response = lerpDouble(spring, 1, _ease((q - .9) / .1))!;
  return response <= 1 ? response : 1 + (response - 1) * strength;
}

/// A sampled V13 frame; content and geometry cannot drift between clocks.
@immutable
class UiFluidMorphFrame {
  const UiFluidMorphFrame(
    this.geometry,
    this.sourceOpacity,
    this.destinationOpacity,
  );
  final UiFluidGeometry geometry;
  final double sourceOpacity;
  final double destinationOpacity;

  static UiFluidMorphFrame sample({
    required UiFluidGeometry source,
    required UiFluidGeometry destination,
    required double progress,
    double contraction = .68,
    double pressExpansion = 1,
    double springStrength = 1,
  }) {
    assert(contraction > 0 && contraction <= 1);
    final t = progress.clamp(0.0, 1.0);
    final a = source.rect;
    UiFluidGeometry scaled(Offset center, double x, double y, double radius) =>
        UiFluidGeometry(
          Rect.fromCenter(
            center: center,
            width: a.width * x,
            height: a.height * y,
          ),
          source.radius * radius,
          corners: source.borderRadius * radius,
        );
    final delta = destination.rect.center - a.center;
    final nudge = delta.distance == 0
        ? Offset.zero
        : delta / delta.distance * math.min(8, delta.distance * .12);
    final compact = scaled(
      a.center + nudge,
      contraction,
      contraction,
      contraction,
    );
    if (t <= .2) {
      final p = _ease(t / .2);
      return UiFluidMorphFrame(
        scaled(
          a.center,
          1 + .12 * p * pressExpansion,
          1 + .17 * p * pressExpansion,
          1 + .12 * p * pressExpansion,
        ),
        1,
        0,
      );
    }
    if (t < .34) {
      final travel = _ease((t - .2) / .14);
      final shrink = _ease((t - .24) / .10);
      return UiFluidMorphFrame(
        scaled(
          a.center + nudge * travel,
          lerpDouble(1 + .12 * pressExpansion, contraction, shrink)!,
          lerpDouble(1 + .17 * pressExpansion, contraction, shrink)!,
          lerpDouble(1 + .12 * pressExpansion, contraction, shrink)!,
        ),
        1 - _ease(shrink * 1.7),
        0,
      );
    }
    final q = (t - .34) / .66;
    return UiFluidMorphFrame(
      UiFluidGeometry.lerp(
        compact,
        destination,
        uiFluidSpring(q, strength: springStrength),
      ),
      0,
      _ease((q - .1) / .42),
    );
  }
}

/// One interruptible timeline for fluid compositions. Own and dispose this
/// alongside a TickerProvider. All operations honor reduced motion.
class UiFluidController extends AnimationController {
  UiFluidController({
    required super.vsync,
    super.value = 0,
    this.durationScale = 1,
  }) : assert(durationScale > 0);

  /// Scales all phases together, preserving the accepted timing proportions.
  final double durationScale;

  /// Last requested endpoint, suitable for toggling during animation.
  double get target => _target;
  double _target = 0;
  int revision = 0;
  double transitionStart = 0;
  bool retargeting = false;

  double get transitionProgress {
    final distance = (_target - transitionStart).abs();
    return distance == 0
        ? 1
        : ((value - transitionStart).abs() / distance).clamp(0.0, 1.0);
  }

  void _go(
    BuildContext context,
    double target,
    int microseconds, {
    bool retarget = false,
  }) {
    retargeting = retarget || (retargeting && value > 0 && value < 1);
    transitionStart = value;
    _target = target;
    revision++;

    final timing = UiMotionDuration.custom(
      Duration(microseconds: (microseconds * durationScale).round()),
    ).resolve(context);
    if (timing == Duration.zero) {
      value = target;
    } else {
      animateTo(target, duration: timing, curve: Curves.linear);
    }
  }

  void press(BuildContext context) {
    if (value <= .2) _go(context, .2, (122400 * ((.2 - value) / .2)).round());
  }

  /// Release from the current frame, including a quick tap before press ends.
  void open(BuildContext context, {bool direct = false}) =>
      _go(context, 1, (765000 * (1 - value)).round(), retarget: direct);

  void close(BuildContext context, {Duration? duration}) => _go(
    context,
    0,
    ((duration?.inMicroseconds ?? 612000) * value).round(),
    retarget: true,
  );

  void cancelPress(BuildContext context) {
    if (value <= .2) _go(context, 0, (612000 * value).round());
  }
}

/// A split's shared geometry/content sample. Consumers can use the same frame
/// to allocate surrounding layout and paint the released surfaces.
@immutable
class UiFluidSplitFrame {
  const UiFluidSplitFrame(this.geometryProgress, this.contentProgress);
  final double geometryProgress;
  final double contentProgress;
}

/// Retargetable split sampling shared by UiFluidSplit and layout owners.
/// Keeps the displayed frame as the origin when a spring reverses.
class UiFluidSplitMotion {
  UiFluidSplitMotion({this.springStrength = 1}) : assert(springStrength >= 0);

  /// Scales only settling overshoot; the approach and reversal stay continuous.
  final double springStrength;
  UiFluidController? _controller;
  int _revision = -1;
  double _lastP = 0, _lastQ = 0, _originP = 0, _originQ = 0;

  UiFluidSplitFrame sample(UiFluidController controller) {
    if (_controller != controller) {
      _controller = controller;
      _revision = -1;
      _lastP = uiFluidSpring(controller.value, strength: springStrength);
      _lastQ = controller.value;
    }
    var q = controller.value;
    var p = uiFluidSpring(q, strength: springStrength);
    if (_revision != controller.revision) {
      _originP = _lastP;
      _originQ = _lastQ;
      _revision = controller.revision;
    }
    if (controller.retargeting) {
      final progress = controller.transitionProgress;
      p =
          _originP +
          (controller.target - _originP) *
              uiFluidSpring(progress, strength: springStrength);
      q = _originQ + (controller.target - _originQ) * progress;
    }
    _lastP = p;
    _lastQ = q;
    return UiFluidSplitFrame(p, q);
  }
}
