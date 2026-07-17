import 'package:flutter/widgets.dart';

/// Safe-area policy for a page subtree.
///
/// Each mode maps to a specific `SafeArea` configuration so screen-level
/// code can opt in to a named behaviour instead of wiring up insets by
/// hand. Nesting is safe: once a `SafeArea` consumes `MediaQuery.padding`
/// it removes that inset for descendants, so a nested [UiSafeViewport]
/// is idempotent.
enum UiSafeViewportMode {
  /// Add no insets. Use when the child already manages its own safe area
  /// (e.g. full-bleed images or a custom scaffold).
  none,

  /// Consume only the top inset (status bar / dynamic island).
  top,

  /// Consume only the bottom inset (home indicator / gesture bar).
  bottom,

  /// Consume both top and bottom insets. Default for most pages.
  all,

  /// Consume the top inset + the soft-keyboard height when it's raised.
  /// When the keyboard is down, the home-indicator inset is still
  /// applied so the page doesn't run under the gesture bar.
  keyboardAware,

  /// Consume the soft-keyboard height only (and bottom inset when the
  /// keyboard is down), but do not consume the top inset.
  ///
  /// Useful when a parent already paints and handles the top safe area
  /// (for example a custom navigation/header surface).
  keyboardAwareNoTop,
}

/// Applies a predictable safe-area strategy for Open UI Kit pages.
///
/// Prefer [UiPageScaffold] at the page root; use [UiSafeViewport]
/// directly when embedding a page-like subtree (e.g. inside a sheet).
class UiSafeViewport extends StatelessWidget {
  const UiSafeViewport({
    super.key,
    required this.child,
    this.mode = UiSafeViewportMode.all,
    this.left = true,
    this.right = true,
    this.minimum = EdgeInsets.zero,
  });

  final Widget child;
  final UiSafeViewportMode mode;
  final bool left;
  final bool right;

  /// Minimum insets applied even when the system reports zero padding.
  final EdgeInsets minimum;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case UiSafeViewportMode.none:
        return child;
      case UiSafeViewportMode.top:
        return SafeArea(
          top: true,
          bottom: false,
          left: left,
          right: right,
          minimum: minimum,
          child: child,
        );
      case UiSafeViewportMode.bottom:
        return SafeArea(
          top: false,
          bottom: true,
          left: left,
          right: right,
          minimum: minimum,
          child: child,
        );
      case UiSafeViewportMode.all:
        return SafeArea(
          left: left,
          right: right,
          minimum: minimum,
          child: child,
        );
      case UiSafeViewportMode.keyboardAware:
        // When the keyboard is up, its height (`viewInsets.bottom`)
        // supersedes the gesture-bar inset. When it's down, we still
        // want the home-indicator padding so the page doesn't run under
        // the OS affordance.
        final media = MediaQuery.of(context);
        final keyboard = media.viewInsets.bottom;
        final keyboardOpen = keyboard > 0;
        return SafeArea(
          top: true,
          bottom: !keyboardOpen,
          left: left,
          right: right,
          minimum: minimum,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardOpen ? keyboard : 0),
            child: child,
          ),
        );
      case UiSafeViewportMode.keyboardAwareNoTop:
        final media = MediaQuery.of(context);
        final keyboard = media.viewInsets.bottom;
        final keyboardOpen = keyboard > 0;
        return SafeArea(
          top: false,
          bottom: !keyboardOpen,
          left: left,
          right: right,
          minimum: minimum,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardOpen ? keyboard : 0),
            child: child,
          ),
        );
    }
  }
}
