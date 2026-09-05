import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_navigation_transition.dart';

/// Tracks a horizontal drag starting in the leading-edge strip and drives
/// an interactive translation on [child], calling [onTriggered] once the
/// drag passes either the distance or velocity threshold on release.
///
/// This is what gives iOS/macOS users the edge-drag-to-pop gesture that
/// nothing in Flutter's plain `Navigator`/`PageRouteBuilder` pipeline
/// provides on its own — [UiNavigationHost] uses it for
/// `UiNavigationController` stacks, and [UiDualPane] uses it for the real
/// `Navigator` route it pushes on phones, so both get the same
/// Open-UI-owned gesture and visual treatment rather than two divergent
/// implementations.
///
/// Three rendering modes:
///
/// - [transitionBuilder], when provided, owns rendering entirely — called
///   with the live drag progress (0 at rest, 1 fully swiped away), the
///   outgoing [child], and (if supplied) [parallaxPrevious] as `incoming`.
///   A caller composites both itself — for example a plain cross-fade, or
///   its own signature [UiNavigationTransition] — instead of getting a
///   generic slide. Composing both explicitly also matters structurally:
///   an opaque `PageRoute`'s `Overlay` entry is painted alone, so nothing
///   underneath is ever visible on its own no matter how [child] is
///   transformed — `incoming` must be painted explicitly or the reveal is
///   just empty space. Takes priority over [style] when both are set.
/// - [UiBackSwipeTransition.slide] (the [style] default) — translate
///   [child] by `progress * width`.
/// - [UiBackSwipeTransition.layered] — when `progress > 0`, paint a
///   parallax stack with [parallaxPrevious] at the bottom and
///   [parallaxCurrent] on top; at `progress = 0` fall through to [child].
class UiEdgeSwipePopRegion extends StatefulWidget {
  const UiEdgeSwipePopRegion({
    super.key,
    required this.onTriggered,
    required this.edgeWidth,
    required this.minDistance,
    required this.minVelocity,
    required this.settleDuration,
    required this.child,
    this.style = UiBackSwipeTransition.slide,
    this.parallaxCurrent,
    this.parallaxPrevious,
    this.externalProgress,
    this.transitionBuilder,
  });

  final VoidCallback onTriggered;
  final double edgeWidth;
  final double minDistance;
  final double minVelocity;
  final Duration settleDuration;
  final Widget child;
  final UiBackSwipeTransition style;

  /// Required for [UiBackSwipeTransition.layered] — the current (topmost)
  /// content, painted above [parallaxPrevious] and translated with the
  /// finger. Ignored in [UiBackSwipeTransition.slide] mode.
  final Widget? parallaxCurrent;

  /// Required for [UiBackSwipeTransition.layered] — the content being
  /// revealed underneath, offset and settling to zero as the gesture
  /// completes. Ignored in [UiBackSwipeTransition.slide] mode.
  final Widget? parallaxPrevious;

  /// Optional observer for the live drag progress (0..1). Fired on every
  /// drag update and while the release animation runs.
  final ValueNotifier<double>? externalProgress;

  /// Overrides how the drag is rendered — see the class doc. `progress` is
  /// 0 at rest and 1 once fully swiped away; `incoming` is
  /// [parallaxPrevious] (`null` if not supplied). [style] and
  /// [parallaxCurrent] are ignored when this is set.
  final Widget Function(
    BuildContext context,
    double progress,
    Widget child,
    Widget? incoming,
  )?
  transitionBuilder;

  @override
  State<UiEdgeSwipePopRegion> createState() => _UiEdgeSwipePopRegionState();
}

class _UiEdgeSwipePopRegionState extends State<UiEdgeSwipePopRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drive = AnimationController(
    vsync: this,
    duration: widget.settleDuration,
    value: 0,
  );

  @override
  void didUpdateWidget(covariant UiEdgeSwipePopRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settleDuration != widget.settleDuration) {
      _drive.duration = widget.settleDuration;
    }
  }

  double _dragDx = 0;
  double _viewportWidth = 1;
  bool _dragActive = false;

  // Parallax continuity: once a drag has started in layered mode, we
  // snapshot the "from" / "to" widgets so the parallax stack keeps
  // rendering the same two surfaces even after `onTriggered()` triggers a
  // rebuild that would otherwise unmount the outgoing one.
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
    _parallaxFromSnapshot = widget.parallaxCurrent;
    _parallaxToSnapshot = widget.parallaxPrevious;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragActive) return;
    _dragDx = (_dragDx + d.delta.dx).clamp(0.0, double.infinity);
    final next = _viewportWidth <= 0
        ? 0.0
        : (_dragDx / _viewportWidth).clamp(0.0, 1.0);
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
    // After the pop, this region is typically about to be unmounted (the
    // route it guarded is gone). Reset drive to 0 defensively in case it
    // isn't — e.g. onTriggered was intercepted and the pop didn't
    // actually happen.
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
    if (widget.style != UiBackSwipeTransition.layered) return false;
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
            final customBuilder = widget.transitionBuilder;
            if (customBuilder != null) {
              // Prefer the drag-start snapshot once one exists — it keeps
              // the incoming content stable through the commit rebuild
              // that `onTriggered()` causes, same as layered mode does.
              final incoming = _parallaxToSnapshot ?? widget.parallaxPrevious;
              body = customBuilder(context, progress, widget.child, incoming);
            } else if (_shouldPaintParallax) {
              body = _LayeredBackSwipeStack(
                progress: progress,
                direction: dir,
                viewportWidth: _viewportWidth,
                from: _parallaxFromSnapshot!,
                to: _parallaxToSnapshot!,
              );
            } else if (widget.style == UiBackSwipeTransition.slide &&
                progress > 0) {
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

/// Two-page parallax stack used by [UiEdgeSwipePopRegion] in
/// [UiBackSwipeTransition.layered] mode.
class _LayeredBackSwipeStack extends StatelessWidget {
  const _LayeredBackSwipeStack({
    required this.progress,
    required this.direction,
    required this.viewportWidth,
    required this.from,
    required this.to,
  });

  /// `0` = gesture start; `1` = fully popped.
  final double progress;

  /// `+1` in LTR, `-1` in RTL. Applied to every horizontal offset so the
  /// reveal mirrors for RTL hosts.
  final double direction;

  final double viewportWidth;
  final Widget from;
  final Widget to;

  @override
  Widget build(BuildContext context) {
    final incomingStart =
        -UiBackSwipeLayeredMetrics.incomingStartRatio * viewportWidth;
    final incomingDx = (incomingStart + incomingStart.abs() * progress).clamp(
      incomingStart,
      0.0,
    );
    final outgoingDx = progress * viewportWidth;

    final scrimAlpha =
        UiBackSwipeLayeredMetrics.incomingScrimOpacity * (1.0 - progress);
    final shadowAlpha =
        UiBackSwipeLayeredMetrics.outgoingShadowOpacity *
        (1.0 - (progress - 0.5).abs() * 2);

    final pageBackground = UiThemeTokens.colorsOf(context).background;

    return Stack(
      children: [
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
                              UiBackSwipeLayeredMetrics.outgoingShadowBlur,
                          offset: Offset(
                            UiBackSwipeLayeredMetrics.outgoingShadowOffsetX *
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
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(() => HorizontalDragGestureRecognizer(), (instance) {
              instance
                ..onStart = onStart
                ..onUpdate = (details) {
                  if (isRtl) {
                    onUpdate(
                      DragUpdateDetails(
                        sourceTimeStamp: details.sourceTimeStamp,
                        delta: Offset(-details.delta.dx, details.delta.dy),
                        primaryDelta: details.primaryDelta == null
                            ? null
                            : -details.primaryDelta!,
                        globalPosition: details.globalPosition,
                        localPosition: details.localPosition,
                      ),
                    );
                  } else {
                    onUpdate(details);
                  }
                }
                ..onEnd = (details) {
                  if (isRtl) {
                    onEnd(
                      DragEndDetails(
                        velocity: details.velocity,
                        primaryVelocity: details.primaryVelocity == null
                            ? null
                            : -details.primaryVelocity!,
                      ),
                    );
                  } else {
                    onEnd(details);
                  }
                }
                ..onCancel = onCancel;
            }),
      },
    );
  }
}
