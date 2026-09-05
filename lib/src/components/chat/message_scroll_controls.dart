import 'package:flutter/widgets.dart';
import 'package:flutter/physics.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Circular control that returns a conversation to its live edge.
class UiMessageScrollToBottomButton extends StatelessWidget {
  const UiMessageScrollToBottomButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Scroll to latest message',
    this.queuedMessageCount = 0,
    this.queueLabelBuilder,
  });

  final VoidCallback onPressed;
  final String semanticLabel;
  final int queuedMessageCount;
  final String Function(int count)? queueLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: onPressed,
      semanticsLabel: semanticLabel,
      minTapSize: 32,
      builder: (context, state, child) => AnimatedScale(
        scale: state.pressed ? .94 : 1,
        duration: tokens.motion.fast,
        curve: tokens.motion.standardCurve,
        child: child,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UiBox(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            background: tokens.colors.secondary,
            borderRadius: tokens.radius.pillAll,
            boxShadow: tokens.shadows.sm,
            child: SizedBox.square(
              dimension: 16,
              child: CustomPaint(
                painter: _DownArrowPainter(tokens.colors.primary),
              ),
            ),
          ),
          if (queuedMessageCount > 0)
            PositionedDirectional(
              top: -7,
              end: -7,
              child: UiMessageQueueBadge(
                count: queuedMessageCount,
                semanticLabelBuilder: queueLabelBuilder,
              ),
            ),
        ],
      ),
    );
  }
}

class _DownArrowPainter extends CustomPainter {
  const _DownArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final centerX = size.width / 2;
    final path = Path()
      ..moveTo(centerX, size.height * .2)
      ..lineTo(centerX, size.height * .68)
      ..moveTo(size.width * .27, size.height * .5)
      ..lineTo(centerX, size.height * .73)
      ..lineTo(size.width * .73, size.height * .5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DownArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compact count displayed over the live-edge control for queued arrivals.
class UiMessageQueueBadge extends StatelessWidget {
  const UiMessageQueueBadge({
    super.key,
    required this.count,
    this.semanticLabelBuilder,
  });

  final int count;
  final String Function(int count)? semanticLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final label = count > 999 ? '999+' : '$count';
    final semanticLabel =
        semanticLabelBuilder?.call(count) ??
        '$count new ${count == 1 ? 'message' : 'messages'}';
    return Semantics(
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: UiBox(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          background: tokens.colors.primary,
          borderRadius: tokens.radius.pillAll,
          child: UiText(
            label,
            variant: UiTextVariant.caption,
            style: TextStyle(
              color: tokens.colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Returns to a message whose quoted reply was followed elsewhere.
class UiMessageReplyReturnButton extends StatelessWidget {
  const UiMessageReplyReturnButton({
    super.key,
    required this.count,
    required this.onPressed,
    this.semanticLabel = 'Return to the last reply',
  });

  final int count;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: onPressed,
      semanticsLabel: semanticLabel,
      minTapSize: 32,
      builder: (context, state, child) => AnimatedScale(
        scale: state.pressed ? .96 : 1,
        duration: tokens.motion.fast,
        curve: tokens.motion.standardCurve,
        child: child,
      ),
      child: UiBox(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        background: tokens.colors.secondary,
        border: Border.all(color: tokens.colors.border),
        borderRadius: tokens.radius.pillAll,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiText(
              '@',
              variant: UiTextVariant.label,
              style: TextStyle(
                color: tokens.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            UiText(
              '$count',
              variant: UiTextVariant.label,
              style: TextStyle(
                color: tokens.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated conversation scroll controls inspired by compact messaging UIs.
class UiMessageScrollControls extends StatelessWidget {
  const UiMessageScrollControls({
    super.key,
    required this.show,
    required this.queuedMessageCount,
    required this.onScrollToBottom,
    this.replyReturnCount = 0,
    this.onReplyReturn,
    this.scrollToBottomLabel = 'Scroll to latest message',
    this.queueLabelBuilder,
    this.replyReturnLabel = 'Return to the last reply',
  });

  final bool show;
  final int queuedMessageCount;
  final VoidCallback onScrollToBottom;
  final int replyReturnCount;
  final VoidCallback? onReplyReturn;
  final String scrollToBottomLabel;
  final String Function(int count)? queueLabelBuilder;
  final String replyReturnLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final showReplyReturn = replyReturnCount > 0 && onReplyReturn != null;
    const standardCurve = Cubic(.4, 0, .2, 1);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: standardCurve,
      switchOutCurve: standardCurve,
      transitionBuilder: (child, animation) {
        final opacity = CurvedAnimation(
          parent: animation,
          curve: standardCurve,
          reverseCurve: Curves.easeIn,
        );
        final springScale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: Tween<double>(begin: .86, end: 1).animate(springScale),
            child: child,
          ),
        );
      },
      child: show
          ? TweenAnimationBuilder<double>(
              key: const ValueKey('message-scroll-controls'),
              tween: Tween<double>(begin: 0, end: showReplyReturn ? 1 : 0),
              duration: Duration(milliseconds: showReplyReturn ? 200 : 150),
              curve: showReplyReturn ? Curves.easeOutCubic : Curves.easeIn,
              builder: (context, chromeProgress, child) => UiBox(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(4 * chromeProgress),
                background: tokens.colors.background.withValues(
                  alpha: .7 * chromeProgress,
                ),
                border: Border.all(
                  color: tokens.colors.border.withValues(
                    alpha: .8 * chromeProgress,
                  ),
                ),
                borderRadius: tokens.radius.pillAll,
                boxShadow: chromeProgress == 0
                    ? null
                    : tokens.shadows.sm
                          .map(
                            (shadow) => shadow.copyWith(
                              color: shadow.color.withValues(
                                alpha: shadow.color.a * chromeProgress,
                              ),
                            ),
                          )
                          .toList(growable: false),
                child: child,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReplyReturnTransition(
                    child: showReplyReturn
                        ? Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: tokens.spacing.x2,
                            ),
                            child: UiMessageReplyReturnButton(
                              count: replyReturnCount,
                              onPressed: onReplyReturn!,
                              semanticLabel: replyReturnLabel,
                            ),
                          )
                        : null,
                  ),
                  UiMessageScrollToBottomButton(
                    onPressed: onScrollToBottom,
                    semanticLabel: scrollToBottomLabel,
                    queuedMessageCount: queuedMessageCount,
                    queueLabelBuilder: queueLabelBuilder,
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('message-scroll-hidden')),
    );
  }
}

class _ReplyReturnTransition extends StatefulWidget {
  const _ReplyReturnTransition({this.child});

  final Widget? child;

  @override
  State<_ReplyReturnTransition> createState() => _ReplyReturnTransitionState();
}

class _ReplyReturnTransitionState extends State<_ReplyReturnTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _retainedChild;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0);
    _retainedChild = widget.child;
    if (_retainedChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateIn();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ReplyReturnTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _retainedChild = widget.child;
      _animateIn();
    } else if (oldWidget.child != null) {
      _controller
          .animateWith(
            SpringSimulation(
              const SpringDescription(mass: 1, stiffness: 320, damping: 28),
              _controller.value,
              0,
              0,
            ),
          )
          .whenComplete(() {
            if (mounted && widget.child == null) {
              setState(() => _retainedChild = null);
            }
          });
    }
  }

  void _animateIn() {
    _controller.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 320, damping: 26),
        _controller.value,
        1,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_retainedChild == null) return const SizedBox.shrink();
    final revealAlignment = Directionality.of(context) == TextDirection.rtl
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return AnimatedBuilder(
      animation: _controller,
      child: _retainedChild,
      builder: (context, child) {
        final progress = _controller.value.clamp(0.0, 1.08);
        return ClipRect(
          child: Align(
            alignment: revealAlignment,
            widthFactor: progress,
            child: Opacity(
              opacity: _controller.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: .65 + (.35 * progress),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
