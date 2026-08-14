import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// Design-system loading spinner implemented without Material or Cupertino.
class UiSpinner extends StatefulWidget {
  const UiSpinner({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.4,
    this.color,
    this.value,
    this.animated = true,
  });

  final double size;
  final double strokeWidth;
  final Color? color;
  final double? value;

  /// Whether an indeterminate spinner rotates.
  ///
  /// Determinate spinners (`value != null`) and environments requesting
  /// reduced motion are always rendered as a stable frame.
  final bool animated;

  @override
  State<UiSpinner> createState() => _UiSpinnerState();
}

class _UiSpinnerState extends State<UiSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(UiSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animated != widget.animated ||
        oldWidget.value != widget.value) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animated && widget.value == null && !reduceMotion) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? UiThemeTokens.colorsOf(context).textPrimary;
    return Semantics(
      value: widget.value == null
          ? null
          : '${(widget.value!.clamp(0.0, 1.0) * 100).round()}%',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.rotate(
            angle: _controller.value * math.pi * 2,
            child: CustomPaint(
              painter: _UiSpinnerPainter(
                color,
                widget.strokeWidth,
                widget.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UiSpinnerPainter extends CustomPainter {
  const _UiSpinnerPainter(this.color, this.strokeWidth, this.value);

  final Color color;
  final double strokeWidth;
  final double? value;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Offset.zero & size,
      -math.pi / 2,
      value == null ? math.pi * 1.45 : math.pi * 2 * value!.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _UiSpinnerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.value != value;
}

/// Design-system determinate/indeterminate linear progress track.
class UiProgressBar extends StatefulWidget {
  const UiProgressBar({
    super.key,
    this.value,
    this.height = 4,
    this.color,
    this.backgroundColor,
  });

  final double? value;
  final double height;
  final Color? color;
  final Color? backgroundColor;

  @override
  State<UiProgressBar> createState() => _UiProgressBarState();
}

class _UiProgressBarState extends State<UiProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = UiThemeTokens.colorsOf(context);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _UiProgressPainter(
            value: widget.value,
            phase: _controller.value,
            color: widget.color ?? colors.primary,
            backgroundColor: widget.backgroundColor ?? colors.border,
          ),
        ),
      ),
    );
  }
}

class _UiProgressPainter extends CustomPainter {
  const _UiProgressPainter({
    required this.value,
    required this.phase,
    required this.color,
    required this.backgroundColor,
  });

  final double? value;
  final double phase;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = backgroundColor,
    );
    final fraction = value?.clamp(0.0, 1.0);
    final start = fraction == null ? (phase * 1.25 - 0.25) * size.width : 0.0;
    final width = fraction == null ? size.width * 0.25 : size.width * fraction;
    final left = start.clamp(0.0, size.width);
    final right = (start + width).clamp(0.0, size.width);
    if (right > left) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 0, right, size.height),
          radius,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UiProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}
