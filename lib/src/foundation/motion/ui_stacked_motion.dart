import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Shared depth geometry for stacked overlay surfaces.
///
/// Used by drawers, toasts, and future overlay primitives so stacked
/// surfaces scale and offset consistently instead of each component
/// inventing slightly different motion.
class UiStackedMotion {
  const UiStackedMotion._();

  static const double scaleStep = 0.04;
  static const double offsetStep = 8;
  static const double opacityStep = 0.18;
  static const double drawerNestedOffsetStep = 24;
  static const Duration drawerDuration = Duration(milliseconds: 500);
  static const Duration drawerStackDuration = Duration(milliseconds: 650);
  static const Curve drawerCurve = Cubic(0.32, 0.72, 0, 1);

  static double scaleForDepth(double depth) {
    return math.max(0.82, 1 - scaleStep * depth);
  }

  static double opacityForDepth(double depth) {
    return math.max(0.0, 1 - opacityStep * depth);
  }

  static Offset offsetForDepth({
    required double depth,
    required AxisDirection direction,
    double step = offsetStep,
  }) {
    final value = step * depth;
    return switch (direction) {
      AxisDirection.up => Offset(0, -value),
      AxisDirection.down => Offset(0, value),
      AxisDirection.left => Offset(-value, 0),
      AxisDirection.right => Offset(value, 0),
    };
  }

  static Offset entranceOffsetFor({
    required AxisDirection direction,
    double distance = 20,
  }) {
    return switch (direction) {
      AxisDirection.up => Offset(0, distance),
      AxisDirection.down => Offset(0, -distance),
      AxisDirection.left => Offset(distance, 0),
      AxisDirection.right => Offset(-distance, 0),
    };
  }
}

/// Applies the shared stacked-overlay transform used by drawers and toasts.
///
/// The front-most surface should pass `depth = 0`; older surfaces increase
/// depth as they move behind the active one. [stackDirection] points in the
/// direction older surfaces should drift.
class UiStackedOverlaySurface extends StatelessWidget {
  const UiStackedOverlaySurface({
    super.key,
    required this.depth,
    required this.stackDirection,
    required this.child,
    this.entranceDirection,
    this.entranceProgress = 1,
    this.entranceDistance = 20,
    this.visible = true,
    this.depthOffsetStep = UiStackedMotion.offsetStep,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
    this.scaleAlignment = Alignment.center,
    this.applyOpacity = true,
    this.implicitScaleAnimation = true,
    this.repaintBoundary = true,
  });

  final double depth;
  final AxisDirection stackDirection;
  final AxisDirection? entranceDirection;
  final double entranceProgress;
  final double entranceDistance;
  final bool visible;
  final double depthOffsetStep;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry scaleAlignment;
  final bool applyOpacity;
  final bool implicitScaleAnimation;
  final bool repaintBoundary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = entranceProgress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: depth),
      duration: duration,
      curve: curve,
      builder: (context, depthValue, child) {
        final entranceOffset = entranceDirection == null
            ? Offset.zero
            : UiStackedMotion.entranceOffsetFor(
                  direction: entranceDirection!,
                  distance: entranceDistance,
                ) *
                (1 - progress);
        final depthOffset = UiStackedMotion.offsetForDepth(
          depth: depthValue,
          direction: stackDirection,
          step: depthOffsetStep,
        );
        final depthScale = UiStackedMotion.scaleForDepth(depthValue);
        final depthOpacity = UiStackedMotion.opacityForDepth(depthValue);
        final resolvedScaleAlignment = scaleAlignment.resolve(
          Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        final scaled = implicitScaleAnimation
            ? AnimatedScale(
                duration: duration,
                curve: curve,
                alignment: resolvedScaleAlignment,
                scale: depthScale * (visible ? 1.0 : 0.98),
                child: child,
              )
            : Transform.scale(
                alignment: resolvedScaleAlignment,
                scale: depthScale * (visible ? 1.0 : 0.98),
                child: child,
              );
        Widget current = Transform.translate(
          offset: entranceOffset + depthOffset,
          child: scaled,
        );
        if (applyOpacity) {
          current = AnimatedOpacity(
            duration: duration,
            curve: curve,
            opacity: visible ? depthOpacity * progress : 0.0,
            child: current,
          );
        }
        if (repaintBoundary) current = RepaintBoundary(child: current);
        return current;
      },
      child: child,
    );
  }
}
