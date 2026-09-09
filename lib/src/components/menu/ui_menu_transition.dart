import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_fluid_motion.dart';
import '../surfaces/ui_fluid_surface.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Menu-specific fluid presentation: stable content is revealed by the moving
/// outline, while visual separation returns to the parent during contraction.
/// Unlike a standalone button morph, the compact endpoint owns no separate fill.
class UiMenuTransition extends StatefulWidget {
  const UiMenuTransition({
    super.key,
    required this.controller,
    required this.sourceGeometry,
    required this.destinationGeometry,
    required this.destination,
    required this.overlayBuilder,
    required this.color,
    this.foregroundColor = const Color(0x00000000),
    this.backdropBlurSigma = 0,
    this.border = BorderSide.none,
    this.springStrength,
  });

  final UiFluidController controller;
  final UiFluidGeometry sourceGeometry;
  final UiFluidGeometry destinationGeometry;
  final Widget destination;
  final Widget Function(BuildContext, UiFluidMorphFrame) overlayBuilder;
  final Color color;
  final Color foregroundColor;
  final double backdropBlurSigma;
  final BorderSide border;
  final double? springStrength;

  @override
  State<UiMenuTransition> createState() => _UiMenuTransitionState();
}

class _UiMenuTransitionState extends State<UiMenuTransition> {
  int _revision = -1;
  UiFluidGeometry? _last, _origin;

  @override
  void didUpdateWidget(UiMenuTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _revision = -1;
      _last = _origin = null;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final strength =
          widget.springStrength ?? UiThemeTokens.menuOf(context).springStrength;
      if (_revision != controller.revision) {
        _origin = _last;
        _revision = controller.revision;
      }
      final geometry = controller.retargeting && _origin != null
          ? UiFluidGeometry.lerp(
              _origin!,
              controller.target == 1
                  ? widget.destinationGeometry
                  : widget.sourceGeometry,
              // The compact endpoint must contain the shared title throughout
              // dismissal. Opening remains elastic; closing cannot undershoot
              // the row or expose it again after briefly reaching its endpoint.
              controller.target == 0
                  ? Curves.easeOutCubic.transform(controller.transitionProgress)
                  : uiFluidSpring(
                      controller.transitionProgress,
                      strength: strength,
                    ),
            )
          : UiFluidGeometry.lerp(
              widget.sourceGeometry,
              widget.destinationGeometry,
              uiFluidSpring(
                ((controller.value - .34) / .66).clamp(0.0, 1.0),
                strength: strength,
              ),
            );
      _last = geometry;
      final travel =
          widget.destinationGeometry.rect.height -
          widget.sourceGeometry.rect.height;
      final expansion = travel.abs() < .001
          ? controller.value
          : ((geometry.rect.height - widget.sourceGeometry.rect.height) /
                    travel)
                .clamp(0.0, 1.0);
      // Separation dissolves faster than the geometric spring. The remaining
      // clip and shared header can return into the parent without a floating pill.
      final separation = expansion * expansion;
      final frame = UiFluidMorphFrame(geometry, 0, 1);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          UiFluidSurface(
            geometry: geometry,
            contentSize: widget.destinationGeometry.rect.size,
            fit: BoxFit.none,
            alignment: Alignment.topLeft,
            color: widget.color.withValues(alpha: widget.color.a * separation),
            backdropBlurSigma: widget.backdropBlurSigma * separation,
            foregroundColor: widget.foregroundColor,
            border: widget.border.copyWith(
              color: widget.border.color.withValues(
                alpha: widget.border.color.a * separation,
              ),
            ),
            child: widget.destination,
          ),
          widget.overlayBuilder(context, frame),
        ],
      );
    },
  );
}
