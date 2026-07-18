import 'package:flutter/widgets.dart';

/// Unit used by [UiSlideFadeTransition] offsets.
enum UiTransitionOffsetUnit {
  /// Offsets are fractions of the child's size, matching [SlideTransition].
  fractional,

  /// Offsets are logical pixels, matching [Transform.translate].
  logicalPixels,
}

/// Shared fade + scale transition for structural UI motion.
///
/// Use this when a surface appears in place: dialogs, popovers, small sheets,
/// compact overlays. Timing and curve should be applied by the caller through
/// the provided [animation].
class UiFadeScaleTransition extends StatelessWidget {
  const UiFadeScaleTransition({
    super.key,
    required this.animation,
    required this.child,
    this.beginScale = 0.96,
    this.endScale = 1.0,
    this.alignment = Alignment.center,
    this.fade = true,
    this.repaintBoundary = false,
  });

  final Animation<double> animation;
  final Widget child;
  final double beginScale;
  final double endScale;
  final Alignment alignment;
  final bool fade;
  final bool repaintBoundary;

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: beginScale,
      end: endScale,
    ).animate(animation);

    Widget current = ScaleTransition(
      scale: scale,
      alignment: alignment,
      child: child,
    );
    if (fade) {
      current = FadeTransition(opacity: animation, child: current);
    }
    if (repaintBoundary) {
      current = RepaintBoundary(child: current);
    }
    return current;
  }
}

/// Shared slide + fade transition for directional structural UI motion.
///
/// The offsets are expressed as fractions of the child's size, matching
/// Flutter's [SlideTransition].
class UiSlideFadeTransition extends StatelessWidget {
  const UiSlideFadeTransition({
    super.key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.04),
    this.endOffset = Offset.zero,
    this.offsetUnit = UiTransitionOffsetUnit.fractional,
    this.fade = true,
    this.repaintBoundary = false,
  });

  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;
  final Offset endOffset;
  final UiTransitionOffsetUnit offsetUnit;
  final bool fade;
  final bool repaintBoundary;

  @override
  Widget build(BuildContext context) {
    final offset = Tween<Offset>(
      begin: beginOffset,
      end: endOffset,
    ).animate(animation);

    final childWithMotion = switch (offsetUnit) {
      UiTransitionOffsetUnit.fractional => SlideTransition(
          position: offset,
          child: child,
        ),
      UiTransitionOffsetUnit.logicalPixels => AnimatedBuilder(
          animation: offset,
          child: child,
          builder: (context, child) {
            return Transform.translate(offset: offset.value, child: child);
          },
        ),
    };

    Widget current = childWithMotion;
    if (fade) {
      current = FadeTransition(opacity: animation, child: current);
    }
    if (repaintBoundary) {
      current = RepaintBoundary(child: current);
    }
    return current;
  }
}
