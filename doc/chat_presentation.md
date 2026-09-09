# Chat presentation

Import `package:open_ui_kit/open_ui_kit.dart`, or the focused
`components/chat.dart` and `patterns/chat.dart` barrels.

- `UiMessageReceipt`: timestamp, edited label, sending/sent/delivered/read/failed
  state, and an optional labeled retry action. The application derives the state
  from transport and receipts. Prefer placement in `UiMessage.footer`, outside
  the bubble, so failure and read colors remain legible. All labels can be
  localized by the caller; `status: null` renders incoming metadata without a
  delivery indicator. Retry only appears for failed messages.
- `UiReplyPreview`: one author/summary presentation for message history and the
  composer. `onPressed` navigates to the original message; `onDismiss` is an
  independent action. The natural height accommodates text scaling. Supply
  `thumbnail` for application-rendered media and `deleted` for a tombstone.
  Inside a colored bubble pass its foreground and a compatible background.
  `variant: UiReplyPreviewVariant.message` uses a compact single-line quote;
  `composer` gives the cancel action and staged reply a little more breathing
  room. Neither displays a reply arrow. Supply `borderRadius` using the enclosing
  surface radius minus its inset to keep nested corners aligned.
- `UiConversationTile`: title, avatar, preview, timestamp, selected/unread state,
  and optional pinned/muted indicators. `unreadCountLabel: null` shows a small
  unread dot; supply a localized `unreadLabel` for its accessible meaning.
  Callbacks are optional for applications that already own row interaction.
  The title uses the full first line and may wrap; trailing timestamps sit on
  the preview line, where preview text yields space before the title does.
- `UiConversationLayout`: floating header/composer placement and history padding.
  Use inside a page scaffold. `headerExtent` includes the top safe inset;
  `composerExtent` is the measured dock height. The history builder receives
  padding including those extents, `composerBottomGap`, and
  `obscuredBottomInset`. Pass that padding to the timeline. The host owns keyboard
  avoidance and must position its composer above any keyboard/replacement panel;
  this pattern reserves history space without moving the dock a second time.
  Disable `fadeHistory` where a platform or application uses solid chrome.

The kit does not store messages, determine read receipts, upload attachments, or
implement backend retry policy. The LMS integration retains those application
responsibilities and supplies localized labels in its supported languages.

`example/lib/chat_main.dart` is an interactive synthetic conversation demonstrating
reply navigation, reply cancellation, local sending, retry and adaptive inbox rows.
No account or network is required. Existing `UiMessageBubble` and
`UiMessageStatus` remain available; the new delivery enum is additive.

Tracking: [OMA-58](https://linear.app/omar-yacop/issue/OMA-58/complete-reusable-chat-presentation-components).
Downstream: [OMA-59](https://linear.app/omar-yacop/issue/OMA-59/adopt-coherent-open-ui-kit-chat-presentation).

## Complete conversations

Use `UiChatScaffold` for a conversation page. It measures the header and writing,
recording or selection surface, reserves history padding, and owns the keyboard
dock. Pass its padding to the timeline. Do not add a second resizing scaffold or
keyboard dock. Floating scroll controls are a separate scaffold slot and do not
change the message content reserve. `UiConversationLayout` remains available for
hosts that intentionally own geometry themselves.

```dart
UiChatScaffold(
  header: UiChatHeader(title: roomName, leading: backAction, trailing: avatarAction),
  historyBuilder: (context, padding) => UiChatTimeline.messages(
    controller: historyController,
    padding: padding,
    entries: entries, // oldest first; stable IDs, dates, sender IDs and builders
    dateLabelBuilder: formatDate,
    onLoadEarlier: loadEarlier,
    typing: typingIndicator,
  ),
  composer: UiChatComposer.conversation(
    controller: formattedDraft, // accepts UiFormattedTextController unchanged
    focusNode: draftFocus,
    hint: localizedMessageHint,
    sendLabel: localizedSend,
    recordLabel: localizedRecord,
    attachmentLabel: localizedAttach,
    attachmentItems: attachmentMenuItems,
    contextShelf: replyPreview,
    onSend: sendMessage,
    onRecord: startRecording,
    actionMode: activeComposerMode, // UiChatComposerActions, null while writing
  ),
)
```

`UiChatComposer.conversation` keeps the circular attachment menu outside the
rounded input and places the reply shelf and send/microphone action inside.
It switches actions from the controller's draft, supports multiline formatted
input, and coordinates size/fade transitions with reduced-motion preferences.
The ordinary constructor keeps its existing toolbar design. By default send
trims and clears the draft; set `clearOnSend: false` to clear it yourself after
an asynchronous operation succeeds. The kit never starts recording or uploads.

Use `UiChatComposerActions.content` for a recording indicator and duration in
place of the inline selection actions. `onClose` cancels recording, while
`primary` finishes into the host's preview flow. Both modes share the Contour
transition, retain the mounted text draft, and remove attachment-menu gestures
from the X control. `selectionLabel` supplies the active mode's accessible
label, including for recording. `modeSurface` remains available for custom
presentations that replace the entire composer.

Each `UiChatTimelineEntry.builder` receives `UiChatMessageGrouping`; pass
`startsGroup` and `endsGroup` to `UiChatMessage`, use `showTimestamp` for text **and
media**, and supply a date-label builder for automatic markers. Events use
`isMessage: false` and break sender runs. Dates must already be converted to the
presentation timezone. Grouping compares complete minute buckets, not just the
minute within an hour. The plain `UiChatTimeline` constructor also accepts
precomposed scroller items. Empty/loading/error/typing slots keep application
state outside the kit and preserve the scroller instance through updates.

`UiChatMessage` owns avatar reservation, sender labels, bubble corners and width,
reply/metadata placement, selected rows, long-press selection, and logical
start-to-end swipe-to-reply. It exposes accessible custom actions for reply and
selection; pass localized labels. Supply `reply`, `metadata`, and application
media as slots. `mediaWithoutCaption` removes content padding, while
`fullMediaCorners` preserves continuous media corners. Optional color overrides
support existing branded message palettes. Successful delivery status should use
`uiChatShowsReceipt` with the latest non-deleted outgoing message; sending and
failed states remain visible regardless of position. Receipt derivation and retry
callbacks remain application-owned.

`UiChatWorkspace<T>` specializes `UiDualPane<T>` with the existing LMS 2:3 split,
zero gap and tablet overlay detail. Reuse `UiDualPaneController<T>` and provide
inbox/detail builders. Phone selection uses the existing root-route navigation;
no parallel selection store is introduced.

LMS now adopts these APIs. Its remaining presentation adapters resolve members,
localized text, reply snapshots and thumbnails, render specialized image/video/
voice/PDF content, and provide selection/recording controls. LMS also retains
history loading, queue counts and reply-return commands around the kit scroller.
Visual approval is deliberately left to the user; no simulator is required for
the widget regression suite.


### Selection and attachment focus

Pass `UiChatComposerActions` through `UiChatComposer.conversation.actionMode`.
The persistent attachment control becomes Close, the input deck morphs into
secondary actions, and the primary action emerges at the trailing edge. A single
Contour controller owns geometry and reversals; hidden writing controls cannot
take focus. LMS supplies Delete as the opaque destructive primary action, with
Reply/Info/Copy inside the deck. The draft/controller survive the transition.

`onAttachmentMenuOpened` runs before the menu takes focus. A host opening native
pickers can snapshot draft focus there, hide the IME before picker/preview work,
and restore focus after cancellation or route return. `UiChatScaffold` history
taps also explicitly hide the IME to recover from orphaned native keyboard state.
The default composer sits 8 logical pixels above an open keyboard (its internal
padding), with no additional history gap beyond the measured composer reserve.

## Inline attachment drafts

Place `UiChatAttachmentTray` in `UiChatComposer.conversation.attachmentShelf`
so selected media stays above the caption inside the input surface. Keep the
conversation visible and open inspection only from an item's `onPreview`.
The tray contains one naturally proportioned image (bounded to 240 × 160), a
horizontal strip for batches, and compact document/recording rows. Set a lower
`maxHeight` when the keyboard or landscape leaves less room.

Pass caller-owned `UiChatDraftAttachment` items with stable IDs, localized
preview/removal labels, filename/size metadata, and callbacks. `mediaBuilder`
receives `BoxFit.contain` for one image or `BoxFit.cover` for batch thumbnails.
Omit it for files. Supply `onAdd` for the batch add tile; the composer's existing
attachment menu remains available for every state.

Set `allowEmptySend: attachments.isNotEmpty`; removing the last attachment
should leave the text controller untouched. Disable the tray and composer
while a picker is outstanding. Keep picker permissions, media rendering,
full-screen inspection, per-item send intent, uploads, progress and retry in
the host application. Existing constructors and `contextShelf` remain supported.

Tracked in [OMA-58](https://linear.app/omar-yacop/issue/OMA-58), with LMS adoption
in [OMA-59](https://linear.app/omar-yacop/issue/OMA-59).

Captioned image/video bubbles use a small media inset. Use
`UiChatMessage.mediaBorderRadius(context, hasCaption: true)` for the media clip
so its curve follows the bubble radius minus that inset. Keep the caption's
spacing inside the child; do not add a second media inset around reply content.
