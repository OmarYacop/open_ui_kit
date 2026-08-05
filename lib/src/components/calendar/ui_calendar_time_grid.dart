import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/tokens/ui_color_tokens.dart';
import 'ui_calendar_event.dart';

typedef UiCalendarTimeLabelBuilder = String Function(int hour);
typedef UiCalendarDayHeaderBuilder = Widget Function(
  BuildContext context,
  DateTime day,
  bool isToday,
);

/// Token-driven, platform-neutral calendar time grid.
///
/// The component owns time geometry, overlapping-event columns, selection,
/// current-time presentation, and accessible press states. Products retain
/// control of date formatting, headers, and event content through data.
class UiCalendarTimeGrid extends StatelessWidget {
  const UiCalendarTimeGrid({
    super.key,
    required this.days,
    required this.events,
    required this.timeLabelBuilder,
    required this.dayHeaderBuilder,
    this.selectedEventId,
    this.onEventPressed,
    this.now,
    this.startHour = 0,
    this.endHour = 24,
    this.hourHeight = 72,
    this.timeRailWidth = 64,
    this.minimumDayWidth = 126,
    this.showDayHeaders = true,
    this.showDayDividers = true,
  })  : assert(endHour > startHour),
        assert(days.length > 0);

  final List<DateTime> days;
  final List<UiCalendarEvent> events;
  final UiCalendarTimeLabelBuilder timeLabelBuilder;
  final UiCalendarDayHeaderBuilder dayHeaderBuilder;
  final String? selectedEventId;
  final ValueChanged<UiCalendarEvent>? onEventPressed;
  final DateTime? now;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeRailWidth;
  final double minimumDayWidth;
  final bool showDayHeaders;

  /// Paints vertical boundaries between days. Phone day views generally keep
  /// this false; full tablet week views generally keep it true.
  final bool showDayDividers;

  @override
  Widget build(BuildContext context) {
    const verticalInset = 10.0;
    final height = (endHour - startHour) * hourHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = math.max(
          viewportWidth,
          timeRailWidth + minimumDayWidth * days.length,
        );
        final dayWidth = (contentWidth - timeRailWidth) / days.length;
        final layouts = _layoutEvents(dayWidth);

        final content = SizedBox(
          width: contentWidth,
          child: Column(
            children: [
              if (showDayHeaders)
                SizedBox(
                  height: 62,
                  child: Row(
                    children: [
                      SizedBox(width: timeRailWidth),
                      for (final day in days)
                        SizedBox(
                          width: dayWidth,
                          child: dayHeaderBuilder(
                            context,
                            day,
                            _sameDay(day, now ?? DateTime.now()),
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                height: height + verticalInset * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: verticalInset,
                      bottom: verticalInset,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        painter: _CalendarGridPainter(
                          colors: UiThemeTokens.colorsOf(context),
                          dayCount: days.length,
                          startHour: startHour,
                          endHour: endHour,
                          hourHeight: hourHeight,
                          timeRailWidth: timeRailWidth,
                          showDayDividers: showDayDividers,
                        ),
                      ),
                    ),
                    for (var hour = startHour; hour <= endHour; hour++)
                      PositionedDirectional(
                        top:
                            verticalInset + (hour - startHour) * hourHeight - 7,
                        start: 0,
                        width: timeRailWidth,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: _CalendarTimeLabel(
                            label: timeLabelBuilder(hour),
                          ),
                        ),
                      ),
                    for (final layout in layouts)
                      _PositionedCalendarEvent(
                        layout: layout.shiftedVertically(verticalInset),
                        selected: layout.event.id == selectedEventId,
                        onPressed: onEventPressed == null
                            ? null
                            : () => onEventPressed!(layout.event),
                      ),
                    if (_nowGeometry(dayWidth) case final geometry?)
                      Positioned(
                        left: geometry.left,
                        top: geometry.top + verticalInset,
                        width: geometry.width,
                        child: _CurrentTimeLine(
                          label: _currentTimeLabel(now!),
                          brightStart: geometry.brightStart,
                          brightWidth: geometry.brightWidth,
                          segmented: days.length > 1,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        return contentWidth <= viewportWidth
            ? content
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: content,
              );
      },
    );
  }

  List<_EventLayout> _layoutEvents(double dayWidth) {
    final result = <_EventLayout>[];
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final dayEvents = events
          .where((event) => _sameDay(event.startAt, days[dayIndex]))
          .toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      final clusters = _overlapClusters(dayEvents);
      for (final cluster in clusters) {
        final columnEnds = <DateTime>[];
        final columns = <UiCalendarEvent, int>{};
        for (final event in cluster) {
          var column = columnEnds.indexWhere(
            (end) => !end.isAfter(event.startAt),
          );
          if (column == -1) {
            column = columnEnds.length;
            columnEnds.add(event.endAt);
          } else {
            columnEnds[column] = event.endAt;
          }
          columns[event] = column;
        }
        final count = math.max(1, columnEnds.length);
        final columnWidth = (dayWidth - 6) / count;
        for (final event in cluster) {
          final start = event.startAt.hour + event.startAt.minute / 60;
          final minutes = event.endAt.difference(event.startAt).inMinutes;
          result.add(
            _EventLayout(
              event: event,
              left: timeRailWidth +
                  dayIndex * dayWidth +
                  3 +
                  columns[event]! * columnWidth,
              top: (start - startHour) * hourHeight,
              width: columnWidth - 2,
              height: math.max(34, minutes / 60 * hourHeight - 2),
            ),
          );
        }
      }
    }
    return result;
  }

  _NowGeometry? _nowGeometry(double dayWidth) {
    final value = now;
    if (value == null) return null;
    final dayIndex = days.indexWhere((day) => _sameDay(day, value));
    final decimalHour = value.hour + value.minute / 60;
    if (dayIndex < 0 || decimalHour < startHour || decimalHour > endHour) {
      return null;
    }
    return _NowGeometry(
      left: 0,
      top: (decimalHour - startHour) * hourHeight,
      width: timeRailWidth + dayWidth * days.length,
      brightStart: timeRailWidth + dayIndex * dayWidth,
      brightWidth: dayWidth,
    );
  }
}

class _CalendarTimeLabel extends StatelessWidget {
  const _CalendarTimeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = UiThemeTokens.colorsOf(context);
    final match = RegExp(r'^(.+?)\s+(AM|PM)$', caseSensitive: false)
        .firstMatch(label.trim());
    final hour = match?.group(1) ?? label;
    final period = match?.group(2);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: hour,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (period != null)
            TextSpan(
              text: ' $period',
              style: TextStyle(
                color: colors.textMuted.withValues(alpha: .72),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.end,
      maxLines: 1,
    );
  }
}

class _PositionedCalendarEvent extends StatelessWidget {
  const _PositionedCalendarEvent({
    required this.layout,
    required this.selected,
    this.onPressed,
  });

  final _EventLayout layout;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final event = layout.event;
    return Positioned(
      left: layout.left,
      top: layout.top,
      width: layout.width,
      height: layout.height,
      child: UiPressable(
        onPressed: onPressed,
        minTapSize: 0,
        semanticsLabel: [event.title, event.subtitle, event.metadata]
            .whereType<String>()
            .join(', '),
        builder: (context, state, _) {
          final background = selected
              ? colors.primary
              : Color.alphaBlend(
                  colors.primary.withValues(alpha: .12),
                  colors.surface,
                );
          final foreground = selected ? colors.onPrimary : colors.primary;
          return AnimatedScale(
            scale: state.pressed ? .985 : 1,
            duration: const Duration(milliseconds: 90),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: tokens.radius.mdAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsetsDirectional.fromSTEB(5, 7, 0, 7),
                    decoration: BoxDecoration(
                      color: foreground,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(7, 6, 5, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: layout.height < 56 ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                          if (layout.height >= 52 && event.metadata != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                event.metadata!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground.withValues(alpha: .82),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (layout.height >= 78 && event.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                event.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground.withValues(alpha: .72),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({
    required this.label,
    required this.brightStart,
    required this.brightWidth,
    required this.segmented,
  });
  final String label;
  final double brightStart;
  final double brightWidth;
  final bool segmented;

  @override
  Widget build(BuildContext context) {
    final color = UiThemeTokens.colorsOf(context).danger;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: UiThemeTokens.colorsOf(context).onDanger,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!segmented) {
      return Transform.translate(
        offset: const Offset(0, -11),
        child: SizedBox(
          height: 22,
          child: Row(
            children: [
              badge,
              Expanded(child: Container(height: 1.5, color: color)),
            ],
          ),
        ),
      );
    }

    return Transform.translate(
      offset: const Offset(0, -11),
      child: SizedBox(
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  badge,
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: color.withValues(alpha: .20),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: brightStart,
              top: 10.25,
              width: brightWidth,
              child: Container(height: 1.5, color: color),
            ),
            Positioned(
              left: brightStart - 3,
              top: 7.5,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGridPainter extends CustomPainter {
  const _CalendarGridPainter({
    required this.colors,
    required this.dayCount,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.timeRailWidth,
    required this.showDayDividers,
  });
  final UiColorTokens colors;
  final int dayCount;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeRailWidth;
  final bool showDayDividers;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.border.withValues(alpha: .72)
      ..strokeWidth = .7;
    for (var hour = startHour; hour <= endHour; hour++) {
      final y = (hour - startHour) * hourHeight;
      canvas.drawLine(Offset(timeRailWidth, y), Offset(size.width, y), paint);
    }
    if (showDayDividers) {
      final dayWidth = (size.width - timeRailWidth) / dayCount;
      for (var day = 0; day <= dayCount; day++) {
        final x = timeRailWidth + day * dayWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarGridPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.dayCount != dayCount ||
      oldDelegate.startHour != startHour ||
      oldDelegate.endHour != endHour ||
      oldDelegate.hourHeight != hourHeight ||
      oldDelegate.timeRailWidth != timeRailWidth ||
      oldDelegate.showDayDividers != showDayDividers;
}

List<List<UiCalendarEvent>> _overlapClusters(List<UiCalendarEvent> events) {
  final clusters = <List<UiCalendarEvent>>[];
  DateTime? clusterEnd;
  for (final event in events) {
    if (clusters.isEmpty ||
        clusterEnd == null ||
        !event.startAt.isBefore(clusterEnd)) {
      clusters.add([event]);
      clusterEnd = event.endAt;
    } else {
      clusters.last.add(event);
      if (event.endAt.isAfter(clusterEnd)) clusterEnd = event.endAt;
    }
  }
  return clusters;
}

String _currentTimeLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _EventLayout {
  const _EventLayout({
    required this.event,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final UiCalendarEvent event;
  final double left;
  final double top;
  final double width;
  final double height;

  _EventLayout shiftedVertically(double offset) => _EventLayout(
        event: event,
        left: left,
        top: top + offset,
        width: width,
        height: height,
      );
}

class _NowGeometry {
  const _NowGeometry({
    required this.left,
    required this.top,
    required this.width,
    required this.brightStart,
    required this.brightWidth,
  });
  final double left;
  final double top;
  final double width;
  final double brightStart;
  final double brightWidth;
}
