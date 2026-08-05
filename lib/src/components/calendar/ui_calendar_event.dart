import 'package:flutter/foundation.dart';

@immutable

/// A dated event rendered by Open UI calendar components.
class UiCalendarEvent {
  const UiCalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.subtitle,
    this.metadata,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? metadata;
  final DateTime startAt;
  final DateTime endAt;
}
