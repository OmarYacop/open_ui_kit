import 'package:flutter/widgets.dart';

import 'ui_navigation_back_button.dart';

/// Tracks the full stack of top-level [PageRoute]s pushed through whichever
/// [Navigator] this observer is attached to, plus a title registered by
/// each page's own chrome — so [UiSliverNavigationBar]'s long-press-back
/// history menu can show the *entire* stack for apps using a plain Flutter
/// [Navigator] (`Navigator.push`/`pushNamed`), the same way
/// [UiNavigationControllerScope] already does for apps built on
/// [UiNavigationController].
///
/// [UiApp] installs and shares one of these automatically — most apps never
/// construct this directly. [UiSliverNavigationBar] registers its own
/// [UiNavigationSpec.title] against the current route on every build, so
/// history titles stay accurate without any additional app-side wiring.
///
/// Only [PageRoute]s are tracked, so a transient dialog or bottom sheet
/// pushed via `showDialog`/`showModalBottomSheet` never appears in — or
/// skews the pop-count arithmetic of — the history menu.
class UiNavigatorHistoryObserver extends NavigatorObserver with ChangeNotifier {
  final List<PageRoute<dynamic>> _stack = [];
  final Map<Route<dynamic>, String> _titles = {};

  /// Associates [title] with [route] so it can be shown in the history menu
  /// once [route] is behind the current top of stack. Safe to call on every
  /// build — a no-op when the title hasn't changed, and deliberately does
  /// *not* call [notifyListeners]: this is meant to be called from
  /// [UiSliverNavigationBar]'s own `build`, and notifying synchronously
  /// from inside another widget's build (which [InheritedNotifier] would
  /// turn into a synchronous rebuild request) is invalid. The title is
  /// still current by the time anything else reads [historyItems].
  void registerTitle(Route<dynamic> route, String title) {
    _titles[route] = title;
  }

  /// Entries *behind* the current top, newest first — the shape a
  /// long-press-back history menu wants. A route with no registered title
  /// and no [RouteSettings.name] is omitted from the menu but still counted
  /// toward the [UiNavigationBackPopTarget.count] of entries behind it, so
  /// selecting one of those still pops the correct number of times.
  List<UiNavigationBackHistoryItem> historyItems() {
    if (_stack.length <= 1) return const [];
    final items = <UiNavigationBackHistoryItem>[];
    for (var i = _stack.length - 2; i >= 0; i--) {
      final title = _titleFor(_stack[i]);
      if (title == null) continue;
      items.add(
        UiNavigationBackHistoryItem(
          title: title,
          value: UiNavigationBackPopTarget(_stack.length - 1 - i),
        ),
      );
    }
    return items;
  }

  String? _titleFor(Route<dynamic> route) =>
      _titles[route] ?? route.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      _stack.add(route);
      _scheduleNotify();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_removeFromStack(route)) _scheduleNotify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_removeFromStack(route)) _scheduleNotify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    var changed = false;
    if (oldRoute != null) changed = _removeFromStack(oldRoute) || changed;
    if (newRoute is PageRoute<dynamic>) {
      _stack.add(newRoute);
      changed = true;
    }
    if (changed) _scheduleNotify();
  }

  bool _removeFromStack(Route<dynamic> route) {
    _titles.remove(route);
    return _stack.remove(route);
  }

  // NavigatorObserver callbacks can fire mid-build — most notably the
  // very first `didPush`, which happens while the Navigator (a descendant
  // of UiNavigatorHistoryScope) is still being constructed inside the
  // same build pass that built the scope itself. Notifying an
  // InheritedNotifier's dependents synchronously at that point is invalid
  // ("setState during build"), so every notification is deferred to just
  // after the current frame instead.
  void _scheduleNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }
}

/// Exposes the [UiApp]-owned [UiNavigatorHistoryObserver] to descendants —
/// most directly [UiSliverNavigationBar], which reads it as a fallback
/// history source and registers each page's title against it.
class UiNavigatorHistoryScope
    extends InheritedNotifier<UiNavigatorHistoryObserver> {
  const UiNavigatorHistoryScope({
    super.key,
    required UiNavigatorHistoryObserver observer,
    required super.child,
  }) : super(notifier: observer);

  static UiNavigatorHistoryObserver? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<UiNavigatorHistoryScope>()
        ?.notifier;
  }
}
