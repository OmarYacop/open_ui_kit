import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/icon_button.dart';
import '../../foundation/theme/ui_intent.dart';

enum UiReplyPreviewVariant { message, composer }

/// The same quoted-message vocabulary in history and above a composer.
///
/// Natural height supports large text. Media rendering and reply navigation
/// remain caller-owned; dismissal is a separate accessible action.
class UiReplyPreview extends StatelessWidget {
  const UiReplyPreview({
    super.key,
    required this.author,
    required this.summary,
    this.thumbnail,
    this.onPressed,
    this.onDismiss,
    this.dismissLabel = 'Cancel reply',
    this.semanticLabel,
    this.foregroundColor,
    this.backgroundColor,
    this.deleted = false,
    this.maxLines = 1,
    this.variant = UiReplyPreviewVariant.message,
    this.borderRadius,
  });

  final UiReplyPreviewVariant variant;
  final BorderRadiusGeometry? borderRadius;
  final String author;
  final String summary;
  final Widget? thumbnail;
  final VoidCallback? onPressed;
  final VoidCallback? onDismiss;
  final String dismissLabel;
  final String? semanticLabel;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final bool deleted;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final foreground = foregroundColor ?? tokens.colors.textPrimary;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiText(
                author,
                variant: UiTextVariant.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.spacing.x1 / 2),
              UiText(
                summary,
                variant: UiTextVariant.caption,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor ?? tokens.colors.textMuted,
                  fontStyle: deleted ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
        if (thumbnail != null && !deleted) ...[
          SizedBox(width: tokens.spacing.x2),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: tokens.radius.smAll,
              child: SizedBox.square(
                dimension: variant == UiReplyPreviewVariant.message ? 36 : 40,
                child: thumbnail,
              ),
            ),
          ),
        ],
      ],
    );
    return UiBox(
      background: backgroundColor ?? tokens.colors.surfaceMuted,
      borderRadius:
          borderRadius ??
          (variant == UiReplyPreviewVariant.message
              ? BorderRadius.circular(
                  (tokens.radius.md.x - tokens.spacing.x1).clamp(
                    0,
                    double.infinity,
                  ),
                )
              : tokens.radius.lgAll),
      border: BorderDirectional(
        start: BorderSide(
          color: foregroundColor ?? tokens.colors.primary,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: UiPressable(
              onPressed: onPressed,
              enabled: onPressed != null,
              semanticsLabel: semanticLabel ?? '$author, $summary',
              semanticsButton: onPressed != null,
              builder: (_, state, child) => UiFocusRing(
                visible: state.focused,
                child: AnimatedOpacity(
                  duration: tokens.motion.fast,
                  opacity: state.pressed ? .72 : 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.x2,
                      vertical: variant == UiReplyPreviewVariant.message
                          ? tokens.spacing.x1 + 2
                          : tokens.spacing.x2,
                    ),
                    child: child,
                  ),
                ),
              ),
              child: ExcludeSemantics(child: content),
            ),
          ),
          if (onDismiss != null)
            Padding(
              padding: EdgeInsetsDirectional.only(end: tokens.spacing.x1),
              child: UiIconButton(
                icon: const Icon(LucideIcons.x),
                semanticsLabel: dismissLabel,
                intent: UiIntent.neutral,
                backgroundColor: tokens.colors.surface,
                foregroundColor: tokens.colors.textPrimary,
                borderColor: tokens.colors.border,
                borderRadius: tokens.radius.pillAll,
                onPressed: onDismiss,
              ),
            ),
        ],
      ),
    );
  }
}
