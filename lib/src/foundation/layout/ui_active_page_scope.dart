import 'package:flutter/widgets.dart';

/// Marks whether the enclosing page is the *active* page of a preserved
/// page stack (for example the selected tab of a bottom tab scaffold).
///
/// `IndexedStack`-style hosts keep inactive pages mounted, so ancestors such
/// as navigation bars keep building. Anything that publishes per-route state
/// from `build` (history titles, system bars) should check [isActiveOf] so
/// hidden pages do not overwrite the visible one.
class UiActivePageScope extends InheritedWidget {
  const UiActivePageScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  /// `true` when no scope is present.
  static bool isActiveOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<UiActivePageScope>()
            ?.active ??
        true;
  }

  @override
  bool updateShouldNotify(UiActivePageScope oldWidget) =>
      oldWidget.active != active;
}
