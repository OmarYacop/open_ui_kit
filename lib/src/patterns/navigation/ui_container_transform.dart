import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/motion/ui_fluid_route_motion.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/motion/ui_shared_morph.dart';
import '../../foundation/primitives/ui_corner_clip.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

typedef UiOpenContainerBuilder = Widget Function(
  BuildContext context,
  VoidCallback open,
);

typedef UiContainerPageBuilder = Widget Function(BuildContext context);
typedef UiContainerFlightBuilder = Widget Function(BuildContext context);

double _directionalCurveProgress(
  double value,
  Curve curve, {
  required bool reversing,
}) {
  final progress = value.clamp(0.0, 1.0);
  if (!reversing) return curve.transform(progress);
  return 1 - curve.transform(1 - progress);
}

_UiContentSwitchState _contentSwitchState(
  double value,
  Curve curve, {
  required Duration switchTime,
  required Duration transitionDuration,
  required Duration totalDuration,
}) {
  if (totalDuration <= Duration.zero) {
    return _UiContentSwitchState(showExpanded: value >= 1, coverOpacity: 0);
  }
  final switchProgress =
      (switchTime.inMicroseconds / totalDuration.inMicroseconds).clamp(
        0.0,
        1.0,
      );
  final showExpanded = value >= switchProgress;
  if (transitionDuration <= Duration.zero) {
    return _UiContentSwitchState(showExpanded: showExpanded, coverOpacity: 0);
  }

  final halfPhaseExtent =
      (transitionDuration.inMicroseconds / totalDuration.inMicroseconds).clamp(
        0.0,
        1.0,
      ) /
      2;
  if (halfPhaseExtent <= 0) {
    return _UiContentSwitchState(showExpanded: showExpanded, coverOpacity: 0);
  }
  final distanceFromSwitch = ((value - switchProgress).abs() / halfPhaseExtent)
      .clamp(0.0, 1.0);
  return _UiContentSwitchState(
    showExpanded: showExpanded,
    coverOpacity: curve.transform(1 - distanceFromSwitch),
  );
}

class _UiContentSwitchState {
  const _UiContentSwitchState({
    required this.showExpanded,
    required this.coverOpacity,
  });

  final bool showExpanded;
  final double coverOpacity;
}

/// Timing and material used to conceal a content identity swap during a
/// container transform.
///
/// Use [resolve] for theme-token timing or [custom] for an authored duration
/// that still respects the platform's reduced-motion preference.
@immutable
class UiContentOcclusionSpec {
  const UiContentOcclusionSpec({
    required this.switchTime,
    required this.duration,
    this.curve = UiSharedMorphMotion.contentCurve,
    this.peakOpacity = 0.94,
    this.color,
  }) : assert(switchTime >= Duration.zero),
       assert(duration >= Duration.zero),
       assert(peakOpacity >= 0 && peakOpacity <= 1);

  factory UiContentOcclusionSpec.resolve(
    BuildContext context, {
    UiMotionSpeed switchTime = UiMotionSpeed.fast,
    UiMotionSpeed duration = UiMotionSpeed.fast,
    Curve curve = UiSharedMorphMotion.contentCurve,
    double peakOpacity = 0.94,
    Color? color,
  }) {
    return UiContentOcclusionSpec.resolveTiming(
      context,
      switchTime: UiMotionDuration.token(switchTime),
      duration: UiMotionDuration.token(duration),
      curve: curve,
      peakOpacity: peakOpacity,
      color: color,
    );
  }

  factory UiContentOcclusionSpec.resolveTiming(
    BuildContext context, {
    UiMotionDuration switchTime = UiMotionDuration.fast,
    UiMotionDuration duration = UiMotionDuration.fast,
    Curve curve = UiSharedMorphMotion.contentCurve,
    double peakOpacity = 0.94,
    Color? color,
  }) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return UiContentOcclusionSpec(
      switchTime: switchTime.resolve(context),
      duration: duration.resolve(context),
      curve: reduceMotion ? Curves.linear : curve,
      peakOpacity: peakOpacity,
      color: color,
    );
  }

  factory UiContentOcclusionSpec.custom(
    BuildContext context, {
    required Duration switchTime,
    required Duration duration,
    Curve curve = UiSharedMorphMotion.contentCurve,
    double peakOpacity = 0.94,
    Color? color,
  }) {
    return UiContentOcclusionSpec.resolveTiming(
      context,
      switchTime: UiMotionDuration.custom(switchTime),
      duration: UiMotionDuration.custom(duration),
      curve: curve,
      peakOpacity: peakOpacity,
      color: color,
    );
  }

  /// Point measured from the collapsed endpoint where content swaps.
  final Duration switchTime;

  /// Total cover-and-reveal duration centered on [switchTime].
  final Duration duration;

  /// Curve applied independently to each half of the cover-and-reveal.
  final Curve curve;

  /// Maximum cover opacity at [switchTime].
  final double peakOpacity;

  /// Optional cover color. When null, the destination state's surface color is
  /// used in each direction.
  final Color? color;
}

enum UiContainerTransformStyle {
  container,

  /// Expands a colored source plate while revealing full-size destination
  /// content through an animated rounded clip.
  iosZoom,

  /// Experimental: the [iosZoom] Hero rig driven by the kit's fluid sampler
  /// ([UiFluidRouteMotion]). The source briefly gathers, then springs into
  /// the page with a bounded overshoot; content cross-fades on the same
  /// clock and corners use the continuous [UiCornerClip]. Pops and
  /// edge-swipe gestures fly back on a monotonic ease. See ADR 0006.
  fluidZoom,
}

/// How the route behind an iOS-style container transform is separated from
/// the expanding surface.
enum UiContainerBackdropStyle {
  /// Use blur when the active effects budget allows it, otherwise use tint.
  adaptive,

  /// Blur the exposed route and add a subtle tint for contrast.
  blur,

  /// Draw only an animated translucent color. This avoids backdrop sampling.
  tint,

  /// Do not draw a backdrop treatment.
  none,
}

/// Configures the performance tier and appearance of a container backdrop.
@immutable
class UiContainerBackdropSpec {
  const UiContainerBackdropSpec({
    this.style = UiContainerBackdropStyle.adaptive,
    this.blurSigma = 8,
    this.tintColor,
    this.tintOpacity = 0.14,
    this.curve,
  }) : assert(blurSigma >= 0),
       assert(tintOpacity >= 0 && tintOpacity <= 1);

  const UiContainerBackdropSpec.blur({
    this.blurSigma = 8,
    this.tintColor,
    this.tintOpacity = 0.14,
    this.curve,
  }) : style = UiContainerBackdropStyle.blur,
       assert(blurSigma >= 0),
       assert(tintOpacity >= 0 && tintOpacity <= 1);

  const UiContainerBackdropSpec.tint({
    this.tintColor,
    this.tintOpacity = 0.14,
    this.curve,
  }) : style = UiContainerBackdropStyle.tint,
       blurSigma = 0,
       assert(tintOpacity >= 0 && tintOpacity <= 1);

  const UiContainerBackdropSpec.none()
    : style = UiContainerBackdropStyle.none,
      blurSigma = 0,
      tintColor = null,
      tintOpacity = 0,
      curve = null;

  final UiContainerBackdropStyle style;
  final double blurSigma;
  final Color? tintColor;
  final double tintOpacity;
  final Curve? curve;
}

/// Path used by the animated container bounds.
enum UiContainerPathMotion {
  /// Position and size use the same geometric progress.
  direct,

  /// Translation leads scale near either endpoint, pulling the surface toward
  /// its destination before the size change becomes dominant.
  centerPull,
}

/// How compact content participates in an iOS-style container flight.
enum UiContainerSourceFlightLayout {
  /// Preserve the compact source's original layout and reveal it through the
  /// changing wrapper clip.
  fixed,

  /// Re-layout compact content against the wrapper's live animated bounds.
  /// Use this for cards designed to grow into their destination surface.
  responsive,
}

enum UiContainerFlightDirection { opening, closing }

/// Live geometry exposed to content inside an Open UI container transform.
///
/// Components can read this scope to adapt their internal layout, corner
/// treatment, or emphasis while the wrapper grows and contracts.
class UiContainerFlightScope extends InheritedWidget {
  const UiContainerFlightScope({
    super.key,
    required this.progress,
    required this.size,
    required this.borderRadius,
    required this.inFlight,
    required this.direction,
    required super.child,
  });

  final double progress;
  final Size size;
  final BorderRadius borderRadius;
  final bool inFlight;
  final UiContainerFlightDirection? direction;

  static UiContainerFlightScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UiContainerFlightScope>();
  }

  static UiContainerFlightScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No UiContainerFlightScope found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(UiContainerFlightScope oldWidget) {
    return progress != oldWidget.progress ||
        size != oldWidget.size ||
        borderRadius != oldWidget.borderRadius ||
        inFlight != oldWidget.inFlight ||
        direction != oldWidget.direction;
  }
}

/// Eases [child] in and out with the ambient [UiContainerFlightScope]
/// progress instead of popping with the rest of the destination content.
///
/// Meant for chrome that sits on top of a container transform's destination
/// page — a back button, trailing actions — so it reads as dissolving into
/// focus the way iOS bar-button content transitions do, rather than
/// appearing abruptly at the content-occlusion switch point. Fades in over
/// the top [revealStart] fraction of the flight (on both push and pop, since
/// [UiContainerFlightScope.progress] is 1 at the fully open end regardless of
/// direction) while a blur relaxes to zero across the same window.
///
/// Renders [child] unchanged where no [UiContainerFlightScope] is in scope
/// (progress defaults to 1), and skips the blur under reduced motion.
class UiContainerFlightReveal extends StatelessWidget {
  const UiContainerFlightReveal({
    super.key,
    required this.child,
    this.revealStart = 0.55,
    this.maxBlurSigma = 8,
    this.curve = Curves.easeOut,
  }) : assert(revealStart >= 0 && revealStart < 1),
       assert(maxBlurSigma >= 0);

  final Widget child;

  /// Progress fraction where the reveal begins; 1 is the fully open end.
  final double revealStart;
  final double maxBlurSigma;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final progress = UiContainerFlightScope.maybeOf(context)?.progress ?? 1;
    final reveal = ((progress - revealStart) / (1 - revealStart)).clamp(
      0.0,
      1.0,
    );
    final eased = curve.transform(reveal);
    if (eased >= 1) return child;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget result = Opacity(opacity: eased, child: child);
    final blurSigma = reduceMotion ? 0.0 : (1 - eased) * maxBlurSigma;
    if (blurSigma > 0.01) {
      result = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: result,
      );
    }
    return IgnorePointer(ignoring: eased < 0.99, child: result);
  }
}

/// Geometry shared by iOS-style source tiles and their route transition.
abstract final class UiContainerTransformGeometry {
  /// A compact source uses a pronounced continuous-corner silhouette instead
  /// of a fixed component radius. This keeps the perceived curvature stable
  /// across phone and tablet grid sizes.
  static const double iosSourceCornerFraction = 0.36;
  static const double iosSourceCornerMinimum = 36;
  static const double iosSourceCornerMaximum = 72;

  /// Reversible progress that moves faster near both endpoints while remaining
  /// monotonic. Forward and reverse flights therefore receive the same visual
  /// emphasis without direction-specific sequencing.
  static double centerPullProgress(double progress, {double strength = 0.65}) {
    assert(strength >= 0 && strength <= 1);
    final t = progress.clamp(0.0, 1.0);
    final smooth = t * t * (3 - 2 * t);
    return (t + (t - smooth) * strength).clamp(0.0, 1.0);
  }

  static BorderRadius iosSourceBorderRadius(
    Size size, {
    double cornerFraction = iosSourceCornerFraction,
  }) {
    assert(cornerFraction > 0 && cornerFraction <= 0.5);
    final shortestSide = size.shortestSide;
    if (!shortestSide.isFinite || shortestSide <= 0) {
      return BorderRadius.zero;
    }

    final maximum = math.min(iosSourceCornerMaximum, shortestSide / 2);
    final minimum = math.min(iosSourceCornerMinimum, maximum);
    final radius = (shortestSide * cornerFraction).clamp(minimum, maximum);
    return BorderRadius.circular(radius);
  }

  /// Infers the physical screen curvature from the safe-area signals Flutter
  /// exposes. Flutter has no direct screen-corner API, so callers can still
  /// override [UiOpenContainer.destinationBorderRadius] for custom hardware.
  static BorderRadius iosScreenBorderRadius(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null || mediaQuery.size.isEmpty) {
      return BorderRadius.zero;
    }

    final insets = mediaQuery.viewPadding;
    final safeAreaSignal = math.max(
      math.max(insets.top * 0.94, insets.bottom * 1.18),
      math.max(insets.left * 0.96, insets.right * 0.96),
    );
    final shortestSide = mediaQuery.size.shortestSide;

    // Ordinary system bars should not manufacture rounded screen corners.
    if (safeAreaSignal < shortestSide * 0.085) {
      return BorderRadius.zero;
    }

    final radius = safeAreaSignal.clamp(
      shortestSide * 0.09,
      shortestSide * 0.15,
    );
    return BorderRadius.circular(radius);
  }
}

/// Connects a compact source surface to a full-page destination.
///
/// Unlike a generic page transition, this measures the source in the active
/// navigator's coordinate space and grows the destination surface from those
/// exact bounds. The destination keeps full-page constraints throughout the
/// flight and is revealed through an animated clip, avoiding per-frame layout
/// churn and semantics instability.
class UiOpenContainer extends StatefulWidget {
  const UiOpenContainer({
    super.key,
    required this.closedBuilder,
    required this.pageBuilder,
    this.sourceBorderRadius,
    this.destinationBorderRadius,
    this.surfaceColor,
    this.destinationSurfaceColor,
    this.sourceBorderColor,
    this.sourceBoxShadow,
    this.scrimColor,
    this.backdrop = const UiContainerBackdropSpec(),
    this.backdropBlurSigma,
    this.motion,
    this.contentOcclusion,
    this.effectCurve = UiSharedMorphMotion.effectCurve,
    this.flightBuilder,
    this.style = UiContainerTransformStyle.container,
    this.sourceFlightLayout = UiContainerSourceFlightLayout.fixed,
    this.pathMotion = UiContainerPathMotion.centerPull,
    this.centerPullStrength = 0.65,
    this.iosZoomSourceRadiusFraction =
        UiContainerTransformGeometry.iosSourceCornerFraction,
    this.fluidMotion = const UiFluidRouteMotion(),
    this.useRootNavigator = false,
  }) : assert(
         iosZoomSourceRadiusFraction > 0 && iosZoomSourceRadiusFraction <= 0.5,
       ),
       assert(centerPullStrength >= 0 && centerPullStrength <= 1),
       assert(backdropBlurSigma == null || backdropBlurSigma >= 0);

  final UiOpenContainerBuilder closedBuilder;
  final UiContainerPageBuilder pageBuilder;
  final BorderRadius? sourceBorderRadius;
  final BorderRadius? destinationBorderRadius;
  final Color? surfaceColor;
  final Color? destinationSurfaceColor;
  final Color? sourceBorderColor;
  final List<BoxShadow>? sourceBoxShadow;
  final Color? scrimColor;
  final UiContainerBackdropSpec backdrop;

  /// Legacy full-screen blur override for
  /// [UiContainerTransformStyle.iosZoom].
  ///
  /// Prefer [backdrop], which provides adaptive tint and no-effect fallbacks.
  @Deprecated(
    'Use backdrop with UiContainerBackdropSpec instead. Scheduled for removal in 1.0.0.',
  )
  final double? backdropBlurSigma;

  final UiMotionSpec? motion;

  /// Controls the content swap independently from container geometry and
  /// effects. When omitted, fast theme timing is used.
  final UiContentOcclusionSpec? contentOcclusion;

  final Curve effectCurve;
  final UiContainerFlightBuilder? flightBuilder;
  final UiContainerTransformStyle style;
  final UiContainerSourceFlightLayout sourceFlightLayout;

  /// Controls whether position follows scale directly or leads it toward the
  /// destination center near the animation endpoints.
  final UiContainerPathMotion pathMotion;

  /// Strength of [UiContainerPathMotion.centerPull], from zero to one.
  final double centerPullStrength;

  /// Controls the compact source's normalized corner geometry when
  /// [sourceBorderRadius] is not supplied.
  final double iosZoomSourceRadiusFraction;

  /// Experimental: sampler tuning for [UiContainerTransformStyle.fluidZoom].
  /// Ignored by the other styles.
  final UiFluidRouteMotion fluidMotion;
  final bool useRootNavigator;

  @override
  State<UiOpenContainer> createState() => _UiOpenContainerState();
}

class _UiOpenContainerState extends State<UiOpenContainer> {
  final GlobalKey _sourceKey = GlobalKey();
  final Object _sharedContainerTag = Object();
  bool _opening = false;

  UiMotionSpec _resolveMotion(BuildContext context) {
    return widget.motion ??
        UiMotionSpec.resolve(
          context,
          duration: UiMotionSpeed.slow,
          reverseDuration: UiMotionSpeed.slow,
          curve: UiSharedMorphMotion.curve,
          reverseCurve: UiSharedMorphMotion.curve,
        );
  }

  UiContentOcclusionSpec _resolveContentOcclusion(UiThemeTokens tokens) {
    return widget.contentOcclusion ??
        UiContentOcclusionSpec(
          switchTime: tokens.motion.fast,
          duration: tokens.motion.fast,
        );
  }

  Future<void> _open() async {
    if (_opening) return;
    final source = _sourceKey.currentContext?.findRenderObject();
    if (source is! RenderBox || !source.hasSize) return;

    final navigator = Navigator.of(
      context,
      rootNavigator: widget.useRootNavigator,
    );
    final overlay = navigator.overlay?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return;

    final origin = source.localToGlobal(Offset.zero, ancestor: overlay);
    final sourceRect = origin & source.size;
    final tokens = UiThemeTokens.of(context);
    final usesIosZoom = widget.style != UiContainerTransformStyle.container;
    final sourceBorderRadius =
        widget.sourceBorderRadius ??
        (usesIosZoom
            ? UiContainerTransformGeometry.iosSourceBorderRadius(
                source.size,
                cornerFraction: widget.iosZoomSourceRadiusFraction,
              )
            : tokens.radius.xlAll);
    final destinationBorderRadius =
        widget.destinationBorderRadius ??
        (usesIosZoom
            ? UiContainerTransformGeometry.iosScreenBorderRadius(context)
            : BorderRadius.zero);
    final motion = _resolveMotion(context);
    final contentOcclusion = _resolveContentOcclusion(tokens);
    final backdrop = _resolveBackdrop(tokens);

    _opening = true;
    if (mounted) setState(() {});
    try {
      if (usesIosZoom) {
        await navigator.push(
          _UiSharedContainerRoute<void>(
            tag: _sharedContainerTag,
            motion: motion,
            destinationBorderRadius: destinationBorderRadius,
            destinationSurfaceColor:
                widget.destinationSurfaceColor ?? tokens.colors.background,
            backdrop: backdrop,
            contentOcclusion: contentOcclusion,
            sourceFlightLayout: widget.sourceFlightLayout,
            pathMotion: widget.pathMotion,
            centerPullStrength: widget.centerPullStrength,
            fluidMotion: _fluidMotion,
            pageBuilder: widget.pageBuilder,
          ),
        );
      } else {
        await navigator.push(
          UiContainerTransformRoute<void>(
            sourceRect: sourceRect,
            sourceBorderRadius: sourceBorderRadius,
            destinationBorderRadius: destinationBorderRadius,
            surfaceColor: widget.surfaceColor ?? tokens.colors.surface,
            scrimColor: widget.scrimColor ?? const Color(0x00000000),
            motion: motion,
            sourceSize: source.size,
            sourceChild: widget.flightBuilder?.call(context),
            pageBuilder: widget.pageBuilder,
          ),
        );
      }
    } finally {
      _opening = false;
      if (mounted) setState(() {});
    }
  }

  UiFluidRouteMotion? get _fluidMotion =>
      widget.style == UiContainerTransformStyle.fluidZoom
      ? widget.fluidMotion
      : null;

  _ResolvedContainerBackdrop _resolveBackdrop(UiThemeTokens tokens) {
    final legacySigma = widget.backdropBlurSigma;
    if (legacySigma != null) {
      if (legacySigma <= 0) {
        return const _ResolvedContainerBackdrop.none();
      }
      final scaledSigma = tokens.effects.scaleBlur(legacySigma);
      if (scaledSigma <= 0 || !tokens.effects.animateBlur) {
        return _ResolvedContainerBackdrop(
          blurSigma: 0,
          tintColor: widget.scrimColor ?? tokens.colors.overlay,
          tintOpacity: widget.backdrop.tintOpacity,
          curve: widget.backdrop.curve ?? widget.effectCurve,
        );
      }
      return _ResolvedContainerBackdrop(
        blurSigma: scaledSigma,
        tintColor: widget.scrimColor ?? tokens.colors.overlay,
        tintOpacity: 0,
        curve: widget.backdrop.curve ?? widget.effectCurve,
      );
    }

    final spec = widget.backdrop;
    var style = spec.style;
    if (style == UiContainerBackdropStyle.adaptive) {
      style = tokens.effects.allowsBackdropBlur && tokens.effects.animateBlur
          ? UiContainerBackdropStyle.blur
          : UiContainerBackdropStyle.tint;
    }
    if (style == UiContainerBackdropStyle.none) {
      return const _ResolvedContainerBackdrop.none();
    }

    var blurSigma = 0.0;
    if (style == UiContainerBackdropStyle.blur) {
      blurSigma = tokens.effects.scaleBlur(spec.blurSigma);
      if (blurSigma <= 0 || !tokens.effects.animateBlur) {
        style = UiContainerBackdropStyle.tint;
        blurSigma = 0;
      }
    }

    return _ResolvedContainerBackdrop(
      blurSigma: blurSigma,
      tintColor: spec.tintColor ?? widget.scrimColor ?? tokens.colors.overlay,
      tintOpacity: spec.tintOpacity,
      curve: spec.curve ?? widget.effectCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style != UiContainerTransformStyle.container) {
      final tokens = UiThemeTokens.of(context);
      final motion = _resolveMotion(context);
      final contentOcclusion = _resolveContentOcclusion(tokens);
      return LayoutBuilder(
        builder: (context, constraints) {
          final sourceSize = Size(
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : constraints.minWidth > 0
                ? constraints.minWidth
                : 300,
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : constraints.minHeight > 0
                ? constraints.minHeight
                : 360,
          );
          final sourceBorderRadius =
              widget.sourceBorderRadius ??
              UiContainerTransformGeometry.iosSourceBorderRadius(
                sourceSize,
                cornerFraction: widget.iosZoomSourceRadiusFraction,
              );

          return IgnorePointer(
            ignoring: _opening,
            child: RepaintBoundary(
              key: _sourceKey,
              child: _UiSharedContainerHero(
                tag: _sharedContainerTag,
                role: _UiSharedContainerRole.compact,
                naturalSize: sourceSize,
                borderRadius: sourceBorderRadius,
                backgroundColor: widget.surfaceColor ?? tokens.colors.surface,
                border: Border.all(
                  color: widget.sourceBorderColor ?? tokens.colors.border,
                ),
                boxShadow: widget.sourceBoxShadow ?? tokens.shadows.sm,
                curve: motion.curve,
                contentOcclusion: contentOcclusion,
                forwardDuration: motion.duration,
                reverseDuration: motion.reverseDuration,
                sourceFlightLayout: widget.sourceFlightLayout,
                pathMotion: widget.pathMotion,
                centerPullStrength: widget.centerPullStrength,
                fluidMotion: _fluidMotion,
                child: UiPressable(
                  minTapSize: 0,
                  onPressed: _open,
                  builder: (context, state, _) => ColoredBox(
                    color: state.pressed
                        ? const Color(0x0A000000)
                        : const Color(0x00000000),
                    child: widget.closedBuilder(context, _open),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return IgnorePointer(
      ignoring: _opening,
      child: ExcludeSemantics(
        excluding: _opening,
        child: Opacity(
          opacity: _opening ? 0 : 1,
          child: RepaintBoundary(
            key: _sourceKey,
            child: widget.closedBuilder(context, _open),
          ),
        ),
      ),
    );
  }
}

enum _UiSharedContainerRole { compact, expanded }

/// Identifies the thumbnail/preview region inside [UiOpenContainer]'s
/// `closedBuilder` and the matching region inside its `pageBuilder`.
///
/// Wrap the same visual (for example the cover image) with this widget in
/// both builders and the [UiContainerTransformStyle.iosZoom] flight will fly
/// that single element directly from its compact bounds to its expanded
/// bounds, instead of only cross-fading it with the rest of the content.
///
/// If only one side supplies a preview, the pairing is skipped for that
/// flight and the region falls back to the standard cross-fade. Outside a
/// container flight, or with [UiContainerTransformStyle.container], this
/// widget renders [child] unchanged.
class UiContainerPreview extends StatelessWidget {
  const UiContainerPreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = _UiContainerPreviewScope.maybeOf(context);
    if (scope == null) return child;

    return _UiContainerPreviewMarker(
      key: _UiContainerPreviewGlobalKey(scope.containerTag, scope.role),
      hidden: scope.hidden,
      child: child,
    );
  }
}

class _UiContainerPreviewMarker extends StatelessWidget {
  const _UiContainerPreviewMarker({
    required super.key,
    required this.hidden,
    required this.child,
  });

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Always the same widget shape regardless of [hidden] — only leaf
    // properties change — so toggling visibility never restructures (and
    // therefore never remounts) [child]'s subtree.
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: Opacity(opacity: hidden ? 0 : 1, child: child),
      ),
    );
  }
}

/// A [GlobalKey] with value equality on (containerTag, role), unlike
/// [GlobalObjectKey] which compares its wrapped value with `identical()`.
/// Freshly constructed instances built from the same pair must still resolve
/// to the same registered element across frames.
class _UiContainerPreviewGlobalKey extends GlobalKey<State<StatefulWidget>> {
  const _UiContainerPreviewGlobalKey(this.containerTag, this.role)
    : super.constructor();

  final Object containerTag;
  final _UiSharedContainerRole role;

  @override
  bool operator ==(Object other) {
    return other is _UiContainerPreviewGlobalKey &&
        other.containerTag == containerTag &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(containerTag, role);
}

class _UiContainerPreviewScope extends InheritedWidget {
  const _UiContainerPreviewScope({
    required this.containerTag,
    required this.role,
    required this.hidden,
    required super.child,
  });

  final Object containerTag;
  final _UiSharedContainerRole role;
  final bool hidden;

  static _UiContainerPreviewScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_UiContainerPreviewScope>();
  }

  @override
  bool updateShouldNotify(_UiContainerPreviewScope oldWidget) {
    return containerTag != oldWidget.containerTag ||
        role != oldWidget.role ||
        hidden != oldWidget.hidden;
  }
}

class _UiSharedContainerHero extends StatelessWidget {
  const _UiSharedContainerHero({
    required this.tag,
    required this.role,
    required this.naturalSize,
    required this.borderRadius,
    required this.backgroundColor,
    required this.curve,
    required this.contentOcclusion,
    required this.forwardDuration,
    required this.reverseDuration,
    required this.sourceFlightLayout,
    required this.pathMotion,
    required this.centerPullStrength,
    required this.child,
    this.fluidMotion,
    this.border,
    this.boxShadow,
  });

  final Object tag;
  final _UiSharedContainerRole role;
  final Size naturalSize;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Curve curve;
  final UiContentOcclusionSpec contentOcclusion;
  final Duration forwardDuration;
  final Duration reverseDuration;
  final UiContainerSourceFlightLayout sourceFlightLayout;
  final UiContainerPathMotion pathMotion;
  final double centerPullStrength;

  /// Non-null for [UiContainerTransformStyle.fluidZoom].
  final UiFluidRouteMotion? fluidMotion;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fluidMotion = this.fluidMotion;
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      curve: Curves.linear,
      reverseCurve: Curves.linear,
      createRectTween: (begin, end) => fluidMotion != null
          ? _UiFluidContainerRectTween(
              begin: begin,
              end: end,
              motion: fluidMotion,
            )
          : _UiSharedContainerRectTween(
              begin: begin,
              end: end,
              curve: curve,
              pathMotion: pathMotion,
              centerPullStrength: centerPullStrength,
            ),
      flightShuttleBuilder: _buildFlight,
      child: _UiSharedContainerSurface(
        role: role,
        containerTag: tag,
        naturalSize: naturalSize,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        border: border,
        boxShadow: boxShadow,
        continuousCorners: fluidMotion != null,
        child: child,
      ),
    );
  }

  Widget _buildFlight(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final fromHero = fromHeroContext.widget as Hero;
    final toHero = toHeroContext.widget as Hero;
    final from = fromHero.child as _UiSharedContainerSurface;
    final to = toHero.child as _UiSharedContainerSurface;
    final compact = from.role == _UiSharedContainerRole.compact ? from : to;
    final expanded = from.role == _UiSharedContainerRole.expanded ? from : to;

    final fluidMotion = this.fluidMotion;
    if (fluidMotion != null) {
      return _UiFluidContainerFlight(
        animation: animation,
        compact: compact,
        expanded: expanded,
        direction: direction,
        motion: fluidMotion,
        sourceFlightLayout: sourceFlightLayout,
      );
    }
    return _UiSharedContainerFlight(
      animation: animation,
      compact: compact,
      expanded: expanded,
      curve: curve,
      contentOcclusion: contentOcclusion,
      forwardDuration: forwardDuration,
      reverseDuration: reverseDuration,
      direction: direction,
      sourceFlightLayout: sourceFlightLayout,
      pathMotion: pathMotion,
      centerPullStrength: centerPullStrength,
    );
  }
}

class _UiSharedContainerSurface extends StatelessWidget {
  const _UiSharedContainerSurface({
    required this.role,
    required this.containerTag,
    required this.naturalSize,
    required this.borderRadius,
    required this.backgroundColor,
    required this.child,
    this.border,
    this.boxShadow,
    this.continuousCorners = false,
  });

  final _UiSharedContainerRole role;
  final Object containerTag;
  final Size naturalSize;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  /// Fluid zoom paints and clips with the token corner style so the resting
  /// surface matches its in-flight [UiCornerClip] outline.
  final bool continuousCorners;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = UiContainerFlightScope(
      progress: role == _UiSharedContainerRole.compact ? 0 : 1,
      size: naturalSize,
      borderRadius: borderRadius,
      inFlight: false,
      direction: null,
      child: child,
    );
    if (continuousCorners) {
      return DecoratedBox(
        decoration: UiThemeTokens.radiusOf(context).decoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          border: border,
          boxShadow: boxShadow,
        ),
        child: UiCornerClip(borderRadius: borderRadius, child: scope),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: scope,
      ),
    );
  }
}

/// Last-known preview rects/widgets for one flight, so the preview keeps
/// flying using stale-but-valid data once the compact side's live content
/// leaves the tree (see [_UiSharedContainerFlight._buildPreviewFlight]).
class _UiContainerPreviewFlightCache {
  Rect? compactRect;
  Rect? expandedRect;
  Widget? compactWidget;
  Widget? expandedWidget;
}

class _UiSharedContainerFlight extends StatelessWidget {
  const _UiSharedContainerFlight({
    required this.animation,
    required this.compact,
    required this.expanded,
    required this.curve,
    required this.contentOcclusion,
    required this.forwardDuration,
    required this.reverseDuration,
    required this.direction,
    required this.sourceFlightLayout,
    required this.pathMotion,
    required this.centerPullStrength,
  });

  final Animation<double> animation;
  final _UiSharedContainerSurface compact;
  final _UiSharedContainerSurface expanded;
  final Curve curve;
  final UiContentOcclusionSpec contentOcclusion;
  final Duration forwardDuration;
  final Duration reverseDuration;
  final HeroFlightDirection direction;
  final UiContainerSourceFlightLayout sourceFlightLayout;
  final UiContainerPathMotion pathMotion;
  final double centerPullStrength;

  @override
  Widget build(BuildContext context) {
    final boundaryKey = GlobalKey();
    // Sticky: once both sides of a paired UiContainerPreview are seen, the
    // preview keeps flying via the cache below even after the compact side
    // is later dropped from the tree at the content-occlusion switch point
    // (see the `!showExpanded` guard around compactContent). Without this,
    // hasPreviewPairLive would go false right at the switch, the overlay
    // would disappear, and the image would jump to its resting layout
    // position instead of continuing to fly to the destination rect.
    var previewFlightActivated = false;
    final previewCache = _UiContainerPreviewFlightCache();
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value.clamp(0.0, 1.0);
        final morphProgress = curve.transform(progress);
        final contentSwitch = _contentSwitchState(
          progress,
          contentOcclusion.curve,
          switchTime: contentOcclusion.switchTime,
          transitionDuration: contentOcclusion.duration,
          totalDuration: direction == HeroFlightDirection.push
              ? forwardDuration
              : reverseDuration,
        );
        final showExpanded = contentSwitch.showExpanded;
        final contentCoverColor =
            contentOcclusion.color ??
            (direction == HeroFlightDirection.push
                ? expanded.backgroundColor
                : compact.backgroundColor);
        final radius = BorderRadius.lerp(
          compact.borderRadius,
          expanded.borderRadius,
          morphProgress,
        )!;
        final backgroundColor = Color.lerp(
          compact.backgroundColor,
          expanded.backgroundColor,
          morphProgress,
        )!;
        final border = Border.lerp(
          compact.border,
          expanded.border,
          morphProgress,
        );
        final shadowProgress = math.sin(morphProgress * math.pi);
        final shadows = BoxShadow.lerpList(
          compact.boxShadow,
          expanded.boxShadow,
          morphProgress,
        );

        final containerTag = compact.containerTag;
        final previewCompactKey = _UiContainerPreviewGlobalKey(
          containerTag,
          _UiSharedContainerRole.compact,
        );
        final previewExpandedKey = _UiContainerPreviewGlobalKey(
          containerTag,
          _UiSharedContainerRole.expanded,
        );
        final hasPreviewPairLive =
            previewCompactKey.currentWidget is _UiContainerPreviewMarker &&
            previewExpandedKey.currentWidget is _UiContainerPreviewMarker;
        if (hasPreviewPairLive) previewFlightActivated = true;

        return LayoutBuilder(
          builder: (context, constraints) {
            final currentSize = constraints.biggest;
            final compactContent = RepaintBoundary(
              child: _UiContainerPreviewScope(
                containerTag: containerTag,
                role: _UiSharedContainerRole.compact,
                hidden: previewFlightActivated,
                child:
                    sourceFlightLayout ==
                        UiContainerSourceFlightLayout.responsive
                    ? SizedBox.expand(
                        key: const Key('ui_ios_zoom_source_content'),
                        child: compact.child,
                      )
                    : _UiNaturalSizeLayer(
                        size: compact.naturalSize,
                        contentKey: const Key('ui_ios_zoom_source_content'),
                        child: compact.child,
                      ),
              ),
            );

            return KeyedSubtree(
              key: boundaryKey,
              child: DecoratedBox(
                key: const Key('ui_ios_zoom_shadow'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    ...?shadows,
                    BoxShadow(
                      color: const Color(0x26000000)
                          .withValues(alpha: 0.15 * shadowProgress),
                      blurRadius: 28 * shadowProgress,
                      offset: Offset(0, 10 * shadowProgress),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  key: const Key('ui_ios_zoom_plate'),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: radius,
                    border: border,
                  ),
                  child: ClipRRect(
                    key: const Key('ui_container_transform_surface'),
                    borderRadius: radius,
                    clipBehavior: Clip.antiAlias,
                    child: UiContainerFlightScope(
                      progress: morphProgress,
                      size: currentSize,
                      borderRadius: radius,
                      inFlight: true,
                      direction: direction == HeroFlightDirection.push
                          ? UiContainerFlightDirection.opening
                          : UiContainerFlightDirection.closing,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            child: ExcludeSemantics(
                              excluding: !showExpanded,
                              child: Opacity(
                                key: const Key(
                                  'ui_ios_zoom_destination_opacity',
                                ),
                                opacity: showExpanded ? 1 : 0,
                                child: RepaintBoundary(
                                  child: _UiContainerPreviewScope(
                                    containerTag: containerTag,
                                    role: _UiSharedContainerRole.expanded,
                                    hidden: previewFlightActivated,
                                    child: _UiNaturalSizeLayer(
                                      size: expanded.naturalSize,
                                      contentKey: const Key(
                                        'ui_ios_zoom_destination_content',
                                      ),
                                      child: expanded.child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!showExpanded)
                            IgnorePointer(
                              child: ExcludeSemantics(
                                child: Opacity(
                                  key: const Key('ui_ios_zoom_source_opacity'),
                                  opacity: 1,
                                  child: compactContent,
                                ),
                              ),
                            ),
                          if (previewFlightActivated)
                            _buildPreviewFlight(
                              cache: previewCache,
                              boundaryKey: boundaryKey,
                              containerTag: containerTag,
                              morphProgress: morphProgress,
                              showExpanded: showExpanded,
                            ),
                          if (contentSwitch.coverOpacity > 0 &&
                              contentOcclusion.peakOpacity > 0)
                            IgnorePointer(
                              child: ExcludeSemantics(
                                child: Opacity(
                                  key: const Key('ui_ios_zoom_content_cover'),
                                  opacity:
                                      contentSwitch.coverOpacity *
                                      contentOcclusion.peakOpacity,
                                  child: ColoredBox(color: contentCoverColor),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Flies the paired [UiContainerPreview] region from its compact rect to
  /// its expanded rect, measured relative to [boundaryKey]. Both natural-size
  /// content layers are always present in the tree at this point (only their
  /// opacity differs), so their descendants' render boxes reflect this
  /// frame's real layout one tick after they first mount.
  ///
  /// Measurements are cached in [cache] and refreshed whenever a live read
  /// succeeds. The compact side stops being live once its content leaves the
  /// tree at the content-occlusion switch point (see the `!showExpanded`
  /// guard in [build]); from then on this keeps flying using the last known
  /// compact rect/widget instead of losing its start point and disappearing.
  Widget _buildPreviewFlight({
    required _UiContainerPreviewFlightCache cache,
    required GlobalKey boundaryKey,
    required Object containerTag,
    required double morphProgress,
    required bool showExpanded,
  }) {
    final boundaryObject = boundaryKey.currentContext?.findRenderObject();
    if (boundaryObject is RenderBox && boundaryObject.hasSize) {
      final compactKey = _UiContainerPreviewGlobalKey(
        containerTag,
        _UiSharedContainerRole.compact,
      );
      final expandedKey = _UiContainerPreviewGlobalKey(
        containerTag,
        _UiSharedContainerRole.expanded,
      );

      cache.compactRect =
          _localPreviewRect(compactKey, boundaryObject) ?? cache.compactRect;
      cache.expandedRect =
          _localPreviewRect(expandedKey, boundaryObject) ?? cache.expandedRect;
      cache.compactWidget =
          (compactKey.currentWidget as _UiContainerPreviewMarker?)?.child ??
          cache.compactWidget;
      cache.expandedWidget =
          (expandedKey.currentWidget as _UiContainerPreviewMarker?)?.child ??
          cache.expandedWidget;
    }

    final compactRect = cache.compactRect;
    final expandedRect = cache.expandedRect;
    final compactWidget = cache.compactWidget;
    final expandedWidget = cache.expandedWidget;
    if (compactRect == null ||
        expandedRect == null ||
        compactWidget == null ||
        expandedWidget == null) {
      return const SizedBox.shrink();
    }

    final positionProgress = switch (pathMotion) {
      UiContainerPathMotion.direct => morphProgress,
      UiContainerPathMotion.centerPull =>
        UiContainerTransformGeometry.centerPullProgress(
          morphProgress,
          strength: centerPullStrength,
        ),
    };
    final size = Size.lerp(compactRect.size, expandedRect.size, morphProgress)!;
    final center = Offset.lerp(
      compactRect.center,
      expandedRect.center,
      positionProgress,
    )!;
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );

    return Positioned.fromRect(
      key: const Key('ui_container_preview_flight'),
      rect: rect,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: showExpanded ? expandedWidget : compactWidget,
        ),
      ),
    );
  }

  static Rect? _localPreviewRect(GlobalKey key, RenderBox boundary) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final origin = renderObject.localToGlobal(Offset.zero, ancestor: boundary);
    return origin & renderObject.size;
  }
}

class _UiNaturalSizeLayer extends StatelessWidget {
  const _UiNaturalSizeLayer({
    required this.size,
    required this.child,
    this.contentKey,
  });

  final Size size;
  final Widget child;
  final Key? contentKey;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: SizedBox.fromSize(key: contentKey, size: size, child: child),
    );
  }
}

class _UiSharedContainerRectTween extends RectTween {
  _UiSharedContainerRectTween({
    required super.begin,
    required super.end,
    required this.curve,
    required this.pathMotion,
    required this.centerPullStrength,
  });

  final Curve curve;
  final UiContainerPathMotion pathMotion;
  final double centerPullStrength;

  @override
  Rect lerp(double t) {
    final geometryProgress = curve.transform(t);
    final positionProgress = switch (pathMotion) {
      UiContainerPathMotion.direct => geometryProgress,
      UiContainerPathMotion.centerPull =>
        UiContainerTransformGeometry.centerPullProgress(
          geometryProgress,
          strength: centerPullStrength,
        ),
    };
    final size = Size.lerp(begin!.size, end!.size, geometryProgress)!;
    final center = Offset.lerp(begin!.center, end!.center, positionProgress)!;
    return Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
  }
}

/// Experimental: Hero rect tween for [UiContainerTransformStyle.fluidZoom].
///
/// Hero evaluates its rect tween from `begin` to `end` along the flight, so
/// on pop `begin` is the expanded page rect. The compact rect is always the
/// smaller one; direction is inferred from that and closing samples the
/// monotonic path so the page never overshoots its source or the viewport.
class _UiFluidContainerRectTween extends RectTween {
  _UiFluidContainerRectTween({
    required super.begin,
    required super.end,
    required this.motion,
  });

  final UiFluidRouteMotion motion;

  @override
  Rect lerp(double t) {
    final a = begin!;
    final b = end!;
    final popping = a.width * a.height > b.width * b.height;
    final source = popping ? b : a;
    final destination = popping ? a : b;
    // Corners never influence the sampled rect; the shuttle owns them.
    return motion
        .sample(
          source: UiFluidGeometry(source, 0),
          destination: UiFluidGeometry(destination, 0),
          progress: popping ? 1 - t : t,
          monotonic: popping,
          bounds: a.expandToInclude(b),
        )
        .geometry
        .rect;
  }
}

/// Experimental shuttle for [UiContainerTransformStyle.fluidZoom]. Corners
/// and the content cross-fade come from the same sampled frame that drives
/// the Hero rect, so outline and content never drift apart.
class _UiFluidContainerFlight extends StatelessWidget {
  const _UiFluidContainerFlight({
    required this.animation,
    required this.compact,
    required this.expanded,
    required this.direction,
    required this.motion,
    required this.sourceFlightLayout,
  });

  final Animation<double> animation;
  final _UiSharedContainerSurface compact;
  final _UiSharedContainerSurface expanded;
  final HeroFlightDirection direction;
  final UiFluidRouteMotion motion;
  final UiContainerSourceFlightLayout sourceFlightLayout;

  @override
  Widget build(BuildContext context) {
    final source = UiFluidGeometry(
      Offset.zero & compact.naturalSize,
      0,
      corners: compact.borderRadius,
    );
    final destination = UiFluidGeometry(
      Offset.zero & expanded.naturalSize,
      0,
      corners: expanded.borderRadius,
    );
    final radiusTokens = UiThemeTokens.radiusOf(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        // The shuttle animation is route-driven: 1 is fully open in both
        // directions, unlike the rect tween's flight-relative clock.
        final progress = animation.value.clamp(0.0, 1.0);
        final frame = motion.sample(
          source: source,
          destination: destination,
          progress: progress,
          monotonic: direction == HeroFlightDirection.pop,
        );
        final radius = frame.geometry.borderRadius;
        final lift = math.sin(progress * math.pi);
        return LayoutBuilder(
          builder: (context, constraints) => DecoratedBox(
            key: const Key('ui_fluid_zoom_plate'),
            decoration: radiusTokens.decoration(
              color: Color.lerp(
                compact.backgroundColor,
                expanded.backgroundColor,
                progress,
              ),
              borderRadius: radius,
              border: Border.lerp(compact.border, expanded.border, progress),
              boxShadow: [
                ...?BoxShadow.lerpList(
                  compact.boxShadow,
                  expanded.boxShadow,
                  progress,
                ),
                BoxShadow(
                  color: const Color(0x26000000).withValues(alpha: 0.15 * lift),
                  blurRadius: 28 * lift,
                  offset: Offset(0, 10 * lift),
                ),
              ],
            ),
            child: UiCornerClip(
              borderRadius: radius,
              child: UiContainerFlightScope(
                progress: progress,
                size: constraints.biggest,
                borderRadius: radius,
                inFlight: true,
                direction: direction == HeroFlightDirection.push
                    ? UiContainerFlightDirection.opening
                    : UiContainerFlightDirection.closing,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (frame.destinationOpacity > 0)
                      _fluidLayer(
                        const Key('ui_fluid_zoom_destination_opacity'),
                        frame.destinationOpacity,
                        _UiNaturalSizeLayer(
                          size: expanded.naturalSize,
                          child: expanded.child,
                        ),
                      ),
                    if (frame.sourceOpacity > 0)
                      _fluidLayer(
                        const Key('ui_fluid_zoom_source_opacity'),
                        frame.sourceOpacity,
                        sourceFlightLayout ==
                                UiContainerSourceFlightLayout.responsive
                            ? SizedBox.expand(child: compact.child)
                            : _UiNaturalSizeLayer(
                                size: compact.naturalSize,
                                child: compact.child,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _fluidLayer(Key key, double opacity, Widget child) =>
      IgnorePointer(
        key: key,
        child: ExcludeSemantics(
          child: Opacity(
            opacity: opacity,
            child: RepaintBoundary(child: child),
          ),
        ),
      );
}

@immutable
class _ResolvedContainerBackdrop {
  const _ResolvedContainerBackdrop({
    required this.blurSigma,
    required this.tintColor,
    required this.tintOpacity,
    required this.curve,
  });

  const _ResolvedContainerBackdrop.none()
    : blurSigma = 0,
      tintColor = const Color(0x00000000),
      tintOpacity = 0,
      curve = Curves.linear;

  final double blurSigma;
  final Color tintColor;
  final double tintOpacity;
  final Curve curve;

  bool get isNone => blurSigma <= 0 && tintOpacity <= 0;
}

class _UiSharedContainerRoute<T> extends PageRoute<T> {
  _UiSharedContainerRoute({
    required this.tag,
    required this.motion,
    required this.destinationBorderRadius,
    required this.destinationSurfaceColor,
    required this.backdrop,
    required this.contentOcclusion,
    required this.sourceFlightLayout,
    required this.pathMotion,
    required this.centerPullStrength,
    required this.pageBuilder,
    this.fluidMotion,
    super.settings,
  });

  final Object tag;
  final UiMotionSpec motion;
  final BorderRadius destinationBorderRadius;
  final Color destinationSurfaceColor;
  final _ResolvedContainerBackdrop backdrop;
  final UiContentOcclusionSpec contentOcclusion;
  final UiContainerSourceFlightLayout sourceFlightLayout;
  final UiContainerPathMotion pathMotion;
  final double centerPullStrength;
  final UiContainerPageBuilder pageBuilder;
  final UiFluidRouteMotion? fluidMotion;

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
  Duration get transitionDuration => motion.duration;

  @override
  Duration get reverseTransitionDuration => motion.reverseDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.sizeOf(context);
    return _UiSharedContainerHero(
      tag: tag,
      role: _UiSharedContainerRole.expanded,
      naturalSize: size,
      borderRadius: destinationBorderRadius,
      backgroundColor: destinationSurfaceColor,
      curve: motion.curve,
      contentOcclusion: contentOcclusion,
      forwardDuration: motion.duration,
      reverseDuration: motion.reverseDuration,
      sourceFlightLayout: sourceFlightLayout,
      pathMotion: pathMotion,
      centerPullStrength: centerPullStrength,
      fluidMotion: fluidMotion,
      child: pageBuilder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (backdrop.isNone) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final effectProgress = _directionalCurveProgress(
          animation.value,
          backdrop.curve,
          reversing: animation.status == AnimationStatus.reverse,
        );
        final visibility = math
            .pow(math.sin(math.pi * effectProgress).clamp(0.0, 1.0), 0.55)
            .toDouble();
        if (visibility <= 0.001) return child!;

        final tintOpacity = backdrop.tintOpacity * visibility;
        final blurSigma = backdrop.blurSigma * visibility;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (blurSigma > 0.001)
              BackdropFilter(
                key: const Key('ui_container_backdrop_blur'),
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: const SizedBox.expand(),
              ),
            if (tintOpacity > 0.001)
              ColoredBox(
                key: const Key('ui_container_backdrop_tint'),
                color: backdrop.tintColor.withValues(alpha: tintOpacity),
              ),
            child!,
          ],
        );
      },
    );
  }
}

/// A reversible route whose surface expands from [sourceRect].
///
/// This route is public so applications can use the primitive without
/// [UiOpenContainer] when source geometry comes from another measurement
/// system.
class UiContainerTransformRoute<T> extends PageRoute<T> {
  UiContainerTransformRoute({
    required this.sourceRect,
    required this.pageBuilder,
    required this.motion,
    required this.surfaceColor,
    required this.scrimColor,
    required this.sourceSize,
    this.sourceChild,
    this.sourceBorderRadius = BorderRadius.zero,
    this.destinationBorderRadius = BorderRadius.zero,
    super.settings,
  });

  final Rect sourceRect;
  final UiContainerPageBuilder pageBuilder;
  final UiMotionSpec motion;
  final Color surfaceColor;
  final Color scrimColor;
  final Size sourceSize;
  final Widget? sourceChild;
  final BorderRadius sourceBorderRadius;
  final BorderRadius destinationBorderRadius;

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
  Duration get transitionDuration => motion.duration;

  @override
  Duration get reverseTransitionDuration => motion.reverseDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return pageBuilder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: motion.curve,
      reverseCurve: motion.reverseCurve,
    );
    return UiContainerTransformTransition(
      animation: curved,
      phaseAnimation: animation,
      sourceRect: sourceRect,
      sourceBorderRadius: sourceBorderRadius,
      destinationBorderRadius: destinationBorderRadius,
      surfaceColor: surfaceColor,
      scrimColor: scrimColor,
      sourceSize: sourceSize,
      sourceChild: sourceChild,
      child: child,
    );
  }
}

/// Geometry and reveal primitive used by [UiContainerTransformRoute].
///
/// The destination remains laid out at its final size. Only paint-time clip,
/// surface geometry, and opacity change during the transition.
class UiContainerTransformTransition extends StatelessWidget {
  const UiContainerTransformTransition({
    super.key,
    required this.animation,
    required this.sourceRect,
    required this.surfaceColor,
    required this.scrimColor,
    required this.sourceSize,
    required this.child,
    this.phaseAnimation,
    this.sourceChild,
    this.sourceBorderRadius = BorderRadius.zero,
    this.destinationBorderRadius = BorderRadius.zero,
    this.contentRevealStart = 0.20,
    this.contentRevealEnd = 0.42,
  }) : assert(contentRevealStart >= 0 && contentRevealStart <= 1),
       assert(contentRevealEnd >= contentRevealStart && contentRevealEnd <= 1);

  final Animation<double> animation;
  final Animation<double>? phaseAnimation;
  final Rect sourceRect;
  final BorderRadius sourceBorderRadius;
  final BorderRadius destinationBorderRadius;
  final Color surfaceColor;
  final Color scrimColor;
  final Size sourceSize;
  final Widget child;
  final Widget? sourceChild;
  final double contentRevealStart;
  final double contentRevealEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final destinationRect = Offset.zero & constraints.biggest;
        final timeline = phaseAnimation == null
            ? animation
            : Listenable.merge([animation, phaseAnimation!]);
        return AnimatedBuilder(
          animation: timeline,
          child: RepaintBoundary(child: child),
          builder: (context, child) {
            final geometryProgress = animation.value.clamp(0.0, 1.0);
            final phaseProgress = (phaseAnimation?.value ?? geometryProgress)
                .clamp(0.0, 1.0);
            final rect = Rect.lerp(
              sourceRect,
              destinationRect,
              geometryProgress,
            )!;
            final elevationProgress = math.sin(phaseProgress * math.pi);

            final radius = BorderRadius.lerp(
              sourceBorderRadius,
              destinationBorderRadius,
              geometryProgress,
            )!;
            final reveal = _interval(
              phaseProgress,
              contentRevealStart,
              contentRevealEnd,
            );
            const sourceOpacity = 1.0;
            final scrimProgress = _interval(phaseProgress, 0, 0.20);

            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Color.lerp(
                    const Color(0x00000000),
                    scrimColor,
                    scrimProgress,
                  )!,
                ),
                Positioned.fromRect(
                  key: const Key('ui_container_transform_surface'),
                  rect: rect,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x33000000)
                              .withValues(alpha: 0.2 * elevationProgress),
                          blurRadius: 28 * elevationProgress,
                          offset: Offset(0, 10 * elevationProgress),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (sourceChild != null && sourceOpacity > 0)
                            ExcludeSemantics(
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: sourceOpacity,
                                  child: FittedBox(
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.topLeft,
                                    child: SizedBox.fromSize(
                                      size: sourceSize,
                                      child: sourceChild,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ExcludeSemantics(
                            excluding: reveal < 0.5,
                            child: IgnorePointer(
                              ignoring: phaseProgress < 0.999,
                              child: Opacity(
                                opacity: reveal,
                                child: FittedBox(
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topLeft,
                                  child: SizedBox.fromSize(
                                    size: destinationRect.size,
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static double _interval(double value, double start, double end) {
    if (end == start) return value >= end ? 1 : 0;
    return ((value - start) / (end - start)).clamp(0.0, 1.0);
  }
}
