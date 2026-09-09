import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

import '../../components/surfaces/ui_fluid_surface.dart';
import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/motion/ui_fluid_route_motion.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_container_transform.dart';
import 'ui_cupertino_back_gesture.dart';

/// Experimental: a full-screen route whose page grows out of a source rect
/// with the kit's fluid morph and shrinks back into it on pop.
///
/// The transition is driven directly by the route's controller, so the iOS
/// edge-swipe from [UiCupertinoBackGestureMixin] scrubs the same geometry.
/// Pops and gestures sample the monotonic path (no overshoot under the
/// finger); pushes use the bounded spring. Provide [sourceRectResolver] to
/// fly back to the source's live position when it has moved (for example a
/// scrolled list); invalid or unmeasurable results fall back to the last
/// known rect.
///
/// Prefer [UiFluidOpenContainer] or [UiFluidPageNavigation.pushUiFluidPage]
/// over constructing this directly.
class UiFluidPageRoute<T> extends PageRoute<T>
    with UiCupertinoBackGestureMixin<T> {
  UiFluidPageRoute({
    required this.builder,
    required Rect sourceRect,
    this.sourceRectResolver,
    this.sourceBorderRadius = BorderRadius.zero,
    this.destinationBorderRadius,
    this.sourceBuilder,
    this.surfaceColor,
    this.scrimColor,
    this.motion = const UiFluidRouteMotion(),
    this.transitionDuration = defaultTransitionDuration,
    this.reverseTransitionDuration = defaultReverseTransitionDuration,
    this.swipeBackEnabled = true,
    this.dragToDismissEnabled = true,
    super.settings,
  }) : _sourceRect = UiFluidRouteMotion.constrainRect(sourceRect, null);

  /// Authored fluid release timing: the route covers the expansion part of
  /// the accepted 765 ms morph (press excluded).
  static const Duration defaultTransitionDuration = Duration(milliseconds: 612);

  /// Closing uses a monotonic ease and reads faster.
  static const Duration defaultReverseTransitionDuration = Duration(
    milliseconds: 480,
  );

  final WidgetBuilder builder;

  /// Re-read on every popping frame. Return `null` to keep the current rect.
  final ValueGetter<Rect?>? sourceRectResolver;
  final BorderRadius sourceBorderRadius;

  /// Defaults to [UiContainerTransformGeometry.iosScreenBorderRadius].
  final BorderRadius? destinationBorderRadius;

  /// Optional stand-in for the source content, painted at the source's size
  /// and cross-faded out as the page appears. Never interactive.
  final WidgetBuilder? sourceBuilder;
  final Color? surfaceColor;
  final Color? scrimColor;
  final UiFluidRouteMotion motion;
  final bool swipeBackEnabled;

  /// Lets a drag anywhere on the page (or an over-scroll past the top of
  /// its scrollable) carry the whole page with the finger, shrinking it
  /// like a media viewer; releasing past the threshold flies it back into
  /// the source, otherwise it settles back in place.
  final bool dragToDismissEnabled;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  Rect _sourceRect;
  final ValueNotifier<UiFluidDragState> _drag = ValueNotifier(
    UiFluidDragState.idle,
  );
  UiFluidGeometry? _dismissOrigin;
  double? _releaseVelocity;
  bool _flyingBack = false;

  /// Critically damped: the page keeps the finger's momentum and lands on
  /// the source without overshooting into it.
  static final SpringDescription _flightSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 170, ratio: 1);

  /// Source rect currently used by the transition, in the navigator
  /// overlay's coordinate space.
  Rect get sourceRect => _sourceRect;

  /// Live drag state while the page is being carried by the finger.
  ValueListenable<UiFluidDragState> get dragState => _drag;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _dismissFromDrag(Offset velocity) {
    final nav = navigator;
    if (nav == null || !isCurrent) return;
    final overlay = nav.overlay?.context.findRenderObject();
    _refreshSourceRect();
    if (overlay is RenderBox && overlay.hasSize) {
      final bounds = Offset.zero & overlay.size;
      final destination = UiFluidGeometry(
        bounds,
        0,
        corners:
            destinationBorderRadius ??
            UiContainerTransformGeometry.iosScreenBorderRadius(nav.context),
      );
      // The reverse leg departs from where the finger left the page, with
      // the finger's speed along the way to the source.
      final origin = UiFluidRouteTransition.draggedGeometry(
        destination,
        _drag.value,
        sourceBorderRadius,
        bounds,
      );
      _dismissOrigin = origin;
      final path = _sourceRect.center - origin.rect.center;
      final distance = math.max(path.distance, 1.0);
      final towardSource = path.distance == 0
          ? 0.0
          : (velocity.dx * path.dx + velocity.dy * path.dy) / path.distance;
      // Progress runs 1 -> 0 toward the source; only momentum that already
      // heads there carries over.
      _releaseVelocity = -math.max(0.0, towardSource) / distance;
    }
    nav.pop();
  }

  @override
  bool didPop(T? result) {
    final popped = super.didPop(result);
    final velocity = _releaseVelocity;
    final animation = controller;
    if (popped && velocity != null && animation != null) {
      _releaseVelocity = null;
      _flyingBack = true;
      // Replace the timed reverse with a spring that starts at the released
      // frame and speed. A negative fling heads to `dismissed`, which is
      // what lets the navigator finalize the route.
      animation.fling(
        velocity: math.min(velocity, -.001),
        springDescription: _flightSpring,
      );
    }
    return popped;
  }

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => false;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  void _refreshSourceRect() {
    final resolved = sourceRectResolver?.call();
    if (resolved == null || !resolved.isFinite) return;
    if (resolved.width < 1 || resolved.height < 1) return;
    _sourceRect = resolved;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final monotonic =
        _flyingBack ||
        animation.status == AnimationStatus.reverse ||
        (navigator?.userGestureInProgress ?? false);
    if (monotonic) _refreshSourceRect();
    final transitioned = UiFluidRouteTransition(
      animation: animation,
      monotonic: monotonic,
      sourceRect: _sourceRect,
      sourceBorderRadius: sourceBorderRadius,
      destinationBorderRadius: destinationBorderRadius,
      sourceBuilder: sourceBuilder,
      surfaceColor: surfaceColor,
      scrimColor: scrimColor,
      motion: motion,
      dragState: dragToDismissEnabled ? _drag : null,
      dismissOrigin: _dismissOrigin,
      linearReverse: _flyingBack,
      child: dragToDismissEnabled
          ? UiFluidDismissRegion(
              state: _drag,
              enabled: () =>
                  isCurrent && !(navigator?.userGestureInProgress ?? false),
              onDismiss: _dismissFromDrag,
              child: child,
            )
          : child,
    );
    if (!swipeBackEnabled) return transitioned;
    return wrapWithBackGesture(context, transitioned);
  }
}

/// Experimental geometry and reveal primitive used by [UiFluidPageRoute].
///
/// The destination is laid out once at the route's full constraints and
/// revealed through the moving [UiFluidSurface] outline; only paint-time
/// geometry and opacity change per frame.
class UiFluidRouteTransition extends StatelessWidget {
  const UiFluidRouteTransition({
    super.key,
    required this.animation,
    required this.sourceRect,
    required this.child,
    this.monotonic = false,
    this.sourceBorderRadius = BorderRadius.zero,
    this.destinationBorderRadius,
    this.sourceBuilder,
    this.surfaceColor,
    this.scrimColor,
    this.motion = const UiFluidRouteMotion(),
    this.dragState,
    this.dismissOrigin,
    this.linearReverse = false,
  });

  final Animation<double> animation;

  /// The closing clock is already shaped (spring), so map it linearly.
  final bool linearReverse;

  /// Sample the ease instead of the spring (closing or scrubbing).
  final bool monotonic;

  /// Finger-carried offset and shrink while the page is dragged.
  final ValueListenable<UiFluidDragState>? dragState;

  /// Where a drag released the page; the reverse leg flies from here
  /// instead of from the full destination.
  final UiFluidGeometry? dismissOrigin;

  /// Page geometry while carried by a drag: it follows the finger and
  /// shrinks toward roughly half size, gaining the source's corners.
  static UiFluidGeometry draggedGeometry(
    UiFluidGeometry destination,
    UiFluidDragState drag,
    BorderRadius sourceCorners,
    Rect bounds,
  ) {
    final q = drag.progress.clamp(0.0, 1.0);
    if (q == 0 && drag.offset == Offset.zero) return destination;
    final scale = lerpDouble(1, .5, q)!;
    final full = destination.rect;
    final rect = Rect.fromCenter(
      center: full.center + drag.offset,
      width: full.width * scale,
      height: full.height * scale,
    );
    final corners = BorderRadius.lerp(
      destination.corners ?? BorderRadius.circular(destination.radius),
      BorderRadius.lerp(
        sourceCorners,
        const BorderRadius.all(Radius.circular(28)),
        .5,
      ),
      q,
    )!;
    return UiFluidGeometry(
      UiFluidRouteMotion.constrainRect(
        rect,
        bounds.inflate(bounds.shortestSide),
      ),
      corners.topLeft.x,
      corners: corners,
    );
  }

  final Rect sourceRect;
  final BorderRadius sourceBorderRadius;
  final BorderRadius? destinationBorderRadius;
  final WidgetBuilder? sourceBuilder;
  final Color? surfaceColor;
  final Color? scrimColor;
  final UiFluidRouteMotion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final surface = surfaceColor ?? tokens.colors.background;
    final scrim = scrimColor ?? tokens.colors.overlay;
    final source = UiFluidGeometry(sourceRect, 0, corners: sourceBorderRadius);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Offset.zero & constraints.biggest;
        final destination = UiFluidGeometry(
          bounds,
          0,
          corners:
              destinationBorderRadius ??
              UiContainerTransformGeometry.iosScreenBorderRadius(context),
        );
        final drag = dragState;
        return AnimatedBuilder(
          animation: drag == null
              ? animation
              : Listenable.merge([animation, drag]),
          child: child,
          builder: (context, child) {
            final progress = animation.value.clamp(0.0, 1.0);
            final dragged = drag?.value ?? UiFluidDragState.idle;
            final carried = monotonic
                ? null
                : (dragged.progress > 0 || dragged.offset != Offset.zero
                      ? draggedGeometry(
                          destination,
                          dragged,
                          sourceBorderRadius,
                          bounds,
                        )
                      : null);
            final origin = monotonic && dismissOrigin != null
                ? dismissOrigin!
                : destination;
            var frame = motion.sample(
              source: source,
              destination: origin,
              progress: progress,
              monotonic: monotonic,
              bounds: monotonic && dismissOrigin != null ? null : bounds,
              monotonicCurve: linearReverse
                  ? Curves.linear
                  : Curves.easeOutCubic,
            );
            if (carried != null) {
              frame = UiFluidMorphFrame(carried, 0, 1);
            }
            final lift = carried != null
                ? dragged.progress.clamp(0.0, 1.0)
                : math.sin(progress * math.pi);
            final shadows = BoxShadow.lerpList(
              const <BoxShadow>[],
              tokens.shadows.lg,
              lift,
            )!;
            final showSource = sourceBuilder != null && frame.sourceOpacity > 0;
            // A fly-back after a drag keeps the scrim where the drag left
            // it, so release does not flash the backdrop dark again.
            final dragFade = 1 - dragged.progress.clamp(0.0, 1.0);
            final scrimAlpha = carried != null
                ? dragFade
                : motion.scrimOpacity(progress) *
                      (monotonic && dismissOrigin != null ? dragFade : 1);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  key: const Key('ui_fluid_route_scrim'),
                  child: ColoredBox(
                    color: scrim.withValues(alpha: scrim.a * scrimAlpha),
                  ),
                ),
                if (showSource)
                  UiFluidSurface(
                    key: const Key('ui_fluid_route_source'),
                    geometry: frame.geometry,
                    contentSize: sourceRect.size,
                    color: surface,
                    shadows: shadows,
                    opacity: frame.sourceOpacity,
                    interactive: false,
                    child: sourceBuilder!(context),
                  ),
                UiFluidSurface(
                  key: const Key('ui_fluid_route_destination'),
                  geometry: frame.geometry,
                  contentSize: constraints.biggest,
                  fit: BoxFit.none,
                  alignment: Alignment.topLeft,
                  color: showSource ? const Color(0x00000000) : surface,
                  shadows: showSource ? const [] : shadows,
                  opacity: frame.destinationOpacity,
                  interactive: frame.destinationOpacity > 0,
                  child: child!,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Experimental: a compact surface that opens its page with
/// [UiFluidPageRoute] and hides itself while the page is open, so the
/// in-flight copy is the only visible instance.
class UiFluidOpenContainer extends StatefulWidget {
  const UiFluidOpenContainer({
    super.key,
    required this.closedBuilder,
    required this.pageBuilder,
    this.sourceBorderRadius,
    this.surfaceColor,
    this.scrimColor,
    this.motion = const UiFluidRouteMotion(),
    this.transitionDuration = UiFluidPageRoute.defaultTransitionDuration,
    this.reverseTransitionDuration =
        UiFluidPageRoute.defaultReverseTransitionDuration,
    this.swipeBackEnabled = true,
    this.dragToDismissEnabled = true,
    this.useRootNavigator = false,
  });

  final UiOpenContainerBuilder closedBuilder;
  final UiContainerPageBuilder pageBuilder;

  /// Defaults to the theme's `xl` corners, matching kit cards.
  final BorderRadius? sourceBorderRadius;
  final Color? surfaceColor;
  final Color? scrimColor;
  final UiFluidRouteMotion motion;
  final Duration transitionDuration;
  final Duration reverseTransitionDuration;
  final bool swipeBackEnabled;

  /// See [UiFluidPageRoute.dragToDismissEnabled].
  final bool dragToDismissEnabled;
  final bool useRootNavigator;

  @override
  State<UiFluidOpenContainer> createState() => _UiFluidOpenContainerState();
}

class _UiFluidOpenContainerState extends State<UiFluidOpenContainer> {
  final GlobalKey _sourceKey = GlobalKey();
  bool _open = false;

  Future<void> _openPage() async {
    if (_open) return;
    final navigator = Navigator.of(
      context,
      rootNavigator: widget.useRootNavigator,
    );
    final rect = _uiFluidSourceRect(_sourceKey, navigator);
    if (rect == null) return;
    final tokens = UiThemeTokens.of(context);
    setState(() => _open = true);
    try {
      await navigator.push(
        UiFluidPageRoute<void>(
          builder: widget.pageBuilder,
          sourceRect: rect,
          sourceRectResolver: () => _uiFluidSourceRect(_sourceKey, navigator),
          sourceBorderRadius: widget.sourceBorderRadius ?? tokens.radius.xlAll,
          sourceBuilder: (context) => widget.closedBuilder(context, () {}),
          surfaceColor: widget.surfaceColor,
          scrimColor: widget.scrimColor,
          motion: widget.motion,
          transitionDuration: UiMotionDuration.custom(widget.transitionDuration)
              .resolve(context),
          reverseTransitionDuration: UiMotionDuration.custom(
            widget.reverseTransitionDuration,
          ).resolve(context),
          swipeBackEnabled: widget.swipeBackEnabled,
          dragToDismissEnabled: widget.dragToDismissEnabled,
        ),
      );
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: _open,
    child: ExcludeSemantics(
      excluding: _open,
      child: Opacity(
        opacity: _open ? 0 : 1,
        child: RepaintBoundary(
          key: _sourceKey,
          // The closed surface is pressable on its own, like
          // [UiOpenContainer], so cards need not wire the callback.
          child: UiPressable(
            minTapSize: 0,
            onPressed: _openPage,
            builder: (context, state, _) {
              final tokens = UiThemeTokens.of(context);
              final surface = widget.surfaceColor ?? tokens.colors.surface;
              return UiBox(
                background: state.pressed
                    ? Color.alphaBlend(const Color(0x0A000000), surface)
                    : surface,
                border: Border.all(color: tokens.colors.border),
                borderRadius: widget.sourceBorderRadius ?? tokens.radius.xlAll,
                boxShadow: tokens.shadows.sm,
                clipBehavior: Clip.antiAlias,
                child: widget.closedBuilder(context, _openPage),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Experimental: pushes [builder] on a [UiFluidPageRoute] that grows out of
/// the widget identified by [sourceKey].
extension UiFluidPageNavigation on BuildContext {
  Future<T?> pushUiFluidPage<T>(
    WidgetBuilder builder, {
    required GlobalKey sourceKey,
    RouteSettings? settings,
    bool rootNavigator = false,
    BorderRadius? sourceBorderRadius,
    Color? surfaceColor,
    Color? scrimColor,
    UiFluidRouteMotion motion = const UiFluidRouteMotion(),
    Duration transitionDuration = UiFluidPageRoute.defaultTransitionDuration,
    Duration reverseTransitionDuration =
        UiFluidPageRoute.defaultReverseTransitionDuration,
    bool swipeBackEnabled = true,
  }) {
    final navigator = Navigator.of(this, rootNavigator: rootNavigator);
    final overlay = navigator.overlay?.context.findRenderObject();
    // An unmeasurable source still gets a fluid route: zoom from the
    // viewport center, like the platform's default zoom.
    final fallback = overlay is RenderBox && overlay.hasSize
        ? Rect.fromCenter(
            center: overlay.size.center(Offset.zero),
            width: 24,
            height: 24,
          )
        : const Rect.fromLTWH(0, 0, 24, 24);
    return navigator.push<T>(
      UiFluidPageRoute<T>(
        builder: builder,
        settings: settings,
        sourceRect: _uiFluidSourceRect(sourceKey, navigator) ?? fallback,
        sourceRectResolver: () => _uiFluidSourceRect(sourceKey, navigator),
        sourceBorderRadius:
            sourceBorderRadius ?? UiThemeTokens.radiusOf(this).xlAll,
        surfaceColor: surfaceColor,
        scrimColor: scrimColor,
        motion: motion,
        transitionDuration: UiMotionDuration.custom(transitionDuration)
            .resolve(this),
        reverseTransitionDuration: UiMotionDuration.custom(
          reverseTransitionDuration,
        ).resolve(this),
        swipeBackEnabled: swipeBackEnabled,
      ),
    );
  }
}

/// Rect of [key]'s render box in [navigator]'s overlay space, the space the
/// route transition is laid out in. `null` when either side is unmeasured.
Rect? _uiFluidSourceRect(GlobalKey key, NavigatorState navigator) {
  final box = key.currentContext?.findRenderObject();
  final overlay = navigator.overlay?.context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  if (overlay is! RenderBox || !overlay.hasSize) return null;
  return MatrixUtils.transformRect(
    box.getTransformTo(overlay),
    Offset.zero & box.size,
  );
}

/// Finger-carried state of a fluid page: [offset] from the page's resting
/// center and a `0..1` [progress] toward dismissal.
@immutable
class UiFluidDragState {
  const UiFluidDragState({required this.offset, required this.progress});

  static const idle = UiFluidDragState(offset: Offset.zero, progress: 0);

  final Offset offset;
  final double progress;

  bool get isIdle => offset == Offset.zero && progress == 0;

  static UiFluidDragState lerp(
    UiFluidDragState a,
    UiFluidDragState b,
    double t,
  ) {
    return UiFluidDragState(
      offset: Offset.lerp(a.offset, b.offset, t)!,
      progress: lerpDouble(a.progress, b.progress, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UiFluidDragState &&
      other.offset == offset &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(offset, progress);
}

/// Experimental: turns a drag anywhere on [child] into a media-viewer style
/// carry of the page, publishing [UiFluidDragState] for the route transition
/// to render.
///
/// Two inputs feed the same gesture. A free-form pan carries the page in
/// any direction; scrollables keep their own vertical drag, but a sideways
/// pull still carries the page, and once they are pulled past their top
/// edge the over-scroll (`dragDetails`) carries it too, so a list that is
/// already at the top dismisses like a plain page. Releasing past
/// [dismissThreshold], or flicking, calls [onDismiss] with the release
/// velocity; otherwise the page springs back into place from that same
/// position and speed.
class UiFluidDismissRegion extends StatefulWidget {
  const UiFluidDismissRegion({
    super.key,
    required this.state,
    required this.onDismiss,
    required this.child,
    this.enabled,
    this.dismissThreshold = .28,
    this.extent = 360,
  });

  final ValueNotifier<UiFluidDragState> state;

  /// Called with the release velocity (logical px/s) once a drag crosses
  /// the threshold or is flung.
  final ValueChanged<Offset> onDismiss;
  final ValueGetter<bool>? enabled;

  /// Progress beyond which a release dismisses.
  final double dismissThreshold;

  /// Travel (any direction) that maps to full progress.
  final double extent;
  final Widget child;

  @override
  State<UiFluidDismissRegion> createState() => _UiFluidDismissRegionState();
}

class _UiFluidDismissRegionState extends State<UiFluidDismissRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  // Two recognizers claim the pointer: the pan for free-form carries, and a
  // horizontal one so a sideways pull still wins over a vertical list. The
  // page itself follows the raw pointer, never a recognizer's axis delta.
  late final PanGestureRecognizer _pan;
  late final HorizontalDragGestureRecognizer _horizontal;
  UiFluidDragState _settleFrom = UiFluidDragState.idle;
  bool _dragging = false, _fromScroll = false, _dismissed = false;
  Offset _pointer = Offset.zero, _down = Offset.zero;
  Offset _origin = Offset.zero, _travel = Offset.zero;
  final VelocityTracker _velocity = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );
  final Stopwatch _clock = Stopwatch()..start();

  static const double _kFlingVelocity = 900; // px/s
  static final SpringDescription _settleSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: .9);

  @override
  void initState() {
    super.initState();
    _pan = PanGestureRecognizer(debugOwner: this);
    _horizontal = HorizontalDragGestureRecognizer(debugOwner: this);
    for (final DragGestureRecognizer recognizer in [_pan, _horizontal]) {
      recognizer.dragStartBehavior = DragStartBehavior.down;
      recognizer.onStart = (_) {
        _begin(fromScroll: false);
      };
      recognizer.onUpdate = (_) {
        _sync();
      };
      recognizer.onEnd = (details) {
        _end(details.velocity.pixelsPerSecond);
      };
      recognizer.onCancel = _cancel;
    }
    _settle.addListener(() {
      widget.state.value = UiFluidDragState.lerp(
        _settleFrom,
        UiFluidDragState.idle,
        _settle.value,
      );
    });
    _settle.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.state.value = UiFluidDragState.idle;
      }
    });
  }

  @override
  void dispose() {
    _pan.dispose();
    _horizontal.dispose();
    _settle.dispose();
    super.dispose();
  }

  bool get _enabled => widget.enabled?.call() ?? true;

  /// [overscroll] is how far a list is already pulled past its top when it
  /// hands the gesture over, so the page picks up that distance at once.
  void _begin({required bool fromScroll, double overscroll = 0}) {
    if (_dragging || _dismissed) return;
    _settle.stop();
    _dragging = true;
    _fromScroll = fromScroll;
    // A pan is anchored at the touch-down point so the slop travel counts;
    // an over-scroll handoff is anchored so the page already sits where the
    // list's rubber band is. Either way a still-settling page resumes from
    // where it is.
    final anchor = fromScroll
        ? _pointer - Offset(0, math.max(0.0, overscroll))
        : _down;
    _origin = anchor - widget.state.value.offset;
    _travel = _pointer - _origin;
    _velocity.addPosition(_clock.elapsed, _pointer);
  }

  /// Applies the latest raw pointer position to the carried state.
  void _sync() {
    if (!_dragging) return;
    _travel = _pointer - _origin;
    widget.state.value = UiFluidDragState(
      offset: _travel,
      progress: (_travel.distance / widget.extent).clamp(0.0, 1.0),
    );
  }

  void _end(Offset? velocity) {
    if (!_dragging) return;
    _dragging = false;
    final state = widget.state.value;
    final released = velocity ?? _velocity.getVelocity().pixelsPerSecond;
    final outward = _travel.distance == 0
        ? 0.0
        : (released.dx * _travel.dx + released.dy * _travel.dy) /
              _travel.distance;
    final flung = outward > _kFlingVelocity;
    if (_enabled && (flung || state.progress >= widget.dismissThreshold)) {
      _dismissed = true;
      widget.onDismiss(released);
      return;
    }
    _springBack(released);
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _springBack(Offset.zero);
  }

  /// Settles from the released position, continuing whatever part of the
  /// release velocity already heads home (in units of the way back per
  /// second), so the return never restarts from rest.
  void _springBack(Offset released) {
    _settleFrom = widget.state.value;
    final distance = _settleFrom.offset.distance;
    final homeward = distance == 0
        ? 0.0
        : -(released.dx * _settleFrom.offset.dx +
                  released.dy * _settleFrom.offset.dy) /
              distance;
    final velocity = math.max(0.0, homeward) / math.max(distance, 1.0);
    _settle.animateWith(
      SpringSimulation(_settleSpring, 0, 1.01, velocity)
        ..tolerance = const Tolerance(velocity: double.infinity, distance: .01),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_enabled && !_dragging) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    switch (notification) {
      case ScrollUpdateNotification(dragDetails: != null):
        final overTop = metrics.pixels < metrics.minScrollExtent - .5;
        if (overTop) {
          if (!_dragging) {
            _begin(
              fromScroll: true,
              overscroll: metrics.minScrollExtent - metrics.pixels,
            );
          }
          if (_fromScroll) _sync();
        } else if (_dragging && _fromScroll) {
          // Finger travelled back into the content: let it scroll.
          _cancel();
        }
      case OverscrollNotification(dragDetails: != null, :final overscroll)
          when overscroll < 0:
        if (!_dragging) _begin(fromScroll: true, overscroll: -overscroll);
        if (_fromScroll) _sync();
      case ScrollEndNotification() when _dragging && _fromScroll:
        _end(notification.dragDetails?.velocity.pixelsPerSecond);
      case UserScrollNotification(direction: ScrollDirection.idle)
          when _dragging && _fromScroll:
        _end(null);
      default:
        break;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointer = _down = event.position;
    if (_enabled) {
      _pan.addPointer(event);
      _horizontal.addPointer(event);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointer = event.position;
    if (_dragging) {
      _velocity.addPosition(_clock.elapsed, _pointer);
      if (_fromScroll) _sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
