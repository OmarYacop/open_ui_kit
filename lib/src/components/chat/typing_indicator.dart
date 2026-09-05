import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../data_display/avatar.dart';
import 'bubble.dart';

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

/// A compact, WhatsApp-inspired incoming bubble for active composition.
///
/// The visible state is deliberately wordless: an avatar group and a three-dot
/// bubble keep the conversation anchored at its live edge without competing
/// with message content. The participant names remain available through the
/// live-region label. An empty [users] list collapses the component.
class UiTypingIndicator extends StatefulWidget {
  const UiTypingIndicator({
    super.key,
    required this.users,
    this.labelBuilder,
    this.maxVisibleAvatars = 3,
    this.avatarSize = 28,
    this.showAvatars = true,
    this.showDots = true,
    this.animationDuration = const UiMotionDuration.custom(
      Duration(milliseconds: 1200),
    ),
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: 4,
      vertical: 6,
    ),
  });

  final List<UiTypingUser> users;

  /// Overrides the live-region announcement.
  ///
  /// The visual indicator intentionally remains a compact ellipsis bubble,
  /// matching the chat vocabulary rather than repeating status text in-line.
  final UiTypingLabelBuilder? labelBuilder;

  /// The maximum number of active participants shown in the avatar group.
  ///
  /// Pass `0` to suppress the avatars while retaining the typing bubble.
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
    with TickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(vsync: this);
  late final AnimationController _presence = AnimationController(
    vsync: this,
    value: widget.users.isEmpty ? 0 : 1,
  )..addStatusListener(_handlePresenceStatus);
  late List<UiTypingUser> _visibleUsers = widget.users;

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
    _configurePresence();
  }

  @override
  void didUpdateWidget(UiTypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.users.isEmpty != widget.users.isEmpty ||
        oldWidget.showDots != widget.showDots) {
      _configureAnimation();
    }
    if (widget.users.isNotEmpty) {
      _visibleUsers = widget.users;
      _presence.forward();
    } else if (oldWidget.users.isNotEmpty) {
      _presence.reverse();
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

  void _configurePresence() {
    final motion = UiMotionSpec.resolve(
      context,
      duration: UiMotionSpeed.standard,
      reverseDuration: UiMotionSpeed.fast,
    );
    _presence
      ..duration = motion.duration
      ..reverseDuration = motion.reverseDuration;
    if (widget.users.isNotEmpty) _presence.forward();
  }

  void _handlePresenceStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        widget.users.isEmpty &&
        _visibleUsers.isNotEmpty) {
      setState(() => _visibleUsers = const []);
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    _presence.dispose();
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
    final users = _visibleUsers;
    if (users.isEmpty) return const SizedBox.shrink();
    final animation = CurvedAnimation(
      parent: _presence,
      curve: transition.curve,
      reverseCurve: transition.reverseCurve,
    );
    final label = _label(context, users);
    final identity = Object.hashAll(users.map((user) => user.id));

    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: Semantics(
          key: ValueKey(identity),
          container: true,
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Padding(
              padding: widget.padding,
              child: SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.showAvatars &&
                          widget.maxVisibleAvatars > 0) ...[
                        UiAvatarGroup(
                          items: users
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
                          overlap: widget.avatarSize * (4 / 7),
                        ),
                        SizedBox(width: tokens.spacing.x2),
                      ],
                      if (widget.showDots)
                        UiBubble(
                          alignment: UiChatAlignment.start,
                          variant: UiBubbleVariant.muted,
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.x3,
                            vertical: tokens.spacing.x2,
                          ),
                          child: _TypingDots(animation: _dots),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context, List<UiTypingUser> users) {
    final builder = widget.labelBuilder;
    if (builder != null) return builder(List.unmodifiable(users));
    return UiLocalizations.of(context)
        .typingLabel(users.map((user) => user.name).toList(growable: false));
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
                    color: colors.textMuted.withValues(alpha: .78),
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
