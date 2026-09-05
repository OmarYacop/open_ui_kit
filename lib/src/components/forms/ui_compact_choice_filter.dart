import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_measured_morph.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/overlay/ui_layered_overlay.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiButtonMetrics, UiSize;

/// A compact choice control whose resting surface becomes its floating menu.
///
/// The expanded surface targets the nearest Open UI floating layer so page
/// navigation chrome can remain above it while preserving the spatial morph.
class UiCompactChoiceFilter<T> extends StatefulWidget {
  const UiCompactChoiceFilter({
    super.key,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    this.iconBuilder,
    this.expandedTitle,
    this.overlayViewportPadding = EdgeInsets.zero,
    this.size = UiSize.md,
    this.semanticsLabel,
  }) : assert(options.length > 1);

  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final Widget Function(T value)? iconBuilder;
  final ValueChanged<T> onChanged;
  final String? expandedTitle;
  final EdgeInsets overlayViewportPadding;
  final UiSize size;
  final String? semanticsLabel;

  @override
  State<UiCompactChoiceFilter<T>> createState() =>
      _UiCompactChoiceFilterState<T>();
}

class _UiCompactChoiceFilterState<T> extends State<UiCompactChoiceFilter<T>>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  late final AnimationController _animation;
  late UiMotionSpec _motion;
  OverlayEntry? _overlayEntry;
  bool _inOverlay = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = UiMotionSpec.resolve(
      context,
      duration: UiMotionSpeed.standard,
      reverseDuration: UiMotionSpeed.fast,
    );
    _motion.configure(_animation);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Semantics(
      container: true,
      button: true,
      expanded: _inOverlay,
      label: widget.semanticsLabel ?? widget.labelBuilder(widget.value),
      onTap: _toggle,
      child: UiPressable(
        onPressed: _toggle,
        excludeFromSemantics: true,
        minTapSize: 44,
        builder: (context, state, _) => Align(
          widthFactor: 1,
          heightFactor: 1,
          child: UiFocusRing(
            visible: state.focused,
            borderRadius: tokens.radius.mdAll,
            child: CompositedTransformTarget(
              link: _link,
              child: _MorphSurface(
                debugKey: const Key('compact_choice_trigger_surface'),
                progress: 0,
                pressed: state.pressed,
                transparent: _inOverlay,
                child: _MorphContent<T>(
                  progress: 0,
                  value: widget.value,
                  options: widget.options,
                  labelBuilder: widget.labelBuilder,
                  iconBuilder: widget.iconBuilder,
                  expandedTitle: widget.expandedTitle,
                  size: widget.size,
                  onSelected: _select,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle() => _inOverlay ? _close() : _open();

  void _open() {
    if (_overlayEntry != null) return;
    final overlay =
        UiLayeredOverlay.maybeOf(context, UiOverlayLayer.floating) ??
        Overlay.maybeOf(context);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      maintainState: true,
      builder: (_) => _MorphOverlay<T>(
        link: _link,
        animation: _animation,
        motion: _motion,
        value: widget.value,
        options: widget.options,
        labelBuilder: widget.labelBuilder,
        iconBuilder: widget.iconBuilder,
        expandedTitle: widget.expandedTitle,
        viewportPadding: widget.overlayViewportPadding,
        size: widget.size,
        onDismiss: _close,
        onSelected: _select,
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() {
      _inOverlay = true;
    });
    _animation.forward(from: 0);
  }

  Future<void> _close() async {
    if (!_inOverlay || _closing) return;
    _closing = true;
    await _animation.reverse();
    if (!mounted) return;
    _removeOverlay();
    setState(() {
      _inOverlay = false;
      _closing = false;
    });
  }

  void _select(T value) {
    if (value != widget.value) widget.onChanged(value);
    _close();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }
}

class _MorphOverlay<T> extends StatelessWidget {
  const _MorphOverlay({
    required this.link,
    required this.animation,
    required this.motion,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.iconBuilder,
    required this.expandedTitle,
    required this.viewportPadding,
    required this.size,
    required this.onDismiss,
    required this.onSelected,
  });

  final LayerLink link;
  final AnimationController animation;
  final UiMotionSpec motion;
  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final Widget Function(T value)? iconBuilder;
  final String? expandedTitle;
  final EdgeInsets viewportPadding;
  final UiSize size;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final anchor = isRtl ? Alignment.topLeft : Alignment.topRight;

    return ClipRect(
      clipper: _ViewportInsetClipper(viewportPadding),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onDismiss,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              targetAnchor: anchor,
              followerAnchor: anchor,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final progress = motion.transform(
                    animation.value,
                    reversing: animation.status == AnimationStatus.reverse,
                  );
                  final lift = 1 + math.sin(progress * math.pi) * 0.018;
                  return Transform.scale(
                    scale: lift,
                    alignment: anchor,
                    child: _MorphSurface(
                      debugKey: const Key('compact_choice_expanded_surface'),
                      progress: progress,
                      child: _MorphContent<T>(
                        progress: progress,
                        value: value,
                        options: options,
                        labelBuilder: labelBuilder,
                        iconBuilder: iconBuilder,
                        expandedTitle: expandedTitle,
                        size: size,
                        onSelected: onSelected,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewportInsetClipper extends CustomClipper<Rect> {
  const _ViewportInsetClipper(this.padding);

  final EdgeInsets padding;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      padding.left,
      padding.top,
      size.width - padding.right,
      size.height - padding.bottom,
    );
  }

  @override
  bool shouldReclip(covariant _ViewportInsetClipper oldClipper) =>
      oldClipper.padding != padding;
}

class _MorphSurface extends StatelessWidget {
  const _MorphSurface({
    required this.debugKey,
    required this.progress,
    required this.child,
    this.pressed = false,
    this.transparent = false,
  });

  final Key debugKey;
  final double progress;
  final Widget child;
  final bool pressed;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final radius = BorderRadius.lerp(
      tokens.radius.mdAll,
      tokens.radius.lgAll,
      progress,
    )!;
    final surface = Color.lerp(
      pressed ? tokens.colors.accent : tokens.colors.card,
      tokens.colors.popover.withValues(alpha: 0.9),
      progress,
    )!;
    final border = Color.lerp(
      tokens.colors.input,
      tokens.colors.border.withValues(alpha: 0.72),
      progress,
    )!;

    return Opacity(
      key: debugKey,
      opacity: transparent ? 0 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: BoxShadow.lerpList(
            tokens.shadows.none,
            tokens.shadows.lg,
            progress,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: _buildSurface(
            tokens: tokens,
            progress: progress,
            surface: surface,
            radius: radius,
            border: border,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSurface({
    required UiThemeTokens tokens,
    required double progress,
    required Color surface,
    required BorderRadius radius,
    required Color border,
    required Widget child,
  }) {
    Widget result = DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: child,
    );
    final requestedBlurSigma = tokens.effects.animateBlur
        ? 18 * progress
        : (progress > 0 ? 18.0 : 0.0);
    final blurSigma = tokens.effects.scaleBlur(requestedBlurSigma);
    if (blurSigma > 0) {
      result = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: result,
      );
    }
    return result;
  }
}

class _MorphContent<T> extends StatelessWidget {
  const _MorphContent({
    required this.progress,
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.iconBuilder,
    required this.expandedTitle,
    required this.size,
    required this.onSelected,
  });

  final double progress;
  final T value;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final Widget Function(T value)? iconBuilder;
  final String? expandedTitle;
  final UiSize size;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return UiMeasuredMorph(
      progress: progress,
      alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
      collapsed: SizedBox(
        height: 36,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x1),
          child: Center(
            widthFactor: 1,
            child: _ChoiceLabel(
              label: labelBuilder(value),
              icon: iconBuilder?.call(value),
              size: size,
              selected: false,
            ),
          ),
        ),
      ),
      expanded: Padding(
        padding: EdgeInsets.all(tokens.spacing.x2),
        child: Column(
          key: const Key('compact_choice_expanded_content'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expandedTitle != null && expandedTitle!.isNotEmpty)
              _ExpandedTitle(title: expandedTitle!),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  _OverlayChoice<T>(
                    selected: options[index] == value,
                    label: labelBuilder(options[index]),
                    icon: iconBuilder?.call(options[index]),
                    size: size,
                    onPressed: () => onSelected(options[index]),
                  ),
                  if (index != options.length - 1)
                    SizedBox(width: tokens.spacing.x1),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedTitle extends StatelessWidget {
  const _ExpandedTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.x2,
        0,
        tokens.spacing.x2,
        tokens.spacing.x1,
      ),
      child: UiText(
        title,
        variant: UiTextVariant.caption,
        tone: UiTextTone.muted,
        maxLines: 1,
      ),
    );
  }
}

class _ChoiceLabel extends StatelessWidget {
  const _ChoiceLabel({
    required this.label,
    this.icon,
    required this.size,
    required this.selected,
  });

  final String label;
  final Widget? icon;
  final UiSize size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final foreground = selected
        ? tokens.colors.primaryForeground
        : tokens.colors.foreground;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme.merge(
              data: IconThemeData(
                size: UiButtonMetrics.iconSize(size),
                color: foreground,
              ),
              child: icon!,
            ),
            SizedBox(width: UiButtonMetrics.gap(size, tokens.spacing)),
          ],
          UiText(
            label,
            variant: UiButtonMetrics.textVariant(size),
            style: UiButtonMetrics.textStyle(
              size,
              tokens,
            ).copyWith(color: foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OverlayChoice<T> extends StatelessWidget {
  const _OverlayChoice({
    required this.selected,
    required this.label,
    this.icon,
    required this.size,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final Widget? icon;
  final UiSize size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: UiPressable(
        onPressed: onPressed,
        excludeFromSemantics: true,
        minTapSize: 32,
        builder: (context, state, _) => AnimatedScale(
          scale: state.pressed ? 0.96 : 1,
          duration: tokens.motion.fast,
          curve: tokens.motion.standardCurve,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            decoration: BoxDecoration(
              color: selected
                  ? tokens.colors.primary
                  : state.hovered || state.pressed
                  ? tokens.colors.accent
                  : const Color(0x00000000),
              borderRadius: tokens.radius.mdAll,
            ),
            child: _ChoiceLabel(
              label: label,
              icon: icon,
              size: size,
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}
