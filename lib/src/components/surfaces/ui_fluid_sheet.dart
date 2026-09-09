import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/layout/ui_keyboard_geometry.dart';
import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/motion/ui_fluid_route_motion.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/scrolling/ui_scroll_configuration.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'fluid_bridge_path.dart';
import 'ui_fluid_surface.dart';
import 'ui_sheet.dart';

/// Experimental: presents a modal sheet that emerges from the widget under
/// [sourceKey] with the kit's fluid choreography instead of sliding up.
///
/// The sheet content is laid out bottom-anchored (like [UiSheetScope.show],
/// including [snap] and [maxWidth]) and measured after its first frame at
/// zero opacity; the sampled surface then springs from the source rect to
/// that rect. During the first half, while the two rects are apart, a
/// geometric neck ([fluidBridgePath]) joins the source to the emerging
/// surface. Dragging the sheet down scrubs the route controller along the
/// monotonic path; a fling or a drag past the threshold dismisses it.
///
/// [sourceBuilder] paints an undimmed copy of the source above the scrim
/// while the neck is attached; [UiFluidSheetAnchor] wires this up for you.
/// Without it the neck attaches to the dimmed source underneath.
///
/// Known limitation: the destination follows the current keyboard inset
/// but keyboard changes while the sheet is open are not animated.
Future<T?> showUiFluidSheet<T>(
  BuildContext context, {
  required GlobalKey sourceKey,
  required Widget Function(BuildContext, UiSheetController<T>) builder,
  WidgetBuilder? sourceBuilder,
  UiSheetSnap snap = const UiSheetSnap.fit(),
  double? maxWidth,
  BorderRadius? sheetBorderRadius,
  BorderRadius? sourceBorderRadius,
  Color? surfaceColor,
  Color? sourceColor,
  Color? scrimColor,
  bool barrierDismissible = true,
  bool isDismissible = true,
  UiFluidRouteMotion motion = const UiFluidRouteMotion(),
  Duration transitionDuration = const Duration(milliseconds: 612),
  Duration reverseTransitionDuration = const Duration(milliseconds: 480),
}) {
  final tokens = UiThemeTokens.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final source = _captureSource(
    sourceKey,
    navigator,
    direction: Directionality.of(context),
    fallbackRadius: sourceBorderRadius ?? tokens.radius.mdAll,
    fallbackColor: sourceColor ?? surfaceColor ?? tokens.colors.card,
    overrideRadius: sourceBorderRadius,
    overrideColor: sourceColor,
  );
  final capturedThemes = InheritedTheme.capture(
    from: context,
    to: navigator.context,
  );
  final sheetRadius = sheetBorderRadius ?? tokens.radius.xlTop;
  return navigator.push<T>(
    _UiFluidSheetRoute<T>(
      source: source,
      builder: builder,
      sourceBuilder: sourceBuilder,
      snap: snap,
      maxWidth: maxWidth,
      sheetBorderRadius: BorderRadius.only(
        topLeft: sheetRadius.topLeft,
        topRight: sheetRadius.topRight,
      ),
      surfaceColor: surfaceColor ?? tokens.colors.card,
      scrimColor: scrimColor ?? tokens.colors.overlay,
      barrierDismissible: barrierDismissible,
      barrierLabel: UiLocalizations.of(context).close,
      isDismissible: isDismissible,
      motion: motion,
      transitionDuration: UiMotionDuration.custom(transitionDuration)
          .resolve(context),
      reverseTransitionDuration: UiMotionDuration.custom(
        reverseTransitionDuration,
      ).resolve(context),
      capturedThemes: capturedThemes,
    ),
  );
}

/// Experimental: owns the source key for [showUiFluidSheet] and supplies the
/// undimmed source copy painted during the transition.
///
/// ```dart
/// UiFluidSheetAnchor<void>(
///   builder: (context, open) => UiButton(label: 'Filters', onPressed: open),
///   sheetBuilder: (context, controller) => UiSheet(child: ...),
/// )
/// ```
class UiFluidSheetAnchor<T> extends StatefulWidget {
  const UiFluidSheetAnchor({
    super.key,
    required this.builder,
    required this.sheetBuilder,
    this.onResult,
    this.snap = const UiSheetSnap.fit(),
    this.maxWidth,
    this.sheetBorderRadius,
    this.sourceBorderRadius,
    this.surfaceColor,
    this.sourceColor,
    this.scrimColor,
    this.barrierDismissible = true,
    this.isDismissible = true,
    this.motion = const UiFluidRouteMotion(),
  });

  /// Builds the source; call `open` to present the sheet.
  final Widget Function(BuildContext context, VoidCallback open) builder;
  final Widget Function(BuildContext, UiSheetController<T>) sheetBuilder;

  /// Receives the sheet's result once it closes.
  final ValueChanged<T?>? onResult;
  final UiSheetSnap snap;
  final double? maxWidth;
  final BorderRadius? sheetBorderRadius;
  final BorderRadius? sourceBorderRadius;
  final Color? surfaceColor;
  final Color? sourceColor;
  final Color? scrimColor;
  final bool barrierDismissible;
  final bool isDismissible;
  final UiFluidRouteMotion motion;

  @override
  State<UiFluidSheetAnchor<T>> createState() => _UiFluidSheetAnchorState<T>();
}

class _UiFluidSheetAnchorState<T> extends State<UiFluidSheetAnchor<T>> {
  final GlobalKey _sourceKey = GlobalKey();
  bool _presenting = false;

  Future<void> _open() async {
    if (_presenting) return;
    _presenting = true;
    try {
      final result = await showUiFluidSheet<T>(
        context,
        sourceKey: _sourceKey,
        builder: widget.sheetBuilder,
        sourceBuilder: (context) => widget.builder(context, () {}),
        snap: widget.snap,
        maxWidth: widget.maxWidth,
        sheetBorderRadius: widget.sheetBorderRadius,
        sourceBorderRadius: widget.sourceBorderRadius,
        surfaceColor: widget.surfaceColor,
        sourceColor: widget.sourceColor,
        scrimColor: widget.scrimColor,
        barrierDismissible: widget.barrierDismissible,
        isDismissible: widget.isDismissible,
        motion: widget.motion,
      );
      widget.onResult?.call(result);
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _sourceKey, child: widget.builder(context, _open));
}

@immutable
class _FluidSheetSource {
  const _FluidSheetSource(this.geometry, this.color);
  final UiFluidGeometry geometry;
  final Color color;
}

// Measure against the root navigator's overlay, the space the modal route's
// transition is laid out in. Only the kit's UiBox surface is inspected for
// paint values; an unmeasurable source emerges from the bottom edge.
_FluidSheetSource _captureSource(
  GlobalKey key,
  NavigatorState navigator, {
  required TextDirection direction,
  required BorderRadius fallbackRadius,
  required Color fallbackColor,
  BorderRadius? overrideRadius,
  Color? overrideColor,
}) {
  final box = key.currentContext?.findRenderObject();
  final overlay = navigator.overlay?.context.findRenderObject();
  if (box is! RenderBox ||
      !box.attached ||
      !box.hasSize ||
      overlay is! RenderBox ||
      !overlay.hasSize) {
    final size = overlay is RenderBox && overlay.hasSize
        ? overlay.size
        : const Size(320, 640);
    return _FluidSheetSource(
      UiFluidGeometry(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height),
          width: 48,
          height: 8,
        ),
        0,
        corners: fallbackRadius,
      ),
      fallbackColor,
    );
  }
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(overlay),
    Offset.zero & box.size,
  );
  UiBox? surface;
  void visit(Element element) {
    if (surface != null) return;
    if (element.widget case final UiBox found) {
      surface = found;
      return;
    }
    element.visitChildren(visit);
  }

  final root = key.currentContext;
  if (root is Element) visit(root);
  // Resolve oversized pill tokens to the corners actually painted so the
  // outline interpolates from its real curvature instead of snapping late.
  final resolved = (overrideRadius ?? surface?.borderRadius ?? fallbackRadius)
      .resolve(direction)
      .toRRect(Offset.zero & box.size)
      .scaleRadii();
  return _FluidSheetSource(
    UiFluidGeometry(
      rect,
      0,
      corners: BorderRadius.only(
        topLeft: resolved.tlRadius,
        topRight: resolved.trRadius,
        bottomLeft: resolved.blRadius,
        bottomRight: resolved.brRadius,
      ),
    ),
    overrideColor ?? surface?.background ?? fallbackColor,
  );
}

class _UiFluidSheetRoute<T> extends PopupRoute<T> {
  _UiFluidSheetRoute({
    required this.source,
    required this.builder,
    required this.sourceBuilder,
    required this.snap,
    required this.maxWidth,
    required this.sheetBorderRadius,
    required this.surfaceColor,
    required this.scrimColor,
    required this.barrierDismissible,
    required this.barrierLabel,
    required this.isDismissible,
    required this.motion,
    required this.transitionDuration,
    required this.reverseTransitionDuration,
    required this.capturedThemes,
  });

  final _FluidSheetSource source;
  final Widget Function(BuildContext, UiSheetController<T>) builder;
  final WidgetBuilder? sourceBuilder;
  final UiSheetSnap snap;
  final double? maxWidth;
  final BorderRadius sheetBorderRadius;
  final Color surfaceColor;
  final Color scrimColor;
  final bool isDismissible;
  final UiFluidRouteMotion motion;
  final CapturedThemes capturedThemes;

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  /// The scrim is painted inside the transition on the fluid clock.
  @override
  Color? get barrierColor => null;

  /// Scrubbed directly by the sheet's drag, like the edge-swipe back gesture.
  AnimationController? get animationController => controller;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final controller = UiSheetController<T>.custom(([r]) {
      Navigator.of(context).maybePop(r);
    });
    return capturedThemes.wrap(
      UiScrollConfiguration(child: builder(context, controller)),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _UiFluidSheetTransition(
    route: this,
    animation: animation,
    monotonic:
        animation.status == AnimationStatus.reverse ||
        (navigator?.userGestureInProgress ?? false),
    child: child,
  );
}

class _UiFluidSheetTransition<T> extends StatefulWidget {
  const _UiFluidSheetTransition({
    required this.route,
    required this.animation,
    required this.monotonic,
    required this.child,
  });

  final _UiFluidSheetRoute<T> route;
  final Animation<double> animation;
  final bool monotonic;
  final Widget child;

  @override
  State<_UiFluidSheetTransition<T>> createState() =>
      _UiFluidSheetTransitionState<T>();
}

class _UiFluidSheetTransitionState<T>
    extends State<_UiFluidSheetTransition<T>> {
  Size? _sheetSize;
  double _dragOffset = 0;
  double _dragExtent = 1;
  bool _dragging = false;

  static const double _flingVelocity = 500;
  static const double _dismissOffset = 120;

  void _onSize(Size size) {
    if (!mounted || _sheetSize == size) return;
    setState(() => _sheetSize = size);
  }

  void _dragStart(DragStartDetails details, double extent) {
    _dragging = true;
    _dragOffset = 0;
    _dragExtent = math.max(1, extent);
    widget.route.navigator?.didStartUserGesture();
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _dragOffset = math.max(0, _dragOffset + details.delta.dy);
    widget.route.animationController?.value = (1 - _dragOffset / _dragExtent)
        .clamp(0.0, 1.0);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final navigator = widget.route.navigator;
    final controller = widget.route.animationController;
    if (navigator == null || controller == null) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > _flingVelocity || _dragOffset > _dismissOffset) {
      // didPop reverses the controller from its scrubbed value.
      navigator.pop();
    } else {
      controller.forward();
    }
    // Keep sampling the monotonic path until the release animation lands,
    // exactly like the edge-swipe controller: switching back to the spring
    // mid-flight would jump the geometry.
    if (controller.isAnimating) {
      late AnimationStatusListener done;
      done = (_) {
        controller.removeStatusListener(done);
        if (navigator.mounted) navigator.didStopUserGesture();
      };
      controller.addStatusListener(done);
    } else {
      navigator.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    if (_dragging) {
      final navigator = widget.route.navigator;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator?.mounted ?? false) navigator!.didStopUserGesture();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final tokens = UiThemeTokens.of(context);
    final keyboard = UiKeyboardGeometry.currentInsetOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Offset.zero & constraints.biggest;
        final width = route.maxWidth == null
            ? constraints.maxWidth
            : math.min(route.maxWidth!, constraints.maxWidth);
        final left = (constraints.maxWidth - width) / 2;
        final bottom = constraints.maxHeight - keyboard;
        final maxHeight = math.max(
          1.0,
          route.snap.isFit
              ? bottom
              : constraints.maxHeight * (route.snap.fraction ?? 1),
        );
        final height = math.min(_sheetSize?.height ?? maxHeight, maxHeight);
        final destination = UiFluidGeometry(
          Rect.fromLTWH(left, bottom - height, width, height),
          0,
          corners: route.sheetBorderRadius,
        );
        final contentSize = Size(width, maxHeight);
        return AnimatedBuilder(
          animation: widget.animation,
          child: widget.child,
          builder: (context, child) {
            final progress = widget.animation.value.clamp(0.0, 1.0);
            final frame = route.motion.sample(
              source: route.source.geometry,
              destination: destination,
              progress: progress,
              monotonic: widget.monotonic,
              bounds: bounds,
            );
            final separated = !frame.geometry.rect.overlaps(
              route.source.geometry.rect,
            );
            final neck = progress < .5 && separated
                ? fluidBridgeStrength(progress / .5)
                : 0.0;
            // The undimmed source copy lingers while the neck is attached,
            // then hands back to the real (dimmed) source underneath.
            final retained = 1 - _ease((progress - .45) / .25);
            final plate = Color.lerp(
              route.source.color,
              route.surfaceColor,
              _ease(progress / .4),
            )!;
            final sourceCopy = route.sourceBuilder;
            Widget sheet = Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: _MeasureSize(onSize: _onSize, child: child!),
              ),
            );
            if (route.isDismissible) {
              sheet = GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (d) => _dragStart(d, height),
                onVerticalDragUpdate: _dragUpdate,
                onVerticalDragEnd: _dragEnd,
                onVerticalDragCancel: () =>
                    _dragEnd(DragEndDetails(primaryVelocity: 0)),
                child: sheet,
              );
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Pointer-transparent so taps outside reach the modal barrier.
                Positioned.fill(
                  key: const Key('ui_fluid_sheet_scrim'),
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: route.scrimColor.withValues(
                        alpha:
                            route.scrimColor.a *
                            route.motion.scrimOpacity(progress),
                      ),
                    ),
                  ),
                ),
                if (neck > 0)
                  Positioned.fill(
                    key: const Key('ui_fluid_sheet_neck'),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _NeckPainter(
                          route.source.geometry,
                          frame.geometry,
                          plate,
                          neck,
                        ),
                      ),
                    ),
                  ),
                if (sourceCopy != null && retained > 0)
                  UiFluidSurface(
                    key: const Key('ui_fluid_sheet_source'),
                    geometry: route.source.geometry,
                    contentSize: route.source.geometry.rect.size,
                    color: route.source.color.withValues(
                      alpha: route.source.color.a * retained,
                    ),
                    opacity: retained,
                    interactive: false,
                    child: sourceCopy(context),
                  ),
                UiFluidSurface(
                  key: const Key('ui_fluid_sheet_surface'),
                  geometry: frame.geometry,
                  contentSize: contentSize,
                  fit: BoxFit.none,
                  alignment: Alignment.bottomCenter,
                  color: plate,
                  shadows: BoxShadow.lerpList(
                    const <BoxShadow>[],
                    tokens.shadows.lg,
                    math.min(1, progress * 2),
                  )!,
                  opacity: frame.destinationOpacity,
                  interactive: frame.destinationOpacity > 0,
                  child: sheet,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

double _ease(double t) {
  final p = t.clamp(0.0, 1.0);
  return p * p * (3 - 2 * p);
}

class _NeckPainter extends CustomPainter {
  const _NeckPainter(this.source, this.target, this.color, this.strength);
  final UiFluidGeometry source;
  final UiFluidGeometry target;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      fluidBridgePath(source, target, strength),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_NeckPainter old) =>
      color != old.color ||
      strength != old.strength ||
      source.rect != old.source.rect ||
      target.rect != old.target.rect;
}

/// Reports the child's laid-out size after the frame so the destination
/// rect can adopt the sheet's natural height.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onSize);
  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}
