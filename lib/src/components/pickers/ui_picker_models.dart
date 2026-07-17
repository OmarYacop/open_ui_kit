import 'package:flutter/widgets.dart';

/// Inclusive date range.
@immutable
class UiDateRange {
  const UiDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final a = DateTime(start.year, start.month, start.day);
    final b = DateTime(end.year, end.month, end.day);
    return !day.isBefore(a) && !day.isAfter(b);
  }

  @override
  bool operator ==(Object other) =>
      other is UiDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// 24-hour clock value (hour 0..23, minute 0..59).
@immutable
class UiTimeValue {
  const UiTimeValue({required this.hour, required this.minute})
      : assert(hour >= 0 && hour < 24, 'hour must be 0..23'),
        assert(minute >= 0 && minute < 60, 'minute must be 0..59');

  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;

  String formatted24() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String formatted12() {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h12:$m $suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is UiTimeValue && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Inclusive time range.
@immutable
class UiTimeRange {
  const UiTimeRange({required this.start, required this.end});

  final UiTimeValue start;
  final UiTimeValue end;

  @override
  bool operator ==(Object other) =>
      other is UiTimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Inclusive date-time range.
@immutable
class UiDateTimeRange {
  const UiDateTimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is UiDateTimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}
