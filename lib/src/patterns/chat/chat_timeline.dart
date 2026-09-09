import 'package:flutter/widgets.dart';

import '../../components/chat/message_scroller.dart';
import '../../components/chat/message_receipt.dart';
import '../../components/chat/marker.dart';

/// Neighbor-derived presentation shared by text and media. Neighbors are in
/// chronological order; pass null across non-message events.
@immutable
class UiChatMessageGrouping {
  const UiChatMessageGrouping({
    required this.startsGroup,
    required this.endsGroup,
    required this.showTimestamp,
    required this.showDateMarker,
  });
  final bool startsGroup, endsGroup, showTimestamp, showDateMarker;

  static bool sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  factory UiChatMessageGrouping.resolve({
    required DateTime timestamp,
    DateTime? previousTimestamp,
    DateTime? nextTimestamp,
    bool samePreviousSender = false,
    bool sameNextSender = false,
  }) {
    final previousDay =
        previousTimestamp != null && sameDay(timestamp, previousTimestamp);
    final nextDay = nextTimestamp != null && sameDay(timestamp, nextTimestamp);
    return UiChatMessageGrouping(
      startsGroup: !previousDay || !samePreviousSender,
      endsGroup: !nextDay || !sameNextSender,
      showDateMarker: !previousDay,
      showTimestamp:
          !sameNextSender ||
          !nextDay ||
          timestamp.millisecondsSinceEpoch ~/ 60000 !=
              nextTimestamp.millisecondsSinceEpoch ~/ 60000,
    );
  }
}

enum UiChatReceiptVisibility { latestOutgoing, allOutgoing }

/// Selects presentation only; the application derives delivery status.
bool uiChatShowsReceipt({
  required bool outgoing,
  required bool latestOutgoing,
  required UiMessageDeliveryStatus status,
  UiChatReceiptVisibility visibility = UiChatReceiptVisibility.latestOutgoing,
}) =>
    outgoing &&
    (latestOutgoing ||
        visibility == UiChatReceiptVisibility.allOutgoing ||
        status == UiMessageDeliveryStatus.sending ||
        status == UiMessageDeliveryStatus.failed);

/// An application message or event projected into presentation data.
/// Event entries use [isMessage] false and break sender runs without losing
/// their stable history ID. The builder receives ready-to-use grouping.
class UiChatTimelineEntry {
  const UiChatTimelineEntry({
    required this.id,
    required this.timestamp,
    required this.builder,
    this.senderId,
    this.outgoing = false,
    this.isMessage = true,
  });
  final String id;
  final DateTime timestamp;
  final Object? senderId;
  final bool outgoing, isMessage;
  final Widget Function(BuildContext, UiChatMessageGrouping) builder;
}

/// Conversation history composition using the existing anchor-preserving
/// scroller. Items are oldest-first and retain their application IDs. Supply
/// localized loading/empty/error and typing surfaces; state is application-owned.
class UiChatTimeline extends StatelessWidget {
  const UiChatTimeline({
    super.key,
    required this.items,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.typing,
    this.loading = false,
    this.loadingState,
    this.emptyState,
    this.errorState,
    this.onLoadEarlier,
    this.initialUnreadMessageId,
    this.unreadMarkerLabel = 'Unread messages',
    this.scrollControlsBuilder,
    this.autoFollow = true,
  }) : entries = null,
       dateLabelBuilder = null;

  /// Composes chronological entries with neighboring sender/day/minute rules.
  /// A date label builder adds markers automatically; omit it only when the
  /// application's event rendering already supplies those markers.
  const UiChatTimeline.messages({
    super.key,
    required this.entries,
    this.dateLabelBuilder,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.typing,
    this.loading = false,
    this.loadingState,
    this.emptyState,
    this.errorState,
    this.onLoadEarlier,
    this.initialUnreadMessageId,
    this.unreadMarkerLabel = 'Unread messages',
    this.scrollControlsBuilder,
    this.autoFollow = true,
  }) : items = const [];

  final List<UiChatTimelineEntry>? entries;
  final String Function(DateTime)? dateLabelBuilder;
  final List<UiMessageScrollerItem> items;
  final UiMessageScrollerController? controller;
  final EdgeInsetsGeometry padding;
  final Widget? typing, loadingState, emptyState, errorState;
  final bool loading, autoFollow;
  final Future<void> Function()? onLoadEarlier;
  final String? initialUnreadMessageId;
  final String unreadMarkerLabel;
  final Widget Function(BuildContext, UiMessageScrollerController)?
  scrollControlsBuilder;

  UiMessageScrollerItem _projectEntry(
    List<UiChatTimelineEntry> entries,
    int index,
  ) {
    final entry = entries[index];
    final previous = index > 0 ? entries[index - 1] : null;
    final next = index + 1 < entries.length ? entries[index + 1] : null;
    bool sameSender(UiChatTimelineEntry? other) =>
        other != null &&
        other.isMessage &&
        entry.isMessage &&
        ((entry.outgoing && other.outgoing) ||
            (entry.outgoing == other.outgoing &&
                entry.senderId != null &&
                entry.senderId == other.senderId));
    final grouping = UiChatMessageGrouping.resolve(
      timestamp: entry.timestamp,
      previousTimestamp: previous?.timestamp,
      nextTimestamp: next?.isMessage == true ? next!.timestamp : null,
      samePreviousSender: sameSender(previous),
      sameNextSender: sameSender(next),
    );
    return UiMessageScrollerItem(
      id: entry.id,
      isOutgoing: entry.outgoing,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isMessage &&
                grouping.showDateMarker &&
                dateLabelBuilder != null)
              UiMarker(
                label: dateLabelBuilder!(entry.timestamp),
                variant: UiMarkerVariant.separator,
              ),
            entry.builder(context, grouping),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projected = entries;
    final history = projected == null
        ? items
        : [
            for (var i = 0; i < projected.length; i++)
              _projectEntry(projected, i),
          ];
    final state =
        errorState ??
        (loading
            ? loadingState
            : history.isEmpty
            ? emptyState
            : null);
    return Stack(
      children: [
        UiMessageScroller(
          controller: controller,
          padding: padding,
          itemSpacing: 0,
          autoFollow: autoFollow,
          onLoadEarlier: onLoadEarlier,
          initialUnreadMessageId: initialUnreadMessageId,
          unreadMarkerLabel: unreadMarkerLabel,
          scrollControlsBuilder: scrollControlsBuilder,
          items: [
            ...history,
            // Stable across typing updates; never replace the scroller to show
            // transient status, so anchors and reply navigation stay attached.
            if (typing != null)
              UiMessageScrollerItem(id: '__ui_chat_typing__', child: typing!),
          ],
        ),
        if (state != null) Positioned.fill(child: state),
      ],
    );
  }
}
