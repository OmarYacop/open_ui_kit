import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
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
/// page — this is how `CupertinoPageRoute` behaves when a screen sits
/// on Flutter's Navigator. `UiNavigationStack` intentionally does NOT
/// participate in the `Navigator`/`Route` system (see its own
/// docstring), so nothing in the default pipeline provides that
/// gesture. [UiNavigationHost] adds an edge-swipe region that
/// translates the top of the stack under the finger and calls
/// [UiNavigationController.pop] when the release passes either the
/// distance or velocity threshold.
///
/// The gesture is:
///
/// - **platform-gated** via [enableEdgeSwipePop]. By default it is on
///   for iOS and macOS, off elsewhere.
/// - **stack-aware**: only active when [UiNavigationController.canPop]
///   is true. At the stack root the edge strip is absent so root-page
///   scroll / hero gestures keep the full width.
/// - **strip-scoped**: the detector occupies a narrow strip along the
///   leading edge ([edgeSwipeWidth] wide).
/// - **interactive** (PR-4): the current page translates under the
///   finger while dragging. A release that doesn't meet threshold
///   animates the page back; a release that meets it animates the
///   page off-screen and then pops the stack.
/// - **Cupertino parallax** (PR-7): on iOS/macOS (or when forced via
///   [backSwipeTransition]) both the outgoing and incoming routes
///   are rendered during the drag. The incoming route starts offset
///   by `-0.30 * width` (LTR reading-start) and settles at 0 as the
///   gesture completes; the outgoing route carries a leading-edge
///   shadow for the elevation cue. Non-Cupertino platforms fall back
///   to the slide-only treatment.
class UiNavigationHost extends StatelessWidget {
  const UiNavigationHost({
    super.key,
    required this.controller,
    this.builder,
    this.transitionStyle = UiNavigationTransitionStyle.softShift,
    this.enableEdgeSwipePop,
    this.edgeSwipeWidth = 22,
    this.edgeSwipeMinDistance = 64,
    this.edgeSwipeMinVelocity = 400,
    this.edgeSwipeProgress,
    this.backSwipeTransition = UiBackSwipeTransition.auto,
  });

  final UiNavigationController controller;

  /// Optional custom entry renderer. When null, each entry is built by
  /// the [UiRouteSpec] registered with that id.
  final Widget Function(BuildContext context, UiRouteEntry entry)? builder;

  final UiNavigationTransitionStyle transitionStyle;

  /// Force edge-swipe-to-pop on/off. When null (default) the behaviour
  /// follows the ambient platform — on for iOS/macOS, off otherwise.
  final bool? enableEdgeSwipePop;

  /// Width in logical pixels of the leading-edge strip that starts the
  /// pop gesture. Matches CupertinoPageRoute's default.
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

  /// Back-swipe visual treatment. See [UiBackSwipeTransition].
  ///
  /// The [UiBackSwipeTransition.auto] default picks Cupertino parallax
  /// on iOS/macOS and the simple slide elsewhere; pass [cupertino] or
  /// [slide] to force a specific treatment regardless of platform.
  final UiBackSwipeTransition backSwipeTransition;

  bool _shouldEnableSwipe(BuildContext context, int stackLength) {
    if (stackLength < 2) return false;
    final forced = enableEdgeSwipePop;
    if (forced != null) return forced;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  UiBackSwipeTransition _resolveBackSwipeStyle() {
    if (backSwipeTransition != UiBackSwipeTransition.auto) {
      return backSwipeTransition;
    }
    final platform = defaultTargetPlatform;
    return (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)
        ? UiBackSwipeTransition.cupertino
        : UiBackSwipeTransition.slide;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<UiRouteEntry>>(
      valueListenable: controller.stackListenable,
      builder: (context, stack, _) {
        if (stack.isEmpty) return const SizedBox.shrink();
        final host = UiNavigationStack(
          index: stack.length - 1,
          transitionStyle: transitionStyle,
          children: [
            for (final entry in stack) _build(context, entry),
          ],
        );
        if (!_shouldEnableSwipe(context, stack.length)) return host;
        final style = _resolveBackSwipeStyle();
        final parallaxCurrent =
            stack.isNotEmpty ? _build(context, stack[stack.length - 1]) : null;
        final parallaxPrevious =
            stack.length >= 2 ? _build(context, stack[stack.length - 2]) : null;
        return _EdgeSwipePopRegion(
          onTriggered: () => controller.pop(),
          edgeWidth: edgeSwipeWidth,
          minDistance: edgeSwipeMinDistance,
          minVelocity: edgeSwipeMinVelocity,
          externalProgress: edgeSwipeProgress,
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
          assert(
            spec != null,
            'No route registered for id "${entry.id}".',
          );
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

/// Tracks a horizontal drag starting in the leading-edge strip and
/// drives an interactive translation on the child.
///
/// Two rendering modes, chosen by [style] resolved against the
/// ambient platform at [UiNavigationHost.build]:
///
/// - [UiBackSwipeTransition.slide] — translate [child] (the full
///   `UiNavigationStack`) by `progress * width`.
/// - [UiBackSwipeTransition.cupertino] — when `progress > 0`, paint a
///   parallax stack with [parallaxPrevious] at the bottom and
///   [parallaxCurrent] on top; at `progress = 0` fall through to
///   [child] so the normal `UiNavigationStack`'s forward transitions
///   remain intact.
class _EdgeSwipePopRegion extends StatefulWidget {
  const _EdgeSwipePopRegion({
    required this.onTriggered,
    required this.edgeWidth,
    required this.minDistance,
    required this.minVelocity,
    required this.child,
    required this.style,
    this.parallaxCurrent,
    this.parallaxPrevious,
    this.externalProgress,
  });

  final VoidCallback onTriggered;
  final double edgeWidth;
  final double minDistance;
  final double minVelocity;
  final Widget child;
  final UiBackSwipeTransition style;
  final Widget? parallaxCurrent;
  final Widget? parallaxPrevious;
  final ValueNotifier<double>? externalProgress;

  @override
  State<_EdgeSwipePopRegion> createState() => _EdgeSwipePopRegionState();
}

class _EdgeSwipePopRegionState extends State<_EdgeSwipePopRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drive = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 0,
  );

  double _dragDx = 0;
  double _viewportWidth = 1;
  bool _dragActive = false;

  // Parallax continuity: once a drag has started in cupertino mode,
  // we snapshot the "from" / "to" widgets so the parallax stack
  // keeps rendering the same two routes even after `controller.pop()`
  // triggers a stack rebuild that would otherwise un-mount the
  // outgoing route.
  Widget? _parallaxFromSnapshot;
  Widget? _parallaxToSnapshot;

  @override
  void initState() {
    super.initState();
    _drive.addListener(_publishProgress);
  }

  void _publishProgress() {
    final notifier = widget.externalProgress;
    if (notifier != null && notifier.value != _drive.value) {
      notifier.value = _drive.value;
    }
  }

  @override
  void dispose() {
    _drive.removeListener(_publishProgress);
    _drive.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    _dragActive = true;
    _dragDx = 0;
    if (_drive.isAnimating) _drive.stop();
    // Capture snapshots at gesture start — these keep the parallax
    // pair stable through the commit rebuild.
    _parallaxFromSnapshot = widget.parallaxCurrent;
    _parallaxToSnapshot = widget.parallaxPrevious;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragActive) return;
    _dragDx = (_dragDx + d.delta.dx).clamp(0.0, double.infinity);
    final next =
        _viewportWidth <= 0 ? 0.0 : (_dragDx / _viewportWidth).clamp(0.0, 1.0);
    _drive.value = next;
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragActive) return;
    _dragActive = false;
    final velocity = d.primaryVelocity ?? 0;
    final meetsDistance = _dragDx >= widget.minDistance;
    final meetsVelocity = velocity >= widget.minVelocity;
    final tokens = UiThemeTokens.of(context);

    if (meetsDistance || meetsVelocity) {
      _drive
          .animateTo(
            1.0,
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
          )
          .whenCompleteOrCancel(_completePop);
    } else {
      _drive
          .animateTo(
            0.0,
            duration: tokens.motion.standard,
            curve: tokens.motion.standardCurve,
          )
          .whenCompleteOrCancel(_clearParallaxSnapshots);
    }
    _dragDx = 0;
  }

  void _onCancel() {
    if (!_dragActive) return;
    _dragActive = false;
    final tokens = UiThemeTokens.of(context);
    _drive
        .animateTo(
          0.0,
          duration: tokens.motion.standard,
          curve: tokens.motion.standardCurve,
        )
        .whenCompleteOrCancel(_clearParallaxSnapshots);
    _dragDx = 0;
  }

  void _completePop() {
    if (!mounted) return;
    widget.onTriggered();
    // After pop, the host rebuilds with stack.length-1. The snapshot
    // pair (outgoing + incoming) is stale; reset drive to 0 so the
    // region falls through to `widget.child` (the new normal host)
    // showing the now-current page at its natural position. Since
    // the incoming page was already at offset 0 at drive = 1, this
    // is a continuous visual swap.
    _drive.value = 0;
    _clearParallaxSnapshots();
  }

  void _clearParallaxSnapshots() {
    if (!mounted) return;
    setState(() {
      _parallaxFromSnapshot = null;
      _parallaxToSnapshot = null;
    });
  }

  bool get _shouldPaintParallax {
    if (widget.style != UiBackSwipeTransition.cupertino) return false;
    if (!_dragActive && _drive.value == 0) return false;
    return _parallaxFromSnapshot != null && _parallaxToSnapshot != null;
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final isRtl = direction == TextDirection.rtl;
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        final edgePositioned = Positioned(
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          left: isRtl ? null : 0,
          right: isRtl ? 0 : null,
          child: _RawEdgeRecognizer(
            onStart: _onStart,
            onUpdate: _onUpdate,
            onEnd: _onEnd,
            onCancel: _onCancel,
            isRtl: isRtl,
          ),
        );
        return AnimatedBuilder(
          animation: _drive,
          builder: (context, _) {
            final progress = _drive.value;
            final dir = isRtl ? -1.0 : 1.0;
            final Widget body;
            if (_shouldPaintParallax) {
              body = _CupertinoBackSwipeStack(
                progress: progress,
                direction: dir,
                viewportWidth: _viewportWidth,
                from: _parallaxFromSnapshot!,
                to: _parallaxToSnapshot!,
              );
            } else if (widget.style == UiBackSwipeTransition.slide &&
                progress > 0) {
              // Slide-only: translate the existing single-child host.
              body = Transform.translate(
                offset: Offset(progress * _viewportWidth * dir, 0),
                child: widget.child,
              );
            } else {
              body = widget.child;
            }
            return Stack(
              children: [
                Positioned.fill(child: body),
                edgePositioned,
              ],
            );
          },
        );
      },
    );
  }
}

/// Two-page parallax stack used by the interactive back-swipe in
/// [UiBackSwipeTransition.cupertino] mode.
class _CupertinoBackSwipeStack extends StatelessWidget {
  const _CupertinoBackSwipeStack({
    required this.progress,
    required this.direction,
    required this.viewportWidth,
    required this.from,
    required this.to,
  });

  /// `0` = gesture start; `1` = fully popped.
  final double progress;

  /// `+1` in LTR, `-1` in RTL. Applied to every horizontal offset so
  /// the reveal mirrors for RTL hosts.
  final double direction;

  final double viewportWidth;
  final Widget from;
  final Widget to;

  @override
  Widget build(BuildContext context) {
    final incomingStart =
        -UiBackSwipeParallaxMetrics.incomingStartRatio * viewportWidth;
    // Incoming page: moves from `incomingStart` at progress=0 to `0`
    // at progress=1.
    final incomingDx = (incomingStart + incomingStart.abs() * progress)
        .clamp(incomingStart, 0.0);
    final outgoingDx = progress * viewportWidth;

    // Scrim intensifies as the incoming page is further offset (i.e.
    // at the start of the gesture), fades out at commit.
    final scrimAlpha =
        UiBackSwipeParallaxMetrics.incomingScrimOpacity * (1.0 - progress);
    // Shadow peaks at mid-gesture for a Cupertino-like elevation cue.
    final shadowAlpha = UiBackSwipeParallaxMetrics.outgoingShadowOpacity *
        (1.0 - (progress - 0.5).abs() * 2);

    // Page-background fallback. Pages that don't install their own
    // opaque background (raw widget trees without `UiPageScaffold` /
    // `Scaffold`) would let the underlying route bleed through during
    // the parallax — the outgoing page needs to be opaque so the
    // reveal reads as a slide, not a cross-fade. Wrap both routes in
    // a ColoredBox painted with the theme's page-background token so
    // every host gets a solid surface regardless of how the page
    // content paints.
    final pageBackground = UiThemeTokens.of(context).colors.background;

    return Stack(
      children: [
        // Incoming (previous) route — scrim overlay fades as the
        // gesture completes.
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(incomingDx * direction, 0),
            child: ColoredBox(
              color: pageBackground,
              child: Stack(
                children: [
                  Positioned.fill(child: to),
                  if (scrimAlpha > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Color.fromRGBO(0, 0, 0, scrimAlpha),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Outgoing (current) route — translates under the finger and
        // casts a leading-edge shadow. The opaque backdrop prevents
        // the incoming page from bleeding through pages that don't
        // paint their own background.
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(outgoingDx * direction, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pageBackground,
                boxShadow: shadowAlpha > 0
                    ? [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, shadowAlpha),
                          blurRadius:
                              UiBackSwipeParallaxMetrics.outgoingShadowBlur,
                          offset: Offset(
                            UiBackSwipeParallaxMetrics.outgoingShadowOffsetX *
                                direction,
                            0,
                          ),
                        ),
                      ]
                    : null,
              ),
              child: from,
            ),
          ),
        ),
      ],
    );
  }
}

class _RawEdgeRecognizer extends StatelessWidget {
  const _RawEdgeRecognizer({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.isRtl,
  });

  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final VoidCallback onCancel;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
          (instance) {
            instance
              ..onStart = onStart
              ..onUpdate = (details) {
                if (isRtl) {
                  onUpdate(DragUpdateDetails(
                    sourceTimeStamp: details.sourceTimeStamp,
                    delta: Offset(-details.delta.dx, details.delta.dy),
                    primaryDelta: details.primaryDelta == null
                        ? null
                        : -details.primaryDelta!,
                    globalPosition: details.globalPosition,
                    localPosition: details.localPosition,
                  ));
                } else {
                  onUpdate(details);
                }
              }
              ..onEnd = (details) {
                if (isRtl) {
                  onEnd(DragEndDetails(
                    velocity: details.velocity,
                    primaryVelocity: details.primaryVelocity == null
                        ? null
                        : -details.primaryVelocity!,
                  ));
                } else {
                  onEnd(details);
                }
              }
              ..onCancel = onCancel;
          },
        ),
      },
    );
  }
}
