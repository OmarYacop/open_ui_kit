import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

enum UiBubbleVariant {
  primary,
  secondary,
  muted,
  tinted,
  outline,
  ghost,
  destructive,
}

enum UiChatAlignment { start, end }

/// The visual message surface. Sender identity, metadata, and row alignment
/// belong to [UiMessage].
class UiBubble extends StatelessWidget {
  const UiBubble({
    super.key,
    required this.child,
    this.variant = UiBubbleVariant.secondary,
    this.alignment = UiChatAlignment.start,
    this.reactions,
    this.maxWidthFactor = .8,
    this.padding,
  }) : assert(maxWidthFactor > 0 && maxWidthFactor <= 1);

  final Widget child;
  final UiBubbleVariant variant;
  final UiChatAlignment alignment;
  final Widget? reactions;
  final double maxWidthFactor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final palette = switch (variant) {
      UiBubbleVariant.primary => (colors.primary, colors.onPrimary, null),
      UiBubbleVariant.secondary => (
          colors.secondary,
          colors.onSecondary,
          null,
        ),
      UiBubbleVariant.muted => (
          colors.surfaceMuted,
          colors.textMuted,
          null,
        ),
      UiBubbleVariant.tinted => (
          Color.alphaBlend(
            colors.primary.withValues(alpha: .10),
            colors.surface,
          ),
          colors.textPrimary,
          null,
        ),
      UiBubbleVariant.outline => (
          colors.surface,
          colors.textPrimary,
          colors.border,
        ),
      UiBubbleVariant.ghost => (
          const Color(0x00000000),
          colors.textPrimary,
          null,
        ),
      UiBubbleVariant.destructive => (
          colors.danger,
          colors.onDanger,
          null,
        ),
    };
    final ghost = variant == UiBubbleVariant.ghost;
    final radius = BorderRadiusDirectional.only(
      topStart: tokens.radius.lg,
      topEnd: tokens.radius.lg,
      bottomStart: alignment == UiChatAlignment.start
          ? tokens.radius.sm
          : tokens.radius.lg,
      bottomEnd: alignment == UiChatAlignment.end
          ? tokens.radius.sm
          : tokens.radius.lg,
    );

    final bubble = IconTheme.merge(
      data: IconThemeData(color: palette.$2),
      child: DefaultTextStyle.merge(
        style: tokens.typography.body.copyWith(color: palette.$2),
        child: UiBox(
          background: palette.$1,
          border: palette.$3 == null ? null : Border.all(color: palette.$3!),
          borderRadius: ghost ? null : radius,
          padding: padding ??
              (ghost
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(
                      horizontal: tokens.spacing.x4,
                      vertical: tokens.spacing.x3,
                    )),
          child: child,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = ghost
            ? constraints.maxWidth
            : constraints.maxWidth * maxWidthFactor;
        return Align(
          alignment: alignment == UiChatAlignment.end
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: alignment == UiChatAlignment.end
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                bubble,
                if (reactions != null)
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: reactions,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UiBubbleGroup extends StatelessWidget {
  const UiBubbleGroup({
    super.key,
    required this.children,
    this.spacing = 4,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
