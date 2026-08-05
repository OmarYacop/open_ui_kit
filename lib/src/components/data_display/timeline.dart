import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../feedback/badge.dart';
import '../forms/button.dart';
import 'avatar.dart';

/// Semantic color and icon treatment for a timeline event marker.
enum UiTimelineTone { neutral, success, warning, error, info }

/// Selects whether an event uses its actor avatar or its status icon.
enum UiTimelineMarker { automatic, actor, icon }

/// A person or system identity associated with a timeline event.
@immutable
class UiTimelineActor {
  const UiTimelineActor({
    required this.name,
    this.avatarUrl,
    this.avatar,
    this.initials,
    this.semanticLabel,
  });

  final String name;
  final String? avatarUrl;
  final Widget? avatar;
  final String? initials;
  final String? semanticLabel;
}

/// A compact label attached to a timeline event.
@immutable
class UiTimelineTag {
  const UiTimelineTag({
    required this.label,
    this.intent = UiIntent.secondary,
    this.onPressed,
  });

  final String label;
  final UiIntent intent;
  final VoidCallback? onPressed;
}

/// A before/after value shown within a timeline event.
@immutable
class UiTimelineChange {
  const UiTimelineChange({
    this.label,
    this.from,
    this.to,
    this.fromIntent = UiIntent.neutral,
    this.toIntent = UiIntent.secondary,
    this.fromIcon,
    this.toIcon,
  });

  final String? label;
  final String? from;
  final String? to;
  final UiIntent fromIntent;
  final UiIntent toIntent;
  final Widget? fromIcon;
  final Widget? toIcon;
}

/// Immutable content model for one [UiTimeline] entry.
@immutable
class UiTimelineEvent {
  const UiTimelineEvent({
    required this.id,
    required this.at,
    required this.title,
    this.actor,
    this.description,
    this.messageTitle,
    this.messageBody,
    this.changes = const [],
    this.tags = const [],
    this.tone = UiTimelineTone.neutral,
    this.icon,
    this.marker = UiTimelineMarker.automatic,
  });

  final Object id;
  final DateTime at;
  final String title;
  final UiTimelineActor? actor;
  final String? description;
  final String? messageTitle;
  final String? messageBody;
  final List<UiTimelineChange> changes;
  final List<UiTimelineTag> tags;
  final UiTimelineTone tone;
  final Widget? icon;
  final UiTimelineMarker marker;
}

typedef UiTimelineDateLabelBuilder = String Function(DateTime date);
typedef UiTimelineTimeLabelBuilder = String Function(DateTime date);
typedef UiTimelineLoadMoreLabelBuilder = String Function(int remaining);

/// A grouped, reverse-chronological activity timeline.
///
/// Events are grouped by their UTC calendar day. Use [dayTotals] together with
/// [onLoadMore] to progressively reveal older events within individual days.
/// Date and time label builders make the component localization-friendly
/// without imposing an internationalization package on applications.
class UiTimeline extends StatelessWidget {
  const UiTimeline({
    super.key,
    required this.events,
    this.emptyText = 'No activity yet.',
    this.dayTotals = const {},
    this.loadingDay,
    this.onLoadMore,
    this.loadMoreLabelBuilder,
    this.dateLabelBuilder,
    this.timeLabelBuilder,
    this.defaultMessageTitle = 'Message',
    this.now,
  });

  final List<UiTimelineEvent> events;
  final String emptyText;

  /// Total event count keyed by the UTC `YYYY-MM-DD` day.
  final Map<String, int> dayTotals;
  final String? loadingDay;
  final ValueChanged<String>? onLoadMore;
  final UiTimelineLoadMoreLabelBuilder? loadMoreLabelBuilder;
  final UiTimelineDateLabelBuilder? dateLabelBuilder;
  final UiTimelineTimeLabelBuilder? timeLabelBuilder;
  final String defaultMessageTitle;

  /// Clock override used by relative day labels and deterministic tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final groups = _groupEvents(events);
    if (groups.isEmpty) return _EmptyTimeline(label: emptyText);

    final tokens = UiThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < groups.length; index += 1) ...[
          if (index > 0) SizedBox(height: tokens.spacing.x4),
          _TimelineGroupView(
            group: groups[index],
            dayTotal: dayTotals[groups[index].key],
            loading: loadingDay == groups[index].key,
            onLoadMore: onLoadMore,
            loadMoreLabelBuilder: loadMoreLabelBuilder,
            dateLabel: _dateLabel(groups[index].date),
            timeLabelBuilder: timeLabelBuilder ?? _defaultTimeLabel,
            defaultMessageTitle: defaultMessageTitle,
          ),
        ],
      ],
    );
  }

  String _dateLabel(DateTime date) {
    if (dateLabelBuilder != null) return dateLabelBuilder!(date);
    final current = (now ?? DateTime.now()).toUtc();
    final day = date.toUtc();
    final today = DateTime.utc(current.year, current.month, current.day);
    final eventDay = DateTime.utc(day.year, day.month, day.day);
    final difference = today.difference(eventDay).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${_months[day.month - 1]} ${day.day}, ${day.year}';
  }

  static List<_TimelineGroup> _groupEvents(List<UiTimelineEvent> events) {
    final sorted = [...events]..sort((a, b) => b.at.compareTo(a.at));
    final groups = <String, _TimelineGroup>{};
    for (final event in sorted) {
      final utc = event.at.toUtc();
      final key = _dayKey(utc);
      groups.putIfAbsent(
        key,
        () => _TimelineGroup(
          key: key,
          date: DateTime.utc(utc.year, utc.month, utc.day),
          events: [],
        ),
      );
      groups[key]!.events.add(event);
    }
    return groups.values.toList(growable: false);
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _defaultTimeLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}

class _TimelineGroup {
  _TimelineGroup({required this.key, required this.date, required this.events});

  final String key;
  final DateTime date;
  final List<UiTimelineEvent> events;
}

class _TimelineGroupView extends StatelessWidget {
  const _TimelineGroupView({
    required this.group,
    required this.dateLabel,
    required this.loading,
    required this.timeLabelBuilder,
    required this.defaultMessageTitle,
    this.dayTotal,
    this.onLoadMore,
    this.loadMoreLabelBuilder,
  });

  final _TimelineGroup group;
  final String dateLabel;
  final int? dayTotal;
  final bool loading;
  final ValueChanged<String>? onLoadMore;
  final UiTimelineLoadMoreLabelBuilder? loadMoreLabelBuilder;
  final UiTimelineTimeLabelBuilder timeLabelBuilder;
  final String defaultMessageTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final remaining = ((dayTotal ?? group.events.length) - group.events.length)
        .clamp(0, 1 << 31);
    final canLoadMore = remaining > 0 && onLoadMore != null;

    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UiText(
                dateLabel,
                variant: UiTextVariant.caption,
                tone: UiTextTone.muted,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(width: tokens.spacing.x3),
              Expanded(
                  child: Container(height: 1, color: tokens.colors.border)),
            ],
          ),
          SizedBox(height: tokens.spacing.x3),
          for (var index = 0; index < group.events.length; index += 1)
            _TimelineEventView(
              key: ValueKey(group.events[index].id),
              event: group.events[index],
              timeLabel: timeLabelBuilder(group.events[index].at),
              defaultMessageTitle: defaultMessageTitle,
              showConnector: index < group.events.length - 1 || canLoadMore,
            ),
          if (canLoadMore)
            _LoadMore(
              remaining: remaining,
              loading: loading,
              labelBuilder: loadMoreLabelBuilder,
              onPressed: () => onLoadMore!(group.key),
            ),
        ],
      ),
    );
  }
}

class _TimelineEventView extends StatelessWidget {
  const _TimelineEventView({
    super.key,
    required this.event,
    required this.timeLabel,
    required this.showConnector,
    required this.defaultMessageTitle,
  });

  final UiTimelineEvent event;
  final String timeLabel;
  final bool showConnector;
  final String defaultMessageTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                SizedBox(
                  width: 72,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: tokens.spacing.x2,
                      end: tokens.spacing.x3,
                    ),
                    child: UiText(
                      timeLabel,
                      variant: UiTextVariant.caption,
                      tone: UiTextTone.muted,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    _TimelineMarker(event: event),
                    if (showConnector)
                      Expanded(
                        child: Container(
                          width: 1,
                          constraints: const BoxConstraints(minHeight: 16),
                          color: tokens.colors.border,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.x3),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    top: tokens.spacing.x2,
                    bottom: tokens.spacing.x3,
                  ),
                  child: _TimelineEventContent(
                    event: event,
                    timeLabel: compact ? timeLabel : null,
                    defaultMessageTitle: defaultMessageTitle,
                    compact: compact,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineMarker extends StatelessWidget {
  const _TimelineMarker({required this.event});

  final UiTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final actor = event.actor;
    final useActor = actor != null &&
        event.marker != UiTimelineMarker.icon &&
        (event.marker == UiTimelineMarker.actor ||
            event.marker == UiTimelineMarker.automatic);

    if (useActor) {
      return ExcludeSemantics(
        child: UiAvatar(
          name: actor.name,
          imageUrl: actor.avatarUrl,
          image: actor.avatar,
          fallback: actor.initials == null
              ? null
              : UiText(actor.initials!, variant: UiTextVariant.caption),
          semanticLabel: actor.semanticLabel ?? actor.name,
          size: 32,
        ),
      );
    }

    final tokens = UiThemeTokens.of(context);
    final colors = _markerColors(event.tone, tokens);
    return ExcludeSemantics(
      child: UiBox(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        background: colors.$2,
        border: Border.all(color: colors.$1.withValues(alpha: 0.35)),
        borderRadius: tokens.radius.pillAll,
        child: IconTheme.merge(
          data: IconThemeData(size: 15, color: colors.$1),
          child: event.icon ?? Icon(_toneIcon(event.tone)),
        ),
      ),
    );
  }

  static (Color, Color) _markerColors(
    UiTimelineTone tone,
    UiThemeTokens tokens,
  ) {
    final colors = tokens.colors;
    final foreground = switch (tone) {
      UiTimelineTone.success => colors.success,
      UiTimelineTone.warning => colors.warning,
      UiTimelineTone.error => colors.danger,
      UiTimelineTone.info => colors.primary,
      UiTimelineTone.neutral => colors.textMuted,
    };
    return (foreground, foreground.withValues(alpha: 0.10));
  }

  static IconData _toneIcon(UiTimelineTone tone) => switch (tone) {
        UiTimelineTone.success => LucideIcons.circleCheck,
        UiTimelineTone.warning => LucideIcons.circleAlert,
        UiTimelineTone.error => LucideIcons.circleAlert,
        UiTimelineTone.info => LucideIcons.info,
        UiTimelineTone.neutral => LucideIcons.clock3,
      };
}

class _TimelineEventContent extends StatelessWidget {
  const _TimelineEventContent({
    required this.event,
    required this.defaultMessageTitle,
    required this.compact,
    this.timeLabel,
  });

  final UiTimelineEvent event;
  final String defaultMessageTitle;
  final bool compact;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final inlineChange = event.changes.length == 1 &&
            _isBlank(event.changes.single.label) &&
            (!_isBlank(event.changes.single.from) ||
                !_isBlank(event.changes.single.to))
        ? event.changes.single
        : null;

    final sections = <Widget>[
      if (timeLabel != null)
        UiText(
          timeLabel!,
          variant: UiTextVariant.caption,
          tone: UiTextTone.muted,
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      Wrap(
        spacing: tokens.spacing.x1,
        runSpacing: tokens.spacing.x1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (event.actor != null)
            UiText(
              event.actor!.name,
              variant: UiTextVariant.bodySm,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          UiText(
            _titleWithoutActorPrefix(event.title, event.actor?.name),
            variant: UiTextVariant.bodySm,
            style: event.actor == null
                ? const TextStyle(fontWeight: FontWeight.w500)
                : null,
          ),
          if (inlineChange != null) ..._changeWidgets(context, inlineChange),
        ],
      ),
      if (event.tags.isNotEmpty)
        Wrap(
          spacing: tokens.spacing.x2,
          runSpacing: tokens.spacing.x1,
          children: [for (final tag in event.tags) _TimelineTagView(tag: tag)],
        ),
      if (event.changes.isNotEmpty && inlineChange == null)
        _TimelineChangeList(changes: event.changes, stacked: compact),
      if (!_isBlank(event.messageBody))
        _MessageCallout(
          event: event,
          defaultMessageTitle: defaultMessageTitle,
        ),
      if (!_isBlank(event.description))
        UiText(
          event.description!,
          variant: UiTextVariant.caption,
          tone: UiTextTone.muted,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index += 1) ...[
          if (index > 0) SizedBox(height: tokens.spacing.x2),
          sections[index],
        ],
      ],
    );
  }

  static List<Widget> _changeWidgets(
    BuildContext context,
    UiTimelineChange change,
  ) {
    return [
      if (!_isBlank(change.from))
        UiBadge(
          label: change.from!,
          intent: change.fromIntent,
          outlined: true,
          leading: change.fromIcon,
          borderRadius: UiThemeTokens.of(context).radius.mdAll,
        ),
      if (!_isBlank(change.from) && !_isBlank(change.to))
        Icon(
          UiDirectionalIcons.chevronForward(context),
          size: 13,
          color: UiThemeTokens.of(context).colors.textMuted,
        ),
      if (!_isBlank(change.to))
        UiBadge(
          label: change.to!,
          intent: change.toIntent,
          leading: change.toIcon,
          borderRadius: UiThemeTokens.of(context).radius.mdAll,
        ),
    ];
  }

  static bool _isBlank(String? value) => value == null || value.trim().isEmpty;

  static String _titleWithoutActorPrefix(String title, String? actorName) {
    if (_isBlank(actorName)) return title.trim();
    final trimmed = title.trim();
    final name = actorName!.trim();
    if (trimmed.length <= name.length ||
        trimmed.substring(0, name.length).toLowerCase() != name.toLowerCase()) {
      return trimmed;
    }
    final rest = trimmed.substring(name.length);
    return rest.isNotEmpty && rest[0].trim().isEmpty
        ? rest.trimLeft()
        : trimmed;
  }
}

class _TimelineChangeList extends StatelessWidget {
  const _TimelineChangeList({
    required this.changes,
    required this.stacked,
  });

  final List<UiTimelineChange> changes;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final labelled = changes.where(
      (change) => !_TimelineEventContent._isBlank(change.label),
    );

    if (labelled.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < changes.length; index += 1) ...[
            if (index > 0) SizedBox(height: tokens.spacing.x2),
            Wrap(
              spacing: tokens.spacing.x2,
              runSpacing: tokens.spacing.x1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _TimelineEventContent._changeWidgets(
                context,
                changes[index],
              ),
            ),
          ],
        ],
      );
    }

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < changes.length; index += 1) ...[
            if (index > 0) SizedBox(height: tokens.spacing.x2),
            if (!_TimelineEventContent._isBlank(changes[index].label))
              UiText(
                changes[index].label!,
                variant: UiTextVariant.caption,
                tone: UiTextTone.muted,
              ),
            SizedBox(height: tokens.spacing.x1),
            _ChangeValue(change: changes[index]),
          ],
        ],
      );
    }

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(104),
        1: FixedColumnWidth(tokens.spacing.x3),
        2: const FlexColumnWidth(),
      },
      children: [
        for (var index = 0; index < changes.length; index += 1)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: index == changes.length - 1 ? 0 : tokens.spacing.x2,
                ),
                child: _TimelineEventContent._isBlank(changes[index].label)
                    ? const SizedBox.shrink()
                    : UiText(
                        changes[index].label!,
                        variant: UiTextVariant.caption,
                        tone: UiTextTone.muted,
                        maxLines: 2,
                      ),
              ),
              const SizedBox.shrink(),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: index == changes.length - 1 ? 0 : tokens.spacing.x2,
                ),
                child: _ChangeValue(change: changes[index]),
              ),
            ],
          ),
      ],
    );
  }
}

class _ChangeValue extends StatelessWidget {
  const _ChangeValue({required this.change});

  final UiTimelineChange change;

  @override
  Widget build(BuildContext context) {
    final widgets = _TimelineEventContent._changeWidgets(context, change);
    if (widgets.isEmpty) {
      return const UiText(
        '—',
        variant: UiTextVariant.caption,
        tone: UiTextTone.muted,
      );
    }

    final tokens = UiThemeTokens.of(context);
    return Wrap(
      spacing: tokens.spacing.x2,
      runSpacing: tokens.spacing.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}

class _TimelineTagView extends StatelessWidget {
  const _TimelineTagView({required this.tag});

  final UiTimelineTag tag;

  @override
  Widget build(BuildContext context) {
    if (tag.onPressed == null) {
      return UiBadge(label: tag.label, intent: tag.intent);
    }

    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: tag.onPressed,
      semanticsLabel: tag.label,
      minTapSize: 44,
      builder: (context, state, _) => UiFocusRing(
        visible: state.focused,
        borderRadius: tokens.radius.pillAll,
        child: Opacity(
          opacity: state.pressed ? 0.72 : 1,
          child: UiBadge(label: tag.label, intent: tag.intent),
        ),
      ),
    );
  }
}

class _MessageCallout extends StatelessWidget {
  const _MessageCallout({
    required this.event,
    required this.defaultMessageTitle,
  });

  final UiTimelineEvent event;
  final String defaultMessageTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiBox(
      background: tokens.colors.surfaceMuted.withValues(alpha: 0.55),
      border: Border.all(color: tokens.colors.border),
      borderRadius: tokens.radius.lgAll,
      padding: EdgeInsets.all(tokens.spacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiText(
            _TimelineEventContent._isBlank(event.messageTitle)
                ? defaultMessageTitle
                : event.messageTitle!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: tokens.spacing.x1),
          UiText(event.messageBody!, variant: UiTextVariant.bodySm),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.remaining,
    required this.loading,
    required this.onPressed,
    this.labelBuilder,
  });

  final int remaining;
  final bool loading;
  final VoidCallback onPressed;
  final UiTimelineLoadMoreLabelBuilder? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final label = labelBuilder?.call(remaining) ?? '$remaining more';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Padding(
          padding: EdgeInsetsDirectional.only(
            start: (compact ? 0 : 72) + 32 + tokens.spacing.x3,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: UiButton(
              label: label,
              intent: UiIntent.link,
              size: UiSize.sm,
              loading: loading,
              showBorder: false,
              onPressed: onPressed,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Semantics(
      container: true,
      label: label,
      child: UiBox(
        border: Border.all(color: tokens.colors.border),
        borderRadius: tokens.radius.xlAll,
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.x8),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: UiText(
            label,
            variant: UiTextVariant.bodySm,
            tone: UiTextTone.muted,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
