import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/chat/bubble.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// A complete message row. Domain content, receipt derivation and reply targets
/// stay application-owned; the kit owns spacing, avatar reservation, selection,
/// bubble geometry and directional swipe-to-reply.
class UiChatMessage extends StatelessWidget {
  const UiChatMessage({
    super.key,
    required this.child,
    this.outgoing = false,
    this.avatar,
    this.showAvatar = false,
    this.sender,
    this.startsGroup = false,
    this.endsGroup = false,
    this.fullMediaCorners = false,
    this.mediaWithoutCaption = false,
    this.reply,
    this.metadata,
    this.selected = false,
    this.selectionMode = false,
    this.onSelect,
    this.onReply,
    this.replyLabel = 'Reply',
    this.selectLabel = 'Select message',
    this.backgroundColor,
    this.foregroundColor,
    this.maxContentWidth = 360,
    this.widthFactor = .72,
    this.availableWidth,
  });
  final Widget child;
  final bool outgoing, showAvatar, startsGroup, endsGroup;
  final bool fullMediaCorners, mediaWithoutCaption, selected, selectionMode;
  final Widget? avatar, reply, metadata;
  final String? sender;
  final String replyLabel, selectLabel;
  final VoidCallback? onSelect, onReply;
  final Color? backgroundColor, foregroundColor;
  final double maxContentWidth, widthFactor;

  /// Optional host width when the row is already inside a constrained preview.
  final double? availableWidth;

  static BorderRadiusGeometry bubbleRadius(
    BuildContext context, {
    required bool outgoing,
    required bool endsGroup,
    bool fullMediaCorners = false,
  }) {
    final r = UiThemeTokens.of(context).radius;
    return BorderRadiusDirectional.only(
      topStart: r.md,
      topEnd: r.md,
      bottomStart: endsGroup && !outgoing && !fullMediaCorners ? r.xs : r.md,
      bottomEnd: endsGroup && outgoing && !fullMediaCorners ? r.xs : r.md,
    );
  }

  /// Radius for media inset inside a captioned bubble. The inner curve follows
  /// the outer curve minus its inset, including custom theme radii.
  static BorderRadius mediaBorderRadius(
    BuildContext context, {
    required bool hasCaption,
  }) {
    final tokens = UiThemeTokens.of(context);
    final outer = tokens.radius.md;
    final inset = hasCaption ? tokens.spacing.x1 : 0.0;
    return BorderRadius.all(
      Radius.elliptical(
        math.max(0, outer.x - inset),
        math.max(0, outer.y - inset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return _ReplySwipe(
      onReply: selectionMode ? null : onReply,
      child: Semantics(
        selected: selectionMode ? selected : null,
        customSemanticsActions: {
          if (onReply != null && !selectionMode)
            CustomSemanticsAction(label: replyLabel): onReply!,
          if (onSelect != null)
            CustomSemanticsAction(label: selectLabel): onSelect!,
        },
        child: GestureDetector(
          onLongPress: onSelect,
          onTap: selectionMode
              ? onSelect
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
                },
          child: Padding(
            padding: EdgeInsets.only(
              top: startsGroup
                  ? tokens.spacing.x2 + tokens.spacing.x1 / 2
                  : tokens.spacing.x1 / 2,
            ),
            child: ColoredBox(
              color: selected
                  ? tokens.colors.primary.withValues(alpha: .16)
                  : const Color(0x00000000),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x2),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    mainAxisAlignment: outgoing
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!outgoing) ...[
                        if (showAvatar && avatar != null)
                          avatar!
                        else
                          const SizedBox(width: 30),
                        SizedBox(width: tokens.spacing.x2),
                      ],
                      Flexible(
                        child: Column(
                          crossAxisAlignment: outgoing
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!outgoing && startsGroup && sender != null)
                              Padding(
                                padding: EdgeInsetsDirectional.only(
                                  start: tokens.spacing.x2,
                                  bottom: tokens.spacing.x1,
                                ),
                                child: UiText(
                                  sender!,
                                  variant: UiTextVariant.caption,
                                  style: tokens.typography.caption.copyWith(
                                    color: tokens.colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            UiBubble(
                              alignment: outgoing
                                  ? UiChatAlignment.end
                                  : UiChatAlignment.start,
                              variant: outgoing
                                  ? UiBubbleVariant.primary
                                  : UiBubbleVariant.secondary,
                              backgroundColor: backgroundColor,
                              foregroundColor: foregroundColor,
                              padding: mediaWithoutCaption
                                  ? EdgeInsets.zero
                                  : EdgeInsets.all(
                                      fullMediaCorners || reply != null
                                          ? tokens.spacing.x1
                                          : tokens.spacing.x2,
                                    ),
                              borderRadius: bubbleRadius(
                                context,
                                outgoing: outgoing,
                                endsGroup: endsGroup,
                                fullMediaCorners: fullMediaCorners,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.min(
                                    (availableWidth ?? constraints.maxWidth) *
                                        widthFactor,
                                    maxContentWidth,
                                  ),
                                ),
                                child: IntrinsicWidth(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (reply != null)
                                        Padding(
                                          padding: EdgeInsetsDirectional.only(
                                            start: mediaWithoutCaption
                                                ? tokens.spacing.x1
                                                : 0,
                                            top: mediaWithoutCaption
                                                ? tokens.spacing.x1
                                                : 0,
                                            end: mediaWithoutCaption
                                                ? tokens.spacing.x1
                                                : 0,
                                            bottom: mediaWithoutCaption
                                                ? tokens.spacing.x1
                                                : 0,
                                          ),
                                          child: reply!,
                                        ),
                                      if (reply != null &&
                                          !mediaWithoutCaption &&
                                          !fullMediaCorners)
                                        Padding(
                                          padding: EdgeInsets.all(
                                            tokens.spacing.x1,
                                          ),
                                          child: child,
                                        )
                                      else
                                        child,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (metadata != null)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: tokens.spacing.x1,
                                ),
                                child: metadata!,
                              ),
                          ],
                        ),
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
}

class _ReplySwipe extends StatefulWidget {
  const _ReplySwipe({required this.child, this.onReply});
  final Widget child;
  final VoidCallback? onReply;
  @override
  State<_ReplySwipe> createState() => _ReplySwipeState();
}

class _ReplySwipeState extends State<_ReplySwipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _return = AnimationController(vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });
  double _distance = 0;
  double _returnFrom = 0;
  bool _dragging = false;
  double get _offset => _dragging
      ? _distance
      : _returnFrom * (1 - Curves.easeOutCubic.transform(_return.value));
  void _finish({bool cancelled = false}) {
    final reply = !cancelled && _distance >= 44 ? widget.onReply : null;
    _returnFrom = _distance;
    _dragging = false;
    _distance = 0;
    _return.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : UiThemeTokens.of(context).motion.fast;
    _return.forward(from: 0);
    if (reply != null) {
      HapticFeedback.lightImpact();
      reply();
    }
  }

  @override
  void didUpdateWidget(covariant _ReplySwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onReply == null) {
      _distance = 0;
      _returnFrom = 0;
      _dragging = false;
      _return.stop();
    }
  }

  @override
  void dispose() {
    _return.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.ltr ? 1.0 : -1.0;
    final tokens = UiThemeTokens.of(context);
    final progress = (_offset / 44).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: widget.onReply == null
          ? null
          : (_) {
              _distance = _offset;
              _return.stop();
              _dragging = true;
            },
      onHorizontalDragUpdate: widget.onReply == null
          ? null
          : (details) => setState(() {
              final wasBeyondThreshold = _distance >= 44;
              _distance =
                  (_distance +
                          details.delta.dx *
                              sign *
                              (1 - (_distance / 76).clamp(0.0, .82)))
                      .clamp(0.0, 76.0);
              if (!wasBeyondThreshold && _distance >= 44) {
                HapticFeedback.mediumImpact();
              }
            }),
      onHorizontalDragEnd: widget.onReply == null ? null : (_) => _finish(),
      onHorizontalDragCancel: widget.onReply == null
          ? null
          : () => _finish(cancelled: true),
      child: Stack(
        children: [
          if (_offset > 0)
            PositionedDirectional(
              start: tokens.spacing.x4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: progress,
                  child: UiBox(
                    borderRadius: tokens.radius.pillAll,
                    background: progress == 1
                        ? tokens.colors.primary
                        : tokens.colors.surfaceMuted,
                    padding: EdgeInsets.all(tokens.spacing.x2),
                    child: Icon(
                      LucideIcons.reply,
                      size: 16,
                      color: progress == 1
                          ? tokens.colors.onPrimary
                          : tokens.colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset * sign, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
