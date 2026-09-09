import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/primitives/ui_corner_clip.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'fluid_bridge_path.dart';

/// Paints a fluid surface while keeping its content at a stable layout size.
/// Use inside a Stack with finite bounds and room for the authored overshoot.
class UiFluidSurface extends StatelessWidget {
  const UiFluidSurface({
    super.key,
    required this.geometry,
    required this.contentSize,
    required this.child,
    required this.color,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
    this.opacity = 1,
    this.interactive = true,
    this.hitTestRect,
    this.shadows = const [],
    this.backdropBlurSigma = 0,
    this.foregroundColor = const Color(0x00000000),
    this.border = BorderSide.none,
    this.clipBehavior = Clip.antiAlias,
  });

  final UiFluidGeometry geometry;
  final Size contentSize;
  final Widget child;
  final Color color;
  final Alignment alignment;

  /// Use [BoxFit.none] for stable-size content revealed only by the outline clip.
  final BoxFit fit;
  final double opacity;
  final bool interactive;

  /// Optional stable interaction bounds while the painted surface moves.
  /// Intended for fitted menu content whose final layout is already known.
  final Rect? hitTestRect;
  final List<BoxShadow> shadows;

  /// Background blur clipped to the animated outline; zero disables it.
  final double backdropBlurSigma;

  /// Non-interactive tint painted over this surface and its content.
  final Color foregroundColor;

  /// Outline painted inside the moving rounded boundary.
  final BorderSide border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final blur = UiThemeTokens.effectsOf(context).scaleBlur(backdropBlurSigma);
    final radius = UiThemeTokens.radiusOf(context);
    final surface = Positioned.fromRect(
      rect: geometry.rect,
      child: IgnorePointer(
        ignoring: !interactive,
        child: DecoratedBox(
          decoration: radius.decoration(
            borderRadius: geometry.borderRadius,
            boxShadow: shadows,
          ),
          // Paint the stroke once, outside the antialiased content clip.
          // Clipping an already antialiased stroke multiplies edge coverage
          // and causes a changing halo as fractional animated bounds move.
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: radius.decoration(
              borderRadius: geometry.borderRadius,
              border: Border.fromBorderSide(border),
            ),
            child: UiCornerClip(
              clipBehavior: clipBehavior,
              borderRadius: geometry.borderRadius,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: radius.decoration(
                  color: foregroundColor,
                  borderRadius: geometry.borderRadius,
                ),
                child: _fluidBackdrop(
                  blur: blur,
                  child: DecoratedBox(
                    decoration: radius.decoration(
                      color: color,
                      borderRadius: geometry.borderRadius,
                    ),
                    child: IgnorePointer(
                      ignoring: !interactive,
                      child: ExcludeFocus(
                        excluding: !interactive,
                        child: ExcludeSemantics(
                          excluding: !interactive,
                          child: Opacity(
                            opacity: opacity,
                            child: FittedBox(
                              fit: fit,
                              alignment: alignment,
                              child: SizedBox.fromSize(
                                size: contentSize,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (hitTestRect == null) return surface;
    final fitted = applyBoxFit(fit, contentSize, geometry.rect.size);
    final paintedContent = alignment.inscribe(
      fitted.destination,
      geometry.rect,
    );
    return Positioned.fill(
      child: _FluidSurfaceHitTarget(
        target: hitTestRect!,
        painted: paintedContent,
        child: Stack(clipBehavior: Clip.none, children: [surface]),
      ),
    );
  }
}

// Redirect only hit testing; retain the original clip, content tree and paint.
// The transform is recorded in the hit path so pointer moves/up use the same
// coordinates as pointer down, even if the spring advances between events.
class _FluidSurfaceHitTarget extends SingleChildRenderObjectWidget {
  const _FluidSurfaceHitTarget({
    required this.target,
    required this.painted,
    required super.child,
  });

  final Rect target;
  final Rect painted;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFluidSurfaceHitTarget(target, painted);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFluidSurfaceHitTarget renderObject,
  ) {
    renderObject
      ..target = target
      ..painted = painted;
  }
}

class _RenderFluidSurfaceHitTarget extends RenderProxyBox {
  _RenderFluidSurfaceHitTarget(this.target, this.painted);

  Rect target;
  Rect painted;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!target.contains(position) || target.isEmpty || painted.isEmpty) {
      return false;
    }
    final transform = Matrix4.identity()
      ..translateByDouble(painted.left, painted.top, 0, 1)
      ..scaleByDouble(
        painted.width / target.width,
        painted.height / target.height,
        1,
        1,
      )
      ..translateByDouble(-target.left, -target.top, 0, 1);
    return result.addWithRawTransform(
      transform: transform,
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }
}

// Zero-blur surfaces avoid allocating a filter and its disabled render object
// on every geometry tick. The nonzero treatment remains identical.
Widget _fluidBackdrop({required double blur, required Widget child}) => blur > 0
    ? BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      )
    : child;

/// Experimental V13 morph. Geometry is expressed in this widget's local
/// coordinate space. The parent owns available space and overlay lifecycle.
/// The source and destination stay mounted; visible content stays interactive during motion.
class UiFluidMorph extends StatefulWidget {
  const UiFluidMorph({
    super.key,
    required this.controller,
    required this.sourceGeometry,
    required this.destinationGeometry,
    required this.source,
    required this.destination,
    required this.color,
    this.sourceFit = BoxFit.contain,
    this.stableDestinationHitTargets = false,
    this.sourceColor,
    this.initialSourceGeometry,
    this.initialSourceColor,
    this.initialSourceBorder,
    this.sourceBorder,
    this.sourceShadows,
    this.sourceBackdropBlurSigma,
    this.contraction = .68,
    this.pressExpansion = 1,
    this.springStrength = 1,
    this.travelArc = 0,
    this.overlayBuilder,
    this.shadows = const [],
    this.backdropBlurSigma = 0,
    this.foregroundColor = const Color(0x00000000),
    this.border = BorderSide.none,
    this.alignment = Alignment.center,
  });

  final UiFluidController controller;
  final UiFluidGeometry sourceGeometry;
  final UiFluidGeometry destinationGeometry;
  final Widget source;
  final Widget destination;
  final Color color;

  /// Use final destination bounds for interaction while opening content appears.
  /// Paint continues to follow the morph, without mounting a second action tree.
  final bool stableDestinationHitTargets;

  /// Optional compact-endpoint styling. Null preserves the destination style.
  final BoxFit sourceFit;
  final Color? sourceColor;

  /// Current pressed appearance for the first frame; reversal returns to source.
  final UiFluidGeometry? initialSourceGeometry;
  final Color? initialSourceColor;
  final BorderSide? initialSourceBorder;
  final BorderSide? sourceBorder;
  final List<BoxShadow>? sourceShadows;
  final double? sourceBackdropBlurSigma;
  final double contraction;
  final double pressExpansion;
  final double springStrength;

  /// Maximum downward bow of the travel path. Zero retains straight travel.
  final double travelArc;

  /// Optional shared content painted above both transitioning content layers.
  final Widget Function(BuildContext context, UiFluidMorphFrame frame)?
  overlayBuilder;
  final List<BoxShadow> shadows;

  /// Background blur clipped to the animated outline; zero disables it.
  final double backdropBlurSigma;

  /// Non-interactive tint painted over this surface and its content.
  final Color foregroundColor;

  /// Outline painted inside the moving rounded boundary.
  final BorderSide border;
  final Alignment alignment;

  @override
  State<UiFluidMorph> createState() => _UiFluidMorphState();
}

class _UiFluidMorphState extends State<UiFluidMorph> {
  int _revision = -1;
  UiFluidMorphFrame? _last;
  UiFluidMorphFrame? _origin;
  double _appearance = 0, _appearanceOrigin = 0;
  Color? _lastColor, _colorOrigin;
  BorderSide? _lastBorder, _borderOrigin;

  @override
  void didUpdateWidget(UiFluidMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _revision = -1;
      _last = null;
      _origin = null;
      _appearance = _appearanceOrigin = 0;
      _lastColor = _colorOrigin = null;
      _lastBorder = _borderOrigin = null;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      var frame = UiFluidMorphFrame.sample(
        source: widget.sourceGeometry,
        destination: widget.destinationGeometry,
        progress: widget.controller.value,
        contraction: widget.contraction,
        pressExpansion: widget.pressExpansion,
        springStrength: widget.springStrength,
      );
      if (_revision != widget.controller.revision) {
        _appearanceOrigin = _appearance;
        _colorOrigin =
            _lastColor ??
            widget.initialSourceColor ??
            widget.sourceColor ??
            widget.color;
        _borderOrigin =
            _lastBorder ??
            widget.initialSourceBorder ??
            widget.sourceBorder ??
            widget.border;
        _origin =
            _last ??
            UiFluidMorphFrame(
              widget.initialSourceGeometry ?? widget.sourceGeometry,
              1,
              0,
            );
        _revision = widget.controller.revision;
      }
      if (widget.controller.retargeting && _origin != null) {
        final opening = widget.controller.target == 1;
        final progress = widget.controller.transitionProgress;
        final p = uiFluidSpring(progress, strength: widget.springStrength);
        // Hand content off in sequence; never leave expanded text behind
        // while the compact label is becoming readable.
        double fade(double start, double duration) => Curves.easeInOut
            .transform(((progress - start) / duration).clamp(0.0, 1.0));
        final sourceFade = opening ? fade(0, .15) : fade(.25, .25);
        final destinationFade = opening ? fade(.15, .30) : fade(0, .22);
        frame = UiFluidMorphFrame(
          UiFluidGeometry.lerp(
            _origin!.geometry,
            opening ? widget.destinationGeometry : widget.sourceGeometry,
            p,
            // Corners and stroke width share one monotonic clock. The rect
            // may spring past its destination, but its outline must not pulse.
            cornerProgress: Curves.easeOutCubic.transform(progress),
            bend: Offset(
              0,
              (widget.destinationGeometry.rect.center.dy <
                          widget.sourceGeometry.rect.center.dy
                      ? -1
                      : 1) *
                  widget.travelArc.clamp(
                    0.0,
                    ((widget.destinationGeometry.rect.shortestSide -
                                widget.sourceGeometry.rect.shortestSide) /
                            2)
                        .clamp(0.0, double.infinity),
                  ),
            ),
          ),
          _origin!.sourceOpacity +
              ((opening ? 0 : 1) - _origin!.sourceOpacity) * sourceFade,
          _origin!.destinationOpacity +
              ((opening ? 1 : 0) - _origin!.destinationOpacity) *
                  destinationFade,
        );
      }
      _last = frame;
      _appearance = widget.controller.retargeting
          ? _appearanceOrigin +
                (widget.controller.target - _appearanceOrigin) *
                    Curves.easeOutCubic.transform(
                      widget.controller.transitionProgress,
                    )
          : widget.controller.value;
      final sourceStyle =
          widget.sourceColor != null ||
          widget.sourceBorder != null ||
          widget.sourceBackdropBlurSigma != null ||
          widget.sourceShadows != null;
      final paintProgress = Curves.easeOutCubic.transform(
        widget.controller.transitionProgress,
      );
      _lastColor = widget.controller.retargeting
          ? Color.lerp(
              _colorOrigin,
              widget.controller.target == 1
                  ? widget.color
                  : (widget.sourceColor ?? widget.color),
              paintProgress,
            )
          : Color.lerp(
              widget.sourceColor ?? widget.color,
              widget.color,
              _appearance,
            );
      _lastBorder = widget.controller.retargeting
          ? BorderSide.lerp(
              _borderOrigin!,
              widget.controller.target == 1
                  ? widget.border
                  : (widget.sourceBorder ?? widget.border),
              paintProgress,
            )
          : BorderSide.lerp(
              widget.sourceBorder ?? widget.border,
              widget.border,
              _appearance,
            );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          UiFluidSurface(
            geometry: frame.geometry,
            contentSize: widget.sourceGeometry.rect.size,
            fit: widget.sourceFit,
            color: _lastColor!,
            border: sourceStyle ? _lastBorder! : BorderSide.none,
            shadows: BoxShadow.lerpList(
              widget.sourceShadows ?? widget.shadows,
              widget.shadows,
              _appearance,
            )!,
            backdropBlurSigma:
                (widget.sourceBackdropBlurSigma ?? widget.backdropBlurSigma) +
                (widget.backdropBlurSigma -
                        (widget.sourceBackdropBlurSigma ??
                            widget.backdropBlurSigma)) *
                    _appearance,
            opacity: frame.sourceOpacity,
            interactive:
                frame.sourceOpacity > 0 && frame.destinationOpacity < .5,
            alignment: widget.alignment,
            child: widget.source,
          ),
          UiFluidSurface(
            geometry: frame.geometry,
            contentSize: widget.destinationGeometry.rect.size,
            hitTestRect: widget.stableDestinationHitTargets
                ? widget.destinationGeometry.rect
                : null,
            color: const Color(0x00000000),
            foregroundColor: widget.foregroundColor,
            border: sourceStyle ? BorderSide.none : widget.border,
            opacity: frame.destinationOpacity,
            interactive: frame.destinationOpacity > 0,
            alignment: widget.alignment,
            child: widget.destination,
          ),
          if (widget.overlayBuilder != null)
            widget.overlayBuilder!(context, frame),
        ],
      );
    },
  );
}

/// A destination surface can contain several actions, independently of the
/// number of surfaces participating in the split.
@immutable
class UiFluidBranch {
  const UiFluidBranch({
    required this.geometry,
    required this.child,
    this.contentSize,
    this.shadows = const [],
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.antiAlias,
  });
  final UiFluidGeometry geometry;
  final Widget child;

  /// Stable content layout when a composition also changes branch geometry.
  final Size? contentSize;

  /// Elevation follows the released branch and fades back into its source.
  final List<BoxShadow> shadows;
  final BoxFit fit;
  final Alignment alignment;
  final Clip clipBehavior;
}

/// Experimental emergence composition: a retained source and one or more
/// surfaces move apart with a diminishing geometric neck. Reverse the same
/// controller to merge them. Uses no blur, refraction, or shader.
class UiFluidSplit extends StatefulWidget {
  const UiFluidSplit({
    super.key,
    required this.controller,
    required this.sourceGeometry,
    required this.source,
    required this.branches,
    required this.color,
    this.frame,
  });

  final UiFluidController controller;
  final UiFluidGeometry sourceGeometry;
  final Widget source;
  final List<UiFluidBranch> branches;
  final Color color;

  /// Optional shared sample when surrounding layout follows this split.
  final UiFluidSplitFrame? frame;

  @override
  State<UiFluidSplit> createState() => _UiFluidSplitState();
}

class _UiFluidSplitState extends State<UiFluidSplit> {
  final _motion = UiFluidSplitMotion();

  @override
  Widget build(BuildContext context) => widget.frame != null
      ? _buildSplit(context)
      : AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => _buildSplit(context),
        );

  Widget _buildSplit(BuildContext context) {
    final frame = widget.frame ?? _motion.sample(widget.controller);
    final q = frame.contentProgress;
    final p = frame.geometryProgress;
    final geometries = widget.branches
        .map(
          (branch) =>
              UiFluidGeometry.lerp(widget.sourceGeometry, branch.geometry, p),
        )
        .toList();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _NeckPainter(
                widget.sourceGeometry,
                geometries,
                widget.color,
                fluidBridgeStrength(q),
              ),
            ),
          ),
        ),
        for (var i = 0; i < widget.branches.length; i++)
          UiFluidSurface(
            geometry: geometries[i],
            clipBehavior: widget.branches[i].clipBehavior,
            contentSize:
                widget.branches[i].contentSize ??
                widget.branches[i].geometry.rect.size,
            fit: widget.branches[i].fit,
            alignment: widget.branches[i].alignment,
            shadows: BoxShadow.lerpList(
              const [],
              widget.branches[i].shadows,
              q.clamp(0.0, 1.0),
            )!,
            color: widget.color,
            opacity: ((q - .15) / .45).clamp(0.0, 1.0),
            interactive: q > .15,
            child: widget.branches[i].child,
          ),
        UiFluidSurface(
          geometry: widget.sourceGeometry,
          contentSize: widget.sourceGeometry.rect.size,
          color: widget.color,
          interactive: true,
          child: widget.source,
        ),
      ],
    );
  }
}

class _NeckPainter extends CustomPainter {
  const _NeckPainter(this.source, this.destinations, this.color, this.strength);
  final UiFluidGeometry source;
  final List<UiFluidGeometry> destinations;
  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final target in destinations) {
      canvas.drawPath(fluidBridgePath(source, target, strength), paint);
    }
  }

  @override
  bool shouldRepaint(_NeckPainter old) =>
      color != old.color ||
      strength != old.strength ||
      source.rect != old.source.rect ||
      source.borderRadius != old.source.borderRadius ||
      destinations.length != old.destinations.length ||
      Iterable<int>.generate(destinations.length).any(
        (i) =>
            destinations[i].rect != old.destinations[i].rect ||
            destinations[i].borderRadius != old.destinations[i].borderRadius,
      );
}

/// Accessible press/hold/release trigger. Place over the source surface, or
/// use as its content. The owning composition controls destination dismissal.
class UiFluidTrigger extends StatelessWidget {
  const UiFluidTrigger({
    super.key,
    required this.controller,
    required this.label,
    required this.child,
    this.enabled = true,
    this.directOpen = false,
  });
  final UiFluidController controller;
  final String label;
  final Widget child;
  final bool enabled;
  final bool directOpen;

  @override
  Widget build(BuildContext context) {
    void activate() => controller.open(context, direct: directOpen);
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      onTap: enabled ? activate : null,
      child: FocusableActionDetector(
        enabled: enabled,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled ? (_) => controller.press(context) : null,
          onTapUp: enabled ? (_) => activate() : null,
          onTapCancel: enabled ? () => controller.cancelPress(context) : null,
          child: child,
        ),
      ),
    );
  }
}
