import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/effects/ui_shader_sampler.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

const _progressiveBlurSigma = 14.0;
const _materialFadeHold = 0.12;
// Keep the progressive material visibly translucent even when callers request a
// stronger edge fade. The progressive blur supplies the remaining separation.
const _materialMaxTintOpacity = 0.84;
const _progressiveBlurShader =
    'packages/open_ui_kit/lib/src/patterns/layout/shaders/'
    'ui_progressive_blur.frag';

/// Paints platform-adaptive fades over scrolling content.
///
/// Android and Apple platforms use continuous progressive top blur and adaptive
/// tint by default, with tint alone at the bottom. Other platforms use gradients.
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
    this.enableProgressiveBlur = true,
    this.topProtectionExtent = 0,
  }) : assert(extent >= 0),
       assert(topProtectionExtent >= 0),
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

  /// Enables progressive top blur on Android, iOS and macOS. Set false to
  /// retain tint without blur.
  final bool enableProgressiveBlur;

  /// Translucent chrome protection before the remaining top fade tapers away.
  /// Keeps bright media from competing with system icons and fixed titles.
  final double topProtectionExtent;

  @override
  Widget build(BuildContext context) {
    final usesProgressiveMaterial = switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.android => true,
      _ => false,
    };
    final brightness = UiThemeTokens.brightnessOf(context);
    final materialFadeColor = brightness == Brightness.dark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final materialEdgeOpacity = maxOpacity > _materialMaxTintOpacity
        ? _materialMaxTintOpacity
        : maxOpacity;
    final topEdgeColor = usesProgressiveMaterial
        ? materialFadeColor.withValues(alpha: materialEdgeOpacity)
        : backgroundColor.withValues(alpha: maxOpacity);
    final transparentTopEdgeColor = usesProgressiveMaterial
        ? materialFadeColor.withValues(alpha: 0)
        : backgroundColor.withValues(alpha: 0);
    final bottomEdgeColor = topEdgeColor;
    final transparentBottomEdgeColor = transparentTopEdgeColor;
    final topBlurSigma = enableProgressiveBlur && usesProgressiveMaterial
        ? UiThemeTokens.effectsOf(context).scaleBlur(_progressiveBlurSigma)
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

    final protectedFraction = effectiveTopExtent <= 0
        ? 0.0
        : (topProtectionExtent / effectiveTopExtent).clamp(0.0, 0.75);
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
              holdFraction: protectedFraction > 0 ? protectedFraction : null,
              transparentEdgeColor: transparentTopEdgeColor,
              holdsEdgeColor: usesProgressiveMaterial,
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
              holdsEdgeColor: usesProgressiveMaterial,
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
    this.holdFraction,
  });

  final Alignment begin;
  final Alignment end;
  final Color edgeColor;
  final Color transparentEdgeColor;
  final bool holdsEdgeColor;
  final double? holdFraction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: holdsEdgeColor || holdFraction != null
              ? [edgeColor, edgeColor, transparentEdgeColor]
              : [edgeColor, transparentEdgeColor],
          stops: holdsEdgeColor || holdFraction != null
              ? [0, holdFraction ?? _materialFadeHold, 1]
              : null,
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
    // Both complementary clips must meet on the same physical pixel. An
    // antialiased shader clip leaves a dark seam against the hard-edged child
    // clip on Android when the measured header height is fractional.
    final alignedExtent = (extent * pixelRatio).roundToDouble() / pixelRatio;
    return RepaintBoundary(
      child: UiShaderBuilder(
        assetKey: _progressiveBlurShader,
        child: child,
        builder: (context, shader, sampledChild) => UiShaderSampler(
          key: const Key('ui_scroll_edge_progressive_blur'),
          paintChild: true,
          childPaintBounds: (size) => ui.Rect.fromLTRB(
            0,
            math.min(alignedExtent, size.height),
            size.width,
            size.height,
          ),
          // Preserve full-resolution sampling and the full Gaussian kernel.
          // The apron supplies vertical taps below the visible fade boundary.
          sampleBounds: (size) => ui.Rect.fromLTWH(
            0,
            0,
            size.width,
            math.min(
              size.height,
              alignedExtent + (3 * sigma).ceil() / pixelRatio,
            ),
          ),
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
              canvas.clipRect(
                ui.Rect.fromLTWH(
                  0,
                  0,
                  pixelSize.width,
                  math.min(pixelSize.height, alignedExtent * pixelRatio),
                ),
                doAntiAlias: false,
              );
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
    shader.setFloat(5, _materialFadeHold);
  }
}
