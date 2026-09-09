import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

/// Local, synthetic conversation: no transport or account is required.
void main() => runApp(
  const UiApp(debugShowCheckedModeBanner: false, home: ChatWorkbench()),
);

class ChatWorkbench extends StatefulWidget {
  const ChatWorkbench({super.key});
  @override
  State<ChatWorkbench> createState() => _ChatWorkbenchState();
}

class _ChatWorkbenchState extends State<ChatWorkbench> {
  final _controller = UiMessageScrollerController();
  final _draft = TextEditingController();
  final List<String> _sent = [];
  bool _reply = true;
  bool _failed = true;

  @override
  void dispose() {
    _controller.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPageScaffold(
      scrollFade: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final room = Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.x4),
                  child: Row(
                    children: [
                      const UiAvatar(name: 'Maya Hassan', size: 40),
                      SizedBox(width: tokens.spacing.x3),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UiText(
                              'Maya Hassan',
                              variant: UiTextVariant.subheading,
                            ),
                            UiText(
                              'Chat components · Demo conversation',
                              variant: UiTextVariant.caption,
                              tone: UiTextTone.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: UiMessageScroller(
                    controller: _controller,
                    padding: EdgeInsets.all(tokens.spacing.x4),
                    items: [
                      const UiMessageScrollerItem(
                        id: 'date',
                        child: UiMarker(
                          label: 'Today',
                          variant: UiMarkerVariant.separator,
                        ),
                      ),
                      UiMessageScrollerItem(
                        id: 'hello',
                        child: _message(
                          context,
                          text: 'Hi! I’ve shared the notes from today’s lesson. Take a look when you have a moment.',
                          time: '10:41',
                          outgoing: false,
                        ),
                      ),
                      UiMessageScrollerItem(
                        id: 'attachment',
                        child: UiMessage(
                          avatar: const UiAvatar(name: 'Maya Hassan', size: 28),
                          footer: const UiMessageReceipt(timestamp: '10:42'),
                          child: UiAttachment(
                            title: 'Lesson 04 — Practice notes',
                            description: 'PDF · 2.4 MB',
                            state: UiAttachmentState.done,
                            media: const Icon(LucideIcons.fileText),
                            actions: [
                              UiIconButton(
                                icon: const Icon(LucideIcons.reply),
                                semanticsLabel: 'Reply to practice notes',
                                onPressed: () => setState(() {
                                  _reply = true;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      UiMessageScrollerItem(
                        id: 'reply',
                        child: _message(
                          context,
                          text: 'Thank you! The examples made it much clearer. I’ll work through the exercises tonight.',
                          time: '10:44',
                          outgoing: true,
                          quoted: true,
                        ),
                      ),
                      UiMessageScrollerItem(
                        id: 'failed',
                        child: _message(
                          context,
                          text: 'Could we go over the last exercise together?',
                          time: '10:45',
                          outgoing: true,
                          failed: _failed,
                        ),
                      ),
                      for (var i = 0; i < _sent.length; i++)
                        UiMessageScrollerItem(
                          id: 'sent-$i',
                          isOutgoing: true,
                          child: _message(
                            context,
                            text: _sent[i],
                            time: 'Now',
                            outgoing: true,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spacing.x3,
                    tokens.spacing.x2,
                    tokens.spacing.x3,
                    tokens.spacing.x3,
                  ),
                  child: UiChatComposer(
                    controller: _draft,
                    compactSendAction: true,
                    header: _reply
                        ? UiReplyPreview(
                            author: 'Maya Hassan',
                            summary: 'Lesson 04 — Practice notes',
                            onDismiss: () => setState(() => _reply = false),
                          )
                        : null,
                    onSend: (text) => setState(() {
                      _sent.add(text);
                      _reply = false;
                    }),
                  ),
                ),
              ],
            );
            if (!wide) return room;
            return Row(
              children: [
                SizedBox(
                  width: 300,
                  child: Padding(
                    padding: EdgeInsets.all(tokens.spacing.x3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(tokens.spacing.x3),
                          child: const UiText(
                            'Messages',
                            variant: UiTextVariant.heading,
                          ),
                        ),
                        const UiConversationTile(
                          title: 'Maya Hassan',
                          avatar: UiAvatar(name: 'Maya Hassan', size: 44),
                          preview: UiText(
                            'Practice notes and exercises',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            tone: UiTextTone.muted,
                          ),
                          timestamp: '10:45',
                          selected: true,
                          pinned: true,
                        ),
                        const SizedBox(height: 4),
                        const UiConversationTile(
                          title: 'Study group',
                          avatar: UiAvatar(name: 'Study group', size: 44),
                          preview: UiText(
                            'Are we meeting tomorrow?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            tone: UiTextTone.muted,
                          ),
                          timestamp: '09:30',
                          unread: true,
                          unreadCountLabel: '3',
                          unreadLabel: '3 unread messages',
                        ),
                      ],
                    ),
                  ),
                ),
                UiBox(width: 1, background: tokens.colors.border),
                Expanded(child: room),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context, {
    required String text,
    required String time,
    required bool outgoing,
    bool quoted = false,
    bool failed = false,
  }) {
    final tokens = UiThemeTokens.of(context);
    final alignment = outgoing ? UiChatAlignment.end : UiChatAlignment.start;
    return UiMessage(
      alignment: alignment,
      avatar: outgoing ? null : const UiAvatar(name: 'Maya Hassan', size: 28),
      footer: UiMessageReceipt(
        timestamp: time,
        status: !outgoing
            ? null
            : failed
            ? UiMessageDeliveryStatus.failed
            : UiMessageDeliveryStatus.read,
        onRetry: failed ? () => setState(() => _failed = false) : null,
      ),
      child: UiBubble(
        alignment: alignment,
        variant: outgoing ? UiBubbleVariant.primary : UiBubbleVariant.secondary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (quoted) ...[
              UiReplyPreview(
                author: 'Maya Hassan',
                summary: 'Lesson 04 — Practice notes',
                foregroundColor: tokens.colors.onPrimary,
                backgroundColor: tokens.colors.onPrimary.withValues(alpha: .12),
                onPressed: () => _controller.jumpToMessage('attachment'),
              ),
              SizedBox(height: tokens.spacing.x2),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}
