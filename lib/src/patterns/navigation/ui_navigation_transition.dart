import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_motion_transitions.dart';

/// Transition presets for navigation animations.
///
/// These match the three common patterns used across the kit's demos and
/// screens. Keep the list small on purpose — more styles should be added
/// only when they correspond to a real product need.
enum UiNavigationTransitionStyle {
  /// Cross-fade only. Good for neutral swaps where motion would feel
  /// heavy (modal dismiss, settings toggle result).
  fade,

  /// Cross-fade + a larger slide (~5%) from the primary axis. Matches a
  /// "push a detail on top" feel.
  slide,

  /// Cross-fade + a tight slide (~2%) suggesting pages share an axis.
  /// The outgoing page mirrors the incoming slide for symmetry.
  sharedAxis,
}

/// Transition wrapper used by [UiNavigationStack] and by custom hosts.
///
/// Pass the same [animation] to both incoming and outgoing children —
/// Flutter's `AnimatedSwitcher` handles this for you. The wrapper keeps
/// geometry symmetric around the mid-point so the outgoing child leaves
/// the stage using the inverse of the incoming motion.
class UiNavigationTransition extends StatelessWidget {
  const UiNavigationTransition({
    super.key,
    required this.animation,
    required this.child,
    this.style = UiNavigationTransitionStyle.sharedAxis,
    this.reverse = false,
  });

  final Animation<double> animation;
  final Widget child;
  final UiNavigationTransitionStyle style;

  /// When `true`, treats [animation] as the outgoing child's timeline
  /// and mirrors the translation. Callers building bespoke hosts can
  /// use `Animation.status` to decide.
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case UiNavigationTransitionStyle.fade:
        return FadeTransition(opacity: animation, child: child);
      case UiNavigationTransitionStyle.slide:
        return _slideFade(begin: 0.08);
      case UiNavigationTransitionStyle.sharedAxis:
        return _slideFade(begin: 0.03);
    }
  }

  Widget _slideFade({required double begin}) {
    final dx = reverse ? -begin : begin;
    return UiSlideFadeTransition(
      animation: animation,
      beginOffset: Offset(dx, 0),
      child: child,
    );
  }
}

/// Interactive back-swipe transition style.
///
/// Controls what the user sees while dragging the leading edge to pop
/// the current page. Introduced in PR-7 for Cupertino parallax
/// fidelity; [auto] matches platform conventions so existing call
/// sites continue to render the right thing.
enum UiBackSwipeTransition {
  /// Resolves to [cupertino] on iOS/macOS and [slide] on every other
  /// platform — matching platform conventions.
  auto,

  /// Full Cupertino parallax: the outgoing page translates with the
  /// finger while the incoming (previous) page is revealed underneath,
  /// starting offset by ~30 % of the viewport width and settling at
  /// zero. A leading-edge shadow accentuates the elevation.
  cupertino,

  /// Simple slide: the outgoing page translates with the finger and
  /// nothing is rendered underneath. Matches the PR-4 behaviour and
  /// is the right default for non-Cupertino platforms where a
  /// parallax reveal would read as Apple-specific.
  slide,
}

/// Parallax geometry constants used by the interactive back-swipe
/// region in [UiNavigationHost]. Declared at the library level so
/// tests can exercise the same numbers the implementation renders.
///
/// The ratio matches Apple's documented
/// `CupertinoPageTransition.primaryRouteAnimation` where the
/// incoming (previous) page starts at `-0.30 * width` and settles at
/// zero as `progress` interpolates from 0 to 1.
class UiBackSwipeParallaxMetrics {
  UiBackSwipeParallaxMetrics._();

  /// Fraction of the viewport width by which the incoming (previous)
  /// page starts offset from zero when the gesture begins.
  static const double incomingStartRatio = 0.30;

  /// Peak opacity of the scrim painted over the incoming page at
  /// `progress = 0`. Fades linearly to zero as the gesture completes.
  static const double incomingScrimOpacity = 0.06;

  /// Peak opacity of the leading-edge shadow cast by the outgoing
  /// page at `progress = 0.5`. Fades to zero at both endpoints so the
  /// elevation cue only appears mid-gesture, matching Cupertino.
  static const double outgoingShadowOpacity = 0.22;

  /// Blur radius of the outgoing page's leading shadow.
  static const double outgoingShadowBlur = 16;

  /// Leading offset of the outgoing page's shadow in logical pixels.
  /// Negative x places the shadow on the reading-start edge.
  static const double outgoingShadowOffsetX = -6;
}
