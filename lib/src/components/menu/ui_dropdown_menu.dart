import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/tokens/ui_menu_tokens.dart';
import 'ui_menu_anchor.dart';

/// Base type for anything that can appear in a [UiDropdownMenu].
sealed class UiMenuNode {
  const UiMenuNode();
}

/// Single actionable row in the menu.
class UiMenuItem extends UiMenuNode {
  const UiMenuItem({
    required this.label,
    this.onPressed,
    this.leading,
    this.shortcut,
    this.enabled = true,
    this.destructive = false,
    this.loading = false,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final FutureOr<void> Function()? onPressed;
  final Widget? leading;

  /// Optional trailing shortcut glyph (e.g. `UiMenuShortcut('⌘K')`).
  final UiMenuShortcut? shortcut;
  final bool enabled;
  final bool destructive;
  final bool loading;
}

/// Shortcut display widget (kept alongside items, not an item itself).
@immutable
class UiMenuShortcut {
  const UiMenuShortcut(this.label);
  final String label;
}

/// Labelled cluster of items; renders an optional caption + items.
class UiMenuGroup extends UiMenuNode {
  const UiMenuGroup({this.label, required this.items});
  final String? label;
  final List<UiMenuItem> items;
}

/// Horizontal separator between groups/items.
class UiMenuSeparator extends UiMenuNode {
  const UiMenuSeparator();
}

/// Long-press / hover submenu. Rendered inline as a row that opens a
/// nested menu on tap.
class UiMenuSubmenu extends UiMenuNode {
  const UiMenuSubmenu({
    required this.label,
    required this.items,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final List<UiMenuNode> items;
  final Widget? leading;
  final bool enabled;
}

/// How an open menu responds when its anchor's ancestor scrollable moves.
enum UiMenuScrollBehavior { dismiss, followAnchor }

/// Dropdown menu surface and trigger.
///
/// The [trigger] widget is made tappable; on tap (and optionally long press)
/// an overlay with the [items] morphs from the trigger. When [openOnLongPress] is true,
/// the initiating pointer can drag across items and release to select one.
/// Keyboard users can move up/down through the rows and activate them with
/// Enter/Space.
class UiDropdownMenu extends StatefulWidget {
  const UiDropdownMenu({
    super.key,
    Widget? trigger,
    this.triggerBuilder,
    this.sourceBorderRadius,
    this.destinationOffset = Offset.zero,
    this.transitionDurationScale = 1,
    this.menuTokens,
    required this.items,
    this.title,
    this.backLabel,
    this.minWidth = 180,
    this.maxWidth = 280,
    this.openOnLongPress = true,
    this.closeOnSelect = true,
    this.dismissOnTapOutside = true,
    this.consumeOutsideTap = true,
    this.scrollBehavior = UiMenuScrollBehavior.dismiss,
  }) : trigger = trigger ?? const SizedBox.shrink(),
       assert(
         transitionDurationScale > 0 &&
             transitionDurationScale < double.infinity,
       ),
       assert(
         (trigger == null) != (triggerBuilder == null),
         'Provide either trigger or triggerBuilder.',
       );

  /// Optional spoken trigger label. Root menus do not render a heading.
  final String? title;

  /// Accessible label for submenu back navigation.
  final String? backLabel;
  final Widget trigger;

  /// Corner radii of the trigger, used at both ends of its morph. Defaults to
  /// a pill for compatibility. Pass the same radius used by the trigger button.
  /// Directional and asymmetric corners are supported.
  final BorderRadiusGeometry? sourceBorderRadius;

  /// Physical displacement of the expanded menu in logical pixels.
  /// Positive x moves right (also in RTL), positive y moves down. The trigger
  /// and return geometry stay fixed. Placement still respects safe bounds and
  /// the keyboard, and may flip above/below when the available space changes.
  final Offset destinationOffset;

  /// Scales the root press/open/close timeline; 1 preserves standard timing.
  /// Must be finite and positive. Reduced motion still takes precedence.
  /// Changing this value closes an open menu and recreates its controller.
  final double transitionDurationScale;

  /// Per-menu overrides shared by the trigger, root transition and submenus.
  /// Null inherits the theme. Use `UiThemeTokens.menuOf(context).copyWith(...)`
  /// to change springStrength, travelArc, pressExpansion, closeDuration,
  /// parentScale or surface effects while retaining other theme values.
  final UiMenuTokens? menuTokens;

  /// Builds an interactive button with the supplied menu-opening callback.
  /// Use `UiButton(onPressed: open, ...)` or `UiIconButton(onPressed: open, ...)`.
  /// The button owns tap/keyboard feedback; the menu retains hold-and-drag.
  /// [trigger] remains supported for existing passive trigger widgets.
  final Widget Function(BuildContext context, VoidCallback open)?
  triggerBuilder;
  final List<UiMenuNode> items;
  final double minWidth;
  final double maxWidth;

  /// Opens the menu on long press and enables drag-to-select for that press.
  final bool openOnLongPress;
  final bool closeOnSelect;

  /// Whether a pointer tap outside the trigger and menu dismisses it.
  ///
  /// Defaults to true. See [consumeOutsideTap] and [scrollBehavior].
  final bool dismissOnTapOutside;

  /// Modal dismissal by default. Set false for table/list interactions where
  /// the outside gesture should also reach the underlying content.
  final bool consumeOutsideTap;

  /// Ancestor scrolling dismisses context actions by default. This never
  /// dismisses when scrolling inside the menu itself.
  final UiMenuScrollBehavior scrollBehavior;

  @override
  State<UiDropdownMenu> createState() => _UiDropdownMenuState();
}

class _UiDropdownMenuState extends State<UiDropdownMenu> {
  @override
  Widget build(BuildContext context) => UiTheme(
    tokens: UiThemeTokens.of(context).copyWith(menu: widget.menuTokens),
    child: UiMenuAnchor(
      key: ValueKey(widget.transitionDurationScale),
      destinationOffset: widget.destinationOffset,
      transitionDurationScale: widget.transitionDurationScale,
      trigger: widget.trigger,
      triggerBuilder: widget.triggerBuilder,
      sourceBorderRadius: widget.sourceBorderRadius,
      items: widget.items,
      title: widget.title,
      backLabel: widget.backLabel,
      minWidth: widget.minWidth,
      maxWidth: widget.maxWidth,
      openOnLongPress: widget.openOnLongPress,
      closeOnSelect: widget.closeOnSelect,
      dismissOnTapOutside: widget.dismissOnTapOutside,
      consumeOutsideTap: widget.consumeOutsideTap,
      scrollBehavior: widget.scrollBehavior,
    ),
  );
}
