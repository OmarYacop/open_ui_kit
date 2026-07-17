import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Direction of a chat message.
enum UiMessageAuthor { incoming, outgoing }

/// Ephemeral state flag for streaming/pending messages.
enum UiMessageStatus { sent, pending, failed }

/// Chat bubble surface.
///
/// Keeps layout neutral (rounded rect, tail-less) and relies on the
/// author/status to pick colors from the theme.
class UiMessageBubble extends StatelessWidget {
  const UiMessageBubble({
    super.key,
    required this.text,
    required this.author,
    this.status = UiMessageStatus.sent,
    this.timestamp,
    this.leading,
  });

  final String text;
  final UiMessageAuthor author;
  final UiMessageStatus status;
  final String? timestamp;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final isOutgoing = author == UiMessageAuthor.outgoing;

    final bg = isOutgoing ? c.primary : c.surfaceMuted;
    final fg = isOutgoing ? c.onPrimary : c.textPrimary;
    final radius = BorderRadius.only(
      topLeft: tokens.radius.lg,
      topRight: tokens.radius.lg,
      bottomLeft: isOutgoing ? tokens.radius.lg : const Radius.circular(4),
      bottomRight: isOutgoing ? const Radius.circular(4) : tokens.radius.lg,
    );

    final column = Column(
      crossAxisAlignment:
          isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UiBox(
          background: bg,
          borderRadius: radius,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x4,
            vertical: tokens.spacing.x3,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Opacity(
              opacity: status == UiMessageStatus.pending ? 0.7 : 1,
              child: UiText(
                text,
                variant: UiTextVariant.body,
                style: TextStyle(color: fg),
              ),
            ),
          ),
        ),
        if (timestamp != null || status == UiMessageStatus.failed) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            status == UiMessageStatus.failed ? 'Failed to send' : timestamp!,
            variant: UiTextVariant.caption,
            tone: status == UiMessageStatus.failed
                ? UiTextTone.danger
                : UiTextTone.muted,
          ),
        ],
      ],
    );

    return Row(
      mainAxisAlignment:
          isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isOutgoing && leading != null) ...[
          leading!,
          SizedBox(width: tokens.spacing.x2),
        ],
        Flexible(child: column),
        if (isOutgoing && leading != null) ...[
          SizedBox(width: tokens.spacing.x2),
          leading!,
        ],
      ],
    );
  }
}
