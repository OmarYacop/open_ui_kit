import 'package:flutter/widgets.dart';

import 'ui_navigation_controller.dart';
import 'ui_navigation_spec.dart';
import 'ui_route_entry.dart';

/// Exposes page-level navigation metadata to descendants.
class UiNavigationScope extends InheritedWidget {
  const UiNavigationScope({
    super.key,
    required this.spec,
    required super.child,
  });

  final UiNavigationSpec spec;

  static UiNavigationSpec? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UiNavigationScope>()
        ?.spec;
  }

  static UiNavigationSpec of(BuildContext context) {
    final spec = maybeOf(context);
    assert(spec != null, 'No UiNavigationScope found in context.');
    return spec!;
  }

  @override
  bool updateShouldNotify(covariant UiNavigationScope oldWidget) {
    return oldWidget.spec != spec;
  }
}

/// Runtime navigation context exposed by [UiNavigationHost].
///
/// Components can use this to access the current [UiRouteEntry] and
/// dynamic controller state (like history/back behavior) without passing
/// it through every page/widget constructor.
class UiNavigationControllerScope extends InheritedWidget {
  const UiNavigationControllerScope({
    super.key,
    required this.controller,
    required this.entry,
    required super.child,
  });

  final UiNavigationController controller;
  final UiRouteEntry entry;

  static UiNavigationControllerScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UiNavigationControllerScope>();
  }

  static UiNavigationControllerScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No UiNavigationControllerScope found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant UiNavigationControllerScope oldWidget) {
    return oldWidget.controller != controller || oldWidget.entry != entry;
  }
}
