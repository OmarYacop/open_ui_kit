import 'package:flutter/widgets.dart';

/// Removes platform overscroll decoration without changing scroll physics.
///
/// Android normally stretches or glows at a scroll boundary. Open UI Kit
/// suppresses that decoration for visual consistency while preserving
/// overscroll notifications used by refreshers and scroll-arbitrated surfaces.
///
/// The ambient [ScrollBehavior] is copied so platform input, desktop
/// scrollbars, keyboard dismissal, and custom physics remain intact.
class UiScrollConfiguration extends StatelessWidget {
  const UiScrollConfiguration({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: child,
    );
  }
}
