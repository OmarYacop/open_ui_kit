import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// A conversation list row with clear identity, recency and unread hierarchy.
///
/// [preview] may contain formatted text or typing activity. Pass localized
/// [unreadLabel], [pinnedLabel] and [mutedLabel] for spoken state. A null callback
/// permits use within a caller-owned interaction surface.
class UiConversationTile extends StatelessWidget {
  const UiConversationTile({
    super.key,
    required this.title,
    required this.preview,
    this.avatar,
    this.timestamp,
    this.unread = false,
    this.unreadCountLabel,
    this.unreadLabel = 'Unread',
    this.selected = false,
    this.pinned = false,
    this.muted = false,
    this.pinnedLabel = 'Pinned',
    this.mutedLabel = 'Muted',
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
  });

  final String title;
  final Widget preview;
  final Widget? avatar;
  final String? timestamp;
  final bool unread;
  final String? unreadCountLabel;
  final String unreadLabel;
  final bool selected;
  final bool pinned;
  final bool muted;
  final String pinnedLabel;
  final String mutedLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Semantics(
      selected: selected,
      child: UiPressable(
        onPressed: onPressed,
        onLongPress: onLongPress,
        enabled: enabled,
        semanticsButton: onPressed != null || onLongPress != null,
        builder: (_, state, child) => UiFocusRing(
          visible: state.focused,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            decoration: tokens.radius.decoration(
              borderRadius: tokens.radius.lgAll,
              border: Border.all(
                color: selected ? tokens.colors.primary : tokens.colors.border,
              ),
              color: selected
                  ? Color.alphaBlend(
                      tokens.colors.primary.withValues(alpha: .09),
                      tokens.colors.surface,
                    )
                  : unread || state.hovered || state.pressed
                  ? tokens.colors.surfaceMuted
                  : tokens.colors.surface,
            ),
            padding: EdgeInsets.all(tokens.spacing.x3),
            child: Opacity(opacity: enabled ? 1 : .5, child: child),
          ),
        ),
        child: Row(
          children: [
            if (avatar != null) ...[
              avatar!,
              SizedBox(width: tokens.spacing.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: UiText(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          variant: UiTextVariant.body,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: tokens.spacing.x2,
                          ),
                          child: Semantics(
                            label: unreadLabel,
                            child: ExcludeSemantics(
                              child: UiBox(
                                background: tokens.colors.primary,
                                borderRadius: tokens.radius.pillAll,
                                padding: unreadCountLabel == null
                                    ? EdgeInsets.zero
                                    : EdgeInsets.symmetric(
                                        horizontal: tokens.spacing.x2,
                                        vertical: tokens.spacing.x1,
                                      ),
                                width: unreadCountLabel == null ? 8 : null,
                                height: unreadCountLabel == null ? 8 : null,
                                child: unreadCountLabel == null
                                    ? null
                                    : UiText(
                                        unreadCountLabel!,
                                        variant: UiTextVariant.caption,
                                        style: TextStyle(
                                          color: tokens.colors.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.x1),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stackedTime =
                          constraints.maxWidth < 240 &&
                          MediaQuery.textScalerOf(context).scale(12) > 18;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: preview),
                              if (muted || pinned)
                                SizedBox(width: tokens.spacing.x2),
                              if (muted)
                                Semantics(
                                  label: mutedLabel,
                                  child: ExcludeSemantics(
                                    child: Icon(
                                      LucideIcons.bellOff,
                                      size: 14,
                                      color: tokens.colors.textMuted,
                                    ),
                                  ),
                                ),
                              if (pinned)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: tokens.spacing.x1,
                                  ),
                                  child: Semantics(
                                    label: pinnedLabel,
                                    child: ExcludeSemantics(
                                      child: Icon(
                                        LucideIcons.pin,
                                        size: 14,
                                        color: tokens.colors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              if (timestamp != null && !stackedTime) ...[
                                SizedBox(width: tokens.spacing.x2),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * .45,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    widthFactor: 1,
                                    child: UiText(
                                      timestamp!,
                                      variant: UiTextVariant.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      tone: UiTextTone.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (timestamp != null && stackedTime)
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: UiText(
                                timestamp!,
                                variant: UiTextVariant.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                tone: UiTextTone.muted,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
