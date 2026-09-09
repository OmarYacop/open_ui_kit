import 'package:flutter/widgets.dart';

import '../forms/icon_button.dart';
import 'bottom_tab_bar.dart';

/// Content identity shared by the expanding, paged, and legacy docks.
Object? bottomTabAccessoryIdentity(UiBottomTabAccessory? accessory) {
  if (accessory == null) return null;
  return (
    accessory.expanded,
    accessory.contentKey ?? _widgetIdentity(accessory.child),
  );
}

Object _widgetIdentity(Widget child) {
  if (child is UiIconButton) {
    return (child.runtimeType, child.key, _widgetIdentity(child.icon));
  }
  if (child is Icon) return (child.runtimeType, child.key, child.icon);
  // Like AnimatedSwitcher, custom widgets define content changes with a key.
  return (child.runtimeType, child.key);
}
