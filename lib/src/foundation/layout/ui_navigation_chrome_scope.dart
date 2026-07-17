import 'package:flutter/widgets.dart';

/// Describes the persistent navigation chrome surrounding a page body.
///
/// Page-level components use this scope to avoid stacking another floating or
/// glass navigation surface next to a persistent rail.
class UiNavigationChromeScope extends InheritedWidget {
  const UiNavigationChromeScope({
    super.key,
    required this.hasPersistentRail,
    required super.child,
  });

  final bool hasPersistentRail;

  static bool hasPersistentRailOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<UiNavigationChromeScope>()
            ?.hasPersistentRail ??
        false;
  }

  @override
  bool updateShouldNotify(UiNavigationChromeScope oldWidget) {
    return oldWidget.hasPersistentRail != hasPersistentRail;
  }
}
