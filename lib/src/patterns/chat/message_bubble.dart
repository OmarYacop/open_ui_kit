import 'package:flutter/widgets.dart';

import '../../components/chat/bubble.dart';
import '../../components/chat/message.dart';
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
    final colors = UiThemeTokens.colorsOf(context);
    final isOutgoing = author == UiMessageAuthor.outgoing;
    final alignment = isOutgoing ? UiChatAlignment.end : UiChatAlignment.start;

    return UiMessage(
      alignment: alignment,
      avatar: leading,
      footer: timestamp == null && status != UiMessageStatus.failed
          ? null
          : UiText(
              status == UiMessageStatus.failed ? 'Failed to send' : timestamp!,
              variant: UiTextVariant.caption,
              tone: status == UiMessageStatus.failed
                  ? UiTextTone.danger
                  : UiTextTone.muted,
            ),
      child: UiBubble(
        alignment: alignment,
        variant:
            isOutgoing ? UiBubbleVariant.primary : UiBubbleVariant.secondary,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Opacity(
            opacity: status == UiMessageStatus.pending ? .7 : 1,
            child: UiText(
              text,
              variant: UiTextVariant.body,
              style: TextStyle(
                color: isOutgoing ? colors.onPrimary : colors.onSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
