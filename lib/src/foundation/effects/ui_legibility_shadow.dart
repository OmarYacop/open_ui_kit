import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// A compact, alpha-following shadow that keeps foreground UI legible.
///
/// This behaves like the tight shadow beneath iOS Home Screen labels: it
/// follows the painted shape of text, icons, and controls instead of their
/// rectangular layout bounds. Use it for floating chrome over scrolling
/// content; use [UiComponentShadow] for broad surface clearance.
class UiLegibilityShadow extends SingleChildRenderObjectWidget {
  const UiLegibilityShadow({
    super.key,
    required super.child,
    this.color,
    this.offset = const Offset(0, 1.25),
    this.blurSigma = 2,
    this.spreadRadius = 0.5,
  }) : assert(blurSigma >= 0),
       assert(spreadRadius >= 0);

  /// Defaults to the theme background at 92% opacity.
  final Color? color;
  final Offset offset;
  final double blurSigma;

  /// Expands the child's alpha silhouette before it is blurred.
  final double spreadRadius;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return RenderUiLegibilityShadow(
      color: color ?? tokens.colors.background.withValues(alpha: 0.92),
      offset: offset,
      blurSigma: blurSigma,
      spreadRadius: spreadRadius,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderUiLegibilityShadow renderObject,
  ) {
    final tokens = UiThemeTokens.of(context);
    renderObject
      ..color = color ?? tokens.colors.background.withValues(alpha: 0.92)
      ..offset = offset
      ..blurSigma = blurSigma
      ..spreadRadius = spreadRadius;
  }
}

class RenderUiLegibilityShadow extends RenderProxyBox {
  RenderUiLegibilityShadow({
    required Color color,
    required Offset offset,
    required double blurSigma,
    required double spreadRadius,
  }) : _color = color,
       _offset = offset,
       _blurSigma = blurSigma,
       _spreadRadius = spreadRadius;

  Color _color;
  Offset _offset;
  double _blurSigma;
  double _spreadRadius;

  @override
  bool get alwaysNeedsCompositing => child != null;

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set offset(Offset value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsPaint();
  }

  set blurSigma(double value) {
    if (_blurSigma == value) return;
    _blurSigma = value;
    markNeedsPaint();
  }

  set spreadRadius(double value) {
    if (_spreadRadius == value) return;
    _spreadRadius = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final inflation = _blurSigma * 3 + _spreadRadius;
    final shadowBounds = (offset & size).shift(_offset).inflate(inflation);

    // Keep the shadow entirely in retained Flutter layers. This avoids raw
    // saveLayer masks, whose temporary bounds can become visible on some GPU
    // backends. Spread is an image-filter dilation, so the shadow pass paints
    // the child only once; the interactive child is painted once afterward.
    final blur = ui.ImageFilter.blur(
      sigmaX: math.max(_blurSigma, 0.01),
      sigmaY: math.max(_blurSigma, 0.01),
      tileMode: TileMode.decal,
    );
    final shadowFilter = _spreadRadius > 0
        ? ui.ImageFilter.compose(
            outer: blur,
            inner: ui.ImageFilter.dilate(
              radiusX: _spreadRadius,
              radiusY: _spreadRadius,
            ),
          )
        : blur;
    final imageLayer = layer is ImageFilterLayer
        ? layer! as ImageFilterLayer
        : ImageFilterLayer();
    imageLayer.imageFilter = shadowFilter;
    layer = imageLayer;
    context.pushLayer(
      imageLayer,
      (blurContext, blurOffset) {
        blurContext.pushColorFilter(
          blurOffset,
          ColorFilter.mode(_color, BlendMode.srcIn),
          (shadowContext, shadowOffset) {
            shadowContext.paintChild(child, shadowOffset + _offset);
          },
        );
      },
      offset,
      childPaintBounds: shadowBounds,
    );
    context.paintChild(child, offset);
  }

  @override
  Rect get paintBounds {
    final inflation = _blurSigma * 3 + _spreadRadius;
    return super.paintBounds
        .shift(_offset)
        .inflate(inflation)
        .expandToInclude(super.paintBounds);
  }
}
