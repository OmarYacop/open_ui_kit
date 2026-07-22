import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_navigation_transition.dart';

/// Open UI Kit transition host for index-addressed page stacks.
///
/// This is a lightweight `AnimatedSwitcher`-based surface — it does not
/// participate in Flutter's `Navigator`/route system. Use it when you
/// own the page selection (e.g. a tab body, a wizard step, a master/
/// detail pane) and want consistent motion tokens without wiring up a
/// nested navigator.
class UiNavigationStack extends StatelessWidget {
  const UiNavigationStack({
    super.key,
    required this.index,
    required this.children,
    this.transitionStyle = UiNavigationTransitionStyle.softShift,
    this.duration,
  }) : assert(
          children.length > 0,
          'UiNavigationStack requires at least one child',
        );

  final int index;
  final List<Widget> children;
  final UiNavigationTransitionStyle transitionStyle;

  /// Override for the swap duration. When null, the ambient
  /// `UiMotionTokens.standard` is used.
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final i = index.clamp(0, children.length - 1);
    return AnimatedSwitcher(
      duration: duration ?? tokens.motion.standard,
      reverseDuration: duration ?? tokens.motion.fast,
      switchInCurve: tokens.motion.standardCurve,
      switchOutCurve: tokens.motion.standardCurve,
      transitionBuilder: (child, animation) {
        // AnimatedSwitcher reuses the animation object for both the
        // incoming and outgoing children; direction differs via status.
        // Flip the slide direction on the outgoing child so the pair
        // reads as a single sweep instead of crossing paths.
        final isReverse = animation.status == AnimationStatus.reverse;
        return UiNavigationTransition(
          animation: animation,
          style: transitionStyle,
          reverse: isReverse,
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Stack(
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(i),
        child: children[i],
      ),
    );
  }
}
