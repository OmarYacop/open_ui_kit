import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/effects/ui_shader_sampler.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

const _appleBlurSigma = 14.0;
const _appleFadeHold = 0.12;
// Keep the Apple material visibly translucent even when callers request a
// stronger edge fade. The progressive blur supplies the remaining separation.
const _appleMaxTintOpacity = 0.84;
const _progressiveBlurShader =
    'packages/open_ui_kit/lib/src/patterns/layout/shaders/'
    'ui_progressive_blur.frag';

/// Paints platform-adaptive fades over the vertical edges of [child].
///
/// This is the standard Open UI treatment for scrollable content moving below
/// floating chrome. Apple platforms use a light/dark adaptive material with a
/// continuous, shader-driven top-edge blur. The bottom edge mirrors the tint
/// transition without blur; other platforms use inexpensive surface gradients.
class UiScrollEdgeFade extends StatelessWidget {
  const UiScrollEdgeFade({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.extent = 48,
    this.topExtent,
    this.bottomExtent,
    this.horizontalInset = 0,
    this.maxOpacity = 0.84,
    this.showTop = true,
    this.showBottom = true,
    this.paintOverChild = true,
  }) : assert(extent >= 0),
       assert(maxOpacity >= 0 && maxOpacity <= 1);

  final Widget child;
  final Color backgroundColor;
  final double extent;
  final double? topExtent;
  final double? bottomExtent;
  final double horizontalInset;
  final double maxOpacity;
  final bool showTop;
  final bool showBottom;
  final bool paintOverChild;

  @override
  Widget build(BuildContext context) {
    final isApplePlatform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final brightness = UiThemeTokens.brightnessOf(context);
    final appleFadeColor = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final appleEdgeOpacity = maxOpacity > _appleMaxTintOpacity
        ? _appleMaxTintOpacity
        : maxOpacity;
    final topEdgeColor = isApplePlatform
        ? appleFadeColor.withValues(alpha: appleEdgeOpacity)
        : backgroundColor.withValues(alpha: maxOpacity);
    final transparentTopEdgeColor = isApplePlatform
        ? appleFadeColor.withValues(alpha: 0)
        : backgroundColor.withValues(alpha: 0);
    final bottomEdgeColor = topEdgeColor;
    final transparentBottomEdgeColor = transparentTopEdgeColor;
    final topBlurSigma = isApplePlatform
        ? UiThemeTokens.effectsOf(context).scaleBlur(_appleBlurSigma)
        : 0.0;
    final effectiveTopExtent = topExtent ?? extent;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final view = View.of(context);
    final leftSafeBleed = view.padding.left / view.devicePixelRatio;
    final rightSafeBleed = view.padding.right / view.devicePixelRatio;
    final startBleed = direction == TextDirection.ltr
        ? leftSafeBleed
        : rightSafeBleed;
    final endBleed = direction == TextDirection.ltr
        ? rightSafeBleed
        : leftSafeBleed;

    final fades = <Widget>[
      if (showTop)
        PositionedDirectional(
          start: horizontalInset - startBleed,
          end: horizontalInset - endBleed,
          top: 0,
          height: effectiveTopExtent,
          child: IgnorePointer(
            child: _EdgeFadeMaterial(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              edgeColor: topEdgeColor,
              transparentEdgeColor: transparentTopEdgeColor,
              holdsEdgeColor: isApplePlatform,
            ),
          ),
        ),
      if (showBottom)
        PositionedDirectional(
          start: horizontalInset - startBleed,
          end: horizontalInset - endBleed,
          bottom: 0,
          height: bottomExtent ?? extent,
          child: IgnorePointer(
            child: _EdgeFadeMaterial(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              edgeColor: bottomEdgeColor,
              transparentEdgeColor: transparentBottomEdgeColor,
              holdsEdgeColor: isApplePlatform,
            ),
          ),
        ),
    ];

    final shouldBlurTop =
        showTop && paintOverChild && topBlurSigma > 0 && effectiveTopExtent > 0;
    final renderedChild = shouldBlurTop
        ? _ContinuousProgressiveBlur(
            sigma: topBlurSigma,
            extent: effectiveTopExtent,
            child: child,
          )
        : child;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (!paintOverChild) ...fades,
        renderedChild,
        if (paintOverChild) ...fades,
      ],
    );
  }
}

class _EdgeFadeMaterial extends StatelessWidget {
  const _EdgeFadeMaterial({
    required this.begin,
    required this.end,
    required this.edgeColor,
    required this.transparentEdgeColor,
    this.holdsEdgeColor = false,
  });

  final Alignment begin;
  final Alignment end;
  final Color edgeColor;
  final Color transparentEdgeColor;
  final bool holdsEdgeColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: holdsEdgeColor
              ? [edgeColor, edgeColor, transparentEdgeColor]
              : [edgeColor, transparentEdgeColor],
          stops: holdsEdgeColor ? const [0, _appleFadeHold, 1] : null,
        ),
      ),
    );
  }
}

class _ContinuousProgressiveBlur extends StatelessWidget {
  const _ContinuousProgressiveBlur({
    required this.sigma,
    required this.extent,
    required this.child,
  });

  final double sigma;
  final double extent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: UiShaderBuilder(
        assetKey: _progressiveBlurShader,
        child: child,
        builder: (context, shader, sampledChild) => UiShaderSampler(
          key: const Key('ui_scroll_edge_progressive_blur'),
          painter: (image, size, canvas) {
            final pixelSize = size * pixelRatio;
            final firstPassRecorder = ui.PictureRecorder();
            final firstPassCanvas = ui.Canvas(firstPassRecorder);

            _configureShader(
              shader,
              image: image,
              size: pixelSize,
              direction: 0,
              pixelRatio: pixelRatio,
            );
            final paint = ui.Paint()..shader = shader;
            firstPassCanvas.drawRect(ui.Offset.zero & pixelSize, paint);

            final firstPassPicture = firstPassRecorder.endRecording();
            final firstPassImage = firstPassPicture.toImageSync(
              pixelSize.width.ceil(),
              pixelSize.height.ceil(),
            );
            try {
              _configureShader(
                shader,
                image: firstPassImage,
                size: pixelSize,
                direction: 1,
                pixelRatio: pixelRatio,
              );
              canvas.scale(1 / pixelRatio);
              canvas.drawRect(ui.Offset.zero & pixelSize, paint);
            } finally {
              firstPassImage.dispose();
              firstPassPicture.dispose();
            }
          },
          child: sampledChild,
        ),
      ),
    );
  }

  void _configureShader(
    ui.FragmentShader shader, {
    required ui.Image image,
    required ui.Size size,
    required double direction,
    required double pixelRatio,
  }) {
    shader.setImageSampler(0, image);
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, sigma);
    shader.setFloat(3, direction);
    shader.setFloat(4, extent * pixelRatio);
    shader.setFloat(5, _appleFadeHold);
  }
}
