import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_motion_spec.dart';
import 'ui_edge_swipe_pop_region.dart';
import 'ui_navigation_controller.dart';
import 'ui_navigation_scope.dart';
import 'ui_navigation_stack.dart';
import 'ui_navigation_transition.dart';
import 'ui_route_entry.dart';

/// Renders the current stack of a [UiNavigationController].
///
/// ### Edge-swipe pop (PR-E / PR-4 / PR-7)
///
/// iOS/macOS users expect an edge-drag from the left to pop the top
/// page. `UiNavigationStack` intentionally does not
/// participate in the `Navigator`/`Route` system (see its own
/// docstring), so nothing in the default pipeline provides that
/// gesture. [UiNavigationHost] adds an edge-swipe region that
/// translates the top of the stack under the finger and calls
/// [UiNavigationController.pop] when the release passes either the
/// distance or velocity threshold.
///
/// The gesture is:
///
/// - **explicitly enabled** via [enableEdgeSwipePop]. It is off by default.
/// - **stack-aware**: only active when [UiNavigationController.canPop]
///   is true. At the stack root the edge strip is absent so root-page
///   scroll / hero gestures keep the full width.
/// - **strip-scoped**: the detector occupies a narrow strip along the
///   leading edge ([edgeSwipeWidth] wide).
/// - **interactive** (PR-4): the current page translates under the
///   finger while dragging. A release that doesn't meet threshold
///   animates the page back; a release that meets it animates the
///   page off-screen and then pops the stack.
/// - **layered parallax**: when selected through [backSwipeTransition], both
///   the outgoing and incoming routes
///   are rendered during the drag. The incoming route starts offset
///   by `-0.30 * width` (LTR reading-start) and settles at 0 as the
///   gesture completes; the outgoing route carries a leading-edge
///   shadow for the elevation cue.
class UiNavigationHost extends StatelessWidget {
  const UiNavigationHost({
    super.key,
    required this.controller,
    this.builder,
    this.transitionStyle = UiNavigationTransitionStyle.softShift,
    this.enableEdgeSwipePop = false,
    this.edgeSwipeWidth = 22,
    this.edgeSwipeMinDistance = 64,
    this.edgeSwipeMinVelocity = 400,
    this.edgeSwipeProgress,
    this.edgeSwipeSettleDuration = UiMotionDuration.slow,
    this.backSwipeTransition = UiBackSwipeTransition.slide,
  });

  final UiNavigationController controller;

  /// Optional custom entry renderer. When null, each entry is built by
  /// the [UiRouteSpec] registered with that id.
  final Widget Function(BuildContext context, UiRouteEntry entry)? builder;

  final UiNavigationTransitionStyle transitionStyle;

  /// Whether edge-swipe-to-pop is enabled.
  final bool enableEdgeSwipePop;

  /// Width in logical pixels of the leading-edge strip that starts the
  /// Width of the leading-edge gesture region.
  final double edgeSwipeWidth;

  /// Horizontal distance the finger must travel from the edge before
  /// releasing for the gesture to complete.
  final double edgeSwipeMinDistance;

  /// Primary horizontal velocity (pts/sec) that alone triggers a pop
  /// even if the distance threshold was not met.
  final double edgeSwipeMinVelocity;

  /// Optional observer for the live drag progress (0..1). Fired on
  /// every drag update and while the release animation runs. Mostly
  /// useful for tests and for hosts that want to cross-fade
  /// supplementary chrome during a pop.
  final ValueNotifier<double>? edgeSwipeProgress;

  /// Timing used after an edge swipe is released.
  final UiMotionDuration edgeSwipeSettleDuration;

  /// Back-swipe visual treatment. See [UiBackSwipeTransition].
  ///
  /// The Open UI-owned visual treatment for an enabled back swipe.
  final UiBackSwipeTransition backSwipeTransition;

  bool _shouldEnableSwipe(BuildContext context, int stackLength) =>
      stackLength >= 2 && enableEdgeSwipePop;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UiRouteEntry>>(
      valueListenable: controller.stackListenable,
      builder: (context, stack, _) {
        if (stack.isEmpty) return const SizedBox.shrink();
        final host = UiNavigationStack(
          index: stack.length - 1,
          transitionStyle: transitionStyle,
          children: [for (final entry in stack) _build(context, entry)],
        );
        if (!_shouldEnableSwipe(context, stack.length)) return host;
        final style = backSwipeTransition;
        final parallaxCurrent = stack.isNotEmpty
            ? _build(context, stack[stack.length - 1])
            : null;
        final parallaxPrevious = stack.length >= 2
            ? _build(context, stack[stack.length - 2])
            : null;
        return UiEdgeSwipePopRegion(
          onTriggered: () => controller.pop(),
          edgeWidth: edgeSwipeWidth,
          minDistance: edgeSwipeMinDistance,
          minVelocity: edgeSwipeMinVelocity,
          externalProgress: edgeSwipeProgress,
          settleDuration: edgeSwipeSettleDuration.resolve(context),
          style: style,
          parallaxCurrent: parallaxCurrent,
          parallaxPrevious: parallaxPrevious,
          child: host,
        );
      },
    );
  }

  Widget _build(BuildContext context, UiRouteEntry entry) {
    final child = switch (builder) {
      final b? => b(context, entry),
      null => () {
        final spec = controller.specFor(entry.id);
        assert(spec != null, 'No route registered for id "${entry.id}".');
        return spec!.builder(context, entry.args);
      }(),
    };
    return UiNavigationControllerScope(
      controller: controller,
      entry: entry,
      child: child,
    );
  }
}
