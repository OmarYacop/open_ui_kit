import 'dart:async';

import 'package:flutter/widgets.dart';

/// A single entry on a [UiNavigationController] stack.
///
/// Stack entries are immutable snapshots; the controller replaces the
/// list-valued listenable with a new list when the stack changes so
/// `ValueListenableBuilder` rebuilds cleanly. The private [completer]
/// is what the controller uses to complete the `Future` returned by
/// `push` when the entry is popped with a result.
@immutable
class UiRouteEntry {
  const UiRouteEntry({
    required this.id,
    this.args,
    this.title,
    this.completer,
  });

  /// Route identifier — matches the [UiRouteSpec.id] that built it.
  final String id;

  /// Typed payload that was passed to `push`. `null` for arg-less routes.
  final Object? args;

  /// Display label for history menus. Falls back to [id].
  final String? title;

  /// The completer that resolves when this entry is popped.
  ///
  /// Exposed as a getter so test code can assert on it, but the
  /// controller owns completion — callers should await the `Future`
  /// returned by `push` instead of touching this directly.
  final Completer<Object?>? completer;

  String get displayTitle => title ?? id;
}
