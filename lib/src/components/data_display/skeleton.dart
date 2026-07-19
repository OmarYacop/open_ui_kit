import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

/// Shared loading placeholder surface and animation scope.
///
/// Place [UiSkeletonBar] or [UiSkeletonText] children inside this widget to
/// make every placeholder pulse in sync.
class UiSkeleton extends StatefulWidget {
  const UiSkeleton({
    super.key,
    this.width,
    this.height,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.background,
    this.border,
    this.duration = const Duration(milliseconds: 1200),
    this.animate = true,
    this.child,
  });

  final double? width;
  final double? height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;
  final Color? background;
  final BoxBorder? border;
  final Duration duration;
  final bool animate;
  final Widget? child;

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _shouldAnimate {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return widget.animate && !reduceMotion && widget.duration > Duration.zero;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(UiSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
      return;
    }

    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final background = widget.background ?? colors.surfaceMuted;
    final baseColor = Color.lerp(colors.surfaceMuted, colors.textMuted, 0.10)!;
    final highlightColor =
        Color.lerp(colors.surfaceMuted, colors.textMuted, 0.20)!;

    return _UiSkeletonScope(
      animation: _shouldAnimate ? _controller : null,
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: background,
          border: widget.border,
          borderRadius: widget.borderRadius ?? tokens.radius.xlAll,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Card-shaped loading placeholder.
class UiCardSkeleton extends StatelessWidget {
  const UiCardSkeleton({
    super.key,
    this.width,
    this.height,
    this.margin = EdgeInsets.zero,
    this.padding,
    this.borderRadius,
    this.child,
  });

  final double? width;
  final double? height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiSkeleton(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? EdgeInsets.all(tokens.spacing.x6),
      borderRadius: borderRadius,
      border: Border.all(color: tokens.colors.border, width: 1),
      background: tokens.colors.card,
      child: child,
    );
  }
}

/// Rectangular loading mark for text, icons, chips, and media blocks.
class UiSkeletonBar extends StatelessWidget {
  const UiSkeletonBar({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius,
  });

  const UiSkeletonBar.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scope = _UiSkeletonScope.maybeOf(context);
    final tokens = UiThemeTokens.of(context);
    final radius = borderRadius ?? BorderRadius.all(tokens.radius.pill);

    Widget bar(double value) {
      final baseColor = scope?.baseColor ??
          Color.lerp(
              tokens.colors.surfaceMuted, tokens.colors.textMuted, 0.10)!;
      final highlightColor = scope?.highlightColor ??
          Color.lerp(
              tokens.colors.surfaceMuted, tokens.colors.textMuted, 0.20)!;
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(baseColor, highlightColor, value),
          borderRadius: radius,
        ),
      );
    }

    final animation = scope?.animation;
    if (animation == null) return bar(0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => bar(animation.value),
    );
  }
}

/// Stack of text-line skeleton bars with optional per-line widths.
class UiSkeletonText extends StatelessWidget {
  const UiSkeletonText({
    super.key,
    this.lines = 3,
    this.height = 12,
    this.spacing,
    this.widths = const <double?>[],
  }) : assert(lines > 0);

  final int lines;
  final double height;
  final double? spacing;
  final List<double?> widths;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final gap = spacing ?? tokens.spacing.x2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < lines; index++) ...[
          UiSkeletonBar(
            width: index < widths.length ? widths[index] : null,
            height: height,
          ),
          if (index != lines - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

class _UiSkeletonScope extends InheritedWidget {
  const _UiSkeletonScope({
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required super.child,
  });

  final Animation<double>? animation;
  final Color baseColor;
  final Color highlightColor;

  static _UiSkeletonScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UiSkeletonScope>();
  }

  @override
  bool updateShouldNotify(_UiSkeletonScope oldWidget) {
    return animation != oldWidget.animation ||
        baseColor != oldWidget.baseColor ||
        highlightColor != oldWidget.highlightColor;
  }
}
