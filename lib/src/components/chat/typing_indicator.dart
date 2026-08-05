import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../data_display/avatar.dart';

/// A participant currently composing a chat message.
@immutable
class UiTypingUser {
  const UiTypingUser({
    required this.id,
    required this.name,
    this.imageUrl,
    this.image,
    this.fallback,
  });

  /// Stable identity used when the visible participant set changes.
  final Object id;
  final String name;
  final String? imageUrl;
  final Widget? image;
  final Widget? fallback;
}

/// Builds the visible and spoken typing-state label.
typedef UiTypingLabelBuilder = String Function(List<UiTypingUser> users);

/// WhatsApp-style presence row for one or more people composing a message.
///
/// Participant changes cross-fade without resizing the surrounding chat, while
/// the trailing dots run as a staggered wave. An empty [users] list collapses
/// the component. Motion automatically stops when reduced motion is enabled.
class UiTypingIndicator extends StatefulWidget {
  const UiTypingIndicator({
    super.key,
    required this.users,
    this.labelBuilder,
    this.maxVisibleAvatars = 3,
    this.avatarSize = 24,
    this.showAvatars = true,
    this.showDots = true,
    this.animationDuration =
        const UiMotionDuration.custom(Duration(milliseconds: 1200)),
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 4,
      vertical: 6,
    ),
  });

  final List<UiTypingUser> users;

  /// Overrides both the visible label and its live-region announcement.
  /// Useful for product-specific copy or localization beyond the built-ins.
  final UiTypingLabelBuilder? labelBuilder;
  final int maxVisibleAvatars;
  final double avatarSize;
  final bool showAvatars;
  final bool showDots;
  final UiMotionDuration animationDuration;
  final EdgeInsetsGeometry padding;

  @override
  State<UiTypingIndicator> createState() => _UiTypingIndicatorState();
}

class _UiTypingIndicatorState extends State<UiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(vsync: this);

  bool get _shouldAnimate {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return widget.users.isNotEmpty &&
        widget.showDots &&
        !reduced &&
        (_dots.duration ?? Duration.zero) > Duration.zero;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureAnimation();
  }

  @override
  void didUpdateWidget(UiTypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.users.isEmpty != widget.users.isEmpty ||
        oldWidget.showDots != widget.showDots) {
      _configureAnimation();
    }
  }

  void _configureAnimation() {
    _dots.duration = widget.animationDuration.resolve(context);
    if (_shouldAnimate) {
      if (!_dots.isAnimating) _dots.repeat();
    } else {
      _dots
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final transition = UiMotionSpec.resolve(
      context,
      duration: UiMotionSpeed.standard,
      reverseDuration: UiMotionSpeed.fast,
    );
    final label = widget.users.isEmpty ? '' : _label(context);
    final identity = Object.hashAll(widget.users.map((user) => user.id));

    return AnimatedSwitcher(
      duration: transition.duration,
      reverseDuration: transition.reverseDuration,
      switchInCurve: transition.curve,
      switchOutCurve: transition.reverseCurve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: widget.users.isEmpty
          ? const SizedBox.shrink(key: ValueKey('typing-indicator-empty'))
          : Semantics(
              key: ValueKey(identity),
              container: true,
              liveRegion: true,
              label: label,
              child: ExcludeSemantics(
                child: Padding(
                  padding: widget.padding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showAvatars) ...[
                        UiAvatarGroup(
                          items: widget.users
                              .map(
                                (user) => UiAvatarEntry(
                                  name: user.name,
                                  imageUrl: user.imageUrl,
                                  image: user.image,
                                  fallback: user.fallback,
                                ),
                              )
                              .toList(growable: false),
                          maxVisible: widget.maxVisibleAvatars,
                          size: widget.avatarSize,
                          overlap: widget.avatarSize * .62,
                          showBorder: true,
                        ),
                        SizedBox(width: tokens.spacing.x2),
                      ],
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: transition.duration,
                          reverseDuration: transition.reverseDuration,
                          switchInCurve: transition.curve,
                          switchOutCurve: transition.reverseCurve,
                          child: UiText(
                            label,
                            key: ValueKey(label),
                            variant: UiTextVariant.bodySm,
                            tone: UiTextTone.muted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (widget.showDots) ...[
                        SizedBox(width: tokens.spacing.x2),
                        _TypingDots(animation: _dots),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _label(BuildContext context) {
    final builder = widget.labelBuilder;
    if (builder != null) return builder(List.unmodifiable(widget.users));
    return UiLocalizations.of(context).typingLabel(
      widget.users.map((user) => user.name).toList(growable: false),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = UiThemeTokens.colorsOf(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => SizedBox(
        width: 22,
        height: 16,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            final phase = (animation.value - index * .16) % 1;
            final lift = math.sin(phase * math.pi * 2).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, -2.5 * lift),
              child: Opacity(
                opacity: .45 + .55 * lift,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.textMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 5),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
