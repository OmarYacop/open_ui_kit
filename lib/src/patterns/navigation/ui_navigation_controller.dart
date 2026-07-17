import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ui_navigation_back_button.dart';
import 'ui_route_entry.dart';
import 'ui_route_spec.dart';

/// A typed, router-agnostic navigation stack controller.
///
/// Mirrors the `push<T>/pop(T?)` shape of Flutter's `Navigator` but works
/// on a `ValueListenable<List<UiRouteEntry>>` so Open UI Kit widgets can rebuild
/// declaratively. It is intentionally independent of
/// `NavigatorState`/routes so a screen can own a nested Open UI Kit navigator
/// without bleeding into the host app's router (go_router, auto_route…).
///
/// Typical usage:
///
/// ```dart
/// final home = UiRouteSpec<void, void>(
///   id: 'home',
///   title: 'Home',
///   builder: (context, _) => const HomePage(),
/// );
/// final detail = UiRouteSpec<int, String>(
///   id: 'detail',
///   title: 'Detail',
///   builder: (context, id) => DetailPage(id: id),
/// );
///
/// final controller = UiNavigationController(routes: [home, detail]);
/// controller.go(home);
/// final note = await controller.push(detail, args: 42);
/// ```
class UiNavigationController {
  UiNavigationController({
    required List<UiRouteSpec<dynamic, dynamic>> routes,
    UiRouteSpec<dynamic, dynamic>? initialRoute,
    Object? initialArgs,
  })  : assert(routes.isNotEmpty, 'At least one route must be registered'),
        _routes = {for (final r in routes) r.id: r} {
    final seed = initialRoute ?? routes.first;
    final entry = UiRouteEntry(
      id: seed.id,
      args: initialArgs,
      title: seed.resolveTitle(initialArgs),
    );
    _stack = ValueNotifier<List<UiRouteEntry>>([entry]);
  }

  final Map<String, UiRouteSpec<dynamic, dynamic>> _routes;
  late final ValueNotifier<List<UiRouteEntry>> _stack;

  /// Listenable stack; last entry is the visible route.
  ValueListenable<List<UiRouteEntry>> get stackListenable => _stack;

  /// Immutable snapshot of the current stack.
  List<UiRouteEntry> get stack => _stack.value;

  /// Currently displayed entry.
  UiRouteEntry? get current => stack.isEmpty ? null : stack.last;

  /// `true` when there's more than one entry on the stack.
  bool get canPop => stack.length > 1;

  /// Route specs keyed by id.
  Map<String, UiRouteSpec<dynamic, dynamic>> get routes =>
      Map.unmodifiable(_routes);

  UiRouteSpec<dynamic, dynamic>? specFor(String id) => _routes[id];

  /// Push [spec] onto the stack with typed [args]. Returns a future that
  /// resolves when the pushed entry is popped.
  Future<TResult?> push<TArgs, TResult>(
    UiRouteSpec<TArgs, TResult> spec, {
    TArgs? args,
  }) {
    _assertRegistered(spec);
    _assertArgsType<TArgs>(spec, args);
    final completer = Completer<Object?>();
    final entry = UiRouteEntry(
      id: spec.id,
      args: args,
      title: spec.resolveTitle(args),
      completer: completer,
    );
    _stack.value = [...stack, entry];
    return completer.future.then((v) => v as TResult?);
  }

  /// Replace the top of the stack. The replaced entry's pending future
  /// resolves with `null`.
  Future<TResult?> replace<TArgs, TResult>(
    UiRouteSpec<TArgs, TResult> spec, {
    TArgs? args,
  }) {
    _assertRegistered(spec);
    _assertArgsType<TArgs>(spec, args);
    final completer = Completer<Object?>();
    final entry = UiRouteEntry(
      id: spec.id,
      args: args,
      title: spec.resolveTitle(args),
      completer: completer,
    );
    if (stack.isEmpty) {
      _stack.value = [entry];
    } else {
      final removed = stack.last;
      removed.completer?.complete(null);
      _stack.value = [...stack.take(stack.length - 1), entry];
    }
    return completer.future.then((v) => v as TResult?);
  }

  /// Pop the top of the stack, optionally resolving its pending future
  /// with [result]. Returns `true` when a pop actually happened.
  bool pop<TResult>([TResult? result]) {
    if (!canPop) return false;
    final removed = stack.last;
    removed.completer?.complete(result);
    _stack.value = stack.sublist(0, stack.length - 1);
    return true;
  }

  /// Pop repeatedly until the topmost entry has the given [routeId].
  void popUntil(String routeId) {
    final idx = stack.lastIndexWhere((e) => e.id == routeId);
    if (idx < 0) return;
    while (stack.length - 1 > idx) {
      pop<dynamic>();
    }
  }

  /// Pop every entry off and push [spec] as the single remaining route.
  /// Any pending futures resolve with `null`.
  Future<TResult?> go<TArgs, TResult>(
    UiRouteSpec<TArgs, TResult> spec, {
    TArgs? args,
  }) {
    _assertRegistered(spec);
    _assertArgsType<TArgs>(spec, args);
    for (final e in stack) {
      e.completer?.complete(null);
    }
    final completer = Completer<Object?>();
    final entry = UiRouteEntry(
      id: spec.id,
      args: args,
      title: spec.resolveTitle(args),
      completer: completer,
    );
    _stack.value = [entry];
    return completer.future.then((v) => v as TResult?);
  }

  /// Pop back to [entry] (must already be on the stack). Useful when
  /// acting on a history-menu selection.
  void popTo(UiRouteEntry entry) {
    final idx = stack.indexOf(entry);
    if (idx < 0) return;
    while (stack.length - 1 > idx) {
      pop<dynamic>();
    }
  }

  /// Entries *behind* the current top, newest first — the shape a
  /// long-press-back history menu wants.
  List<UiNavigationBackHistoryItem> historyItems() {
    if (stack.length <= 1) return const [];
    final prior = stack.sublist(0, stack.length - 1).reversed;
    return [
      for (final e in prior)
        UiNavigationBackHistoryItem(
          title: e.displayTitle,
          value: e,
        ),
    ];
  }

  void dispose() {
    for (final e in stack) {
      e.completer?.complete(null);
    }
    _stack.dispose();
  }

  void _assertRegistered(UiRouteSpec<dynamic, dynamic> spec) {
    assert(
      _routes[spec.id] != null,
      'Route "${spec.id}" was not registered on this controller. '
      'Add it to the `routes` list when constructing the controller.',
    );
  }

  void _assertArgsType<TArgs>(
    UiRouteSpec<dynamic, dynamic> spec,
    Object? args,
  ) {
    if (TArgs == _typeOf<void>()) {
      assert(
        args == null,
        'Route "${spec.id}" is typed <void, _> but received non-null args.',
      );
      return;
    }
    if (args != null) {
      assert(
        args is TArgs,
        'Route "${spec.id}" expected args of type $TArgs but got '
        '${args.runtimeType}.',
      );
    }
  }

  static Type _typeOf<T>() => T;
}
