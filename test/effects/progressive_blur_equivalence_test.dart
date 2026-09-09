import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_ui_kit/src/foundation/effects/ui_shader_sampler.dart';
import 'package:open_ui_kit/src/patterns/layout/ui_scroll_edge_fade.dart';

const _progressiveBlurShader =
    'packages/open_ui_kit/lib/src/patterns/layout/shaders/ui_progressive_blur.frag';
const _appleFadeHold = .12;

void main() {
  for (final dpr in [2.0, 2.625]) {
    testWidgets('fractional blur boundary has no dark seam at DPR $dpr', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      const extent = 115.37;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(devicePixelRatio: dpr),
            child: RepaintBoundary(
              key: boundary,
              child: const ColoredBox(
                color: Color(0xff000000),
                child: UiScrollEdgeFade(
                  backgroundColor: Color(0xff000000),
                  maxOpacity: 0,
                  topExtent: extent,
                  showBottom: false,
                  child: ColoredBox(color: Color(0xffffffff)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: dpr),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final edge = (extent * dpr).round();
      for (var y = edge - 2; y <= edge + 2; y++) {
        final offset = (y * image.width + image.width ~/ 2) * 4;
        expect(
          bytes.getUint8(offset),
          greaterThanOrEqualTo(254),
          reason: 'red at $y',
        );
        expect(
          bytes.getUint8(offset + 1),
          greaterThanOrEqualTo(254),
          reason: 'green at $y',
        );
        expect(
          bytes.getUint8(offset + 2),
          greaterThanOrEqualTo(254),
          reason: 'blue at $y',
        );
      }
      image.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('bounded blur preserves full-page pixels, including alpha', (
    tester,
  ) async {
    final platform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = platform);
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    Future<ui.Image> render(bool reference) async {
      const pattern = CustomPaint(
        painter: _Pattern(),
        child: SizedBox.expand(),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2),
            child: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: const Color(0xff224466),
                child: reference
                    ? const _ReferenceBlur(
                        sigma: 14,
                        extent: 128,
                        child: pattern,
                      )
                    : const UiScrollEdgeFade(
                        enableProgressiveBlur: true,
                        backgroundColor: Color(0xff224466),
                        maxOpacity: 0,
                        topExtent: 128,
                        showBottom: false,
                        child: pattern,
                      ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .runAsync(
            () =>
                (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2),
          )
          .then((value) => value!);
    }

    final reference = await render(true);
    final optimized = await render(false);
    final sampler = tester.widget<UiShaderSampler>(
      find.byType(UiShaderSampler),
    );
    expect(
      sampler.sampleBounds!(const Size(320, 640)),
      const Rect.fromLTWH(0, 0, 320, 149),
    );
    expect(
      sampler.childPaintBounds!(const Size(320, 640)),
      const Rect.fromLTRB(0, 128, 320, 640),
    );
    final data = await tester.runAsync(
      () async => [
        (await reference.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
            .asUint8List(),
        (await optimized.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
            .asUint8List(),
      ],
    );
    int maxDifference = 0, changed = 0, totalDifference = 0;
    for (var i = 0; i < data![0].length; i++) {
      final d = (data[0][i] - data[1][i]).abs();
      if (d > maxDifference) maxDifference = d;
      if (d > 0) changed++;
      totalDifference += d;
    }
    debugPrint(
      'BLUR_EQ max=$maxDifference changed=$changed mean=${totalDifference / data[0].length}',
    );
    expect(maxDifference, lessThanOrEqualTo(1));
    reference.dispose();
    optimized.dispose();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = platform;
  });
}

class _Pattern extends CustomPainter {
  const _Pattern();
  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0.0; y < size.height; y += 7) {
      for (var x = 0.0; x < size.width; x += 11) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, 9, 5),
          Paint()
            ..color = Color.fromARGB(
              ((x + y) % 3 == 0) ? 110 : 255,
              (x * 3).toInt() % 255,
              (y * 5).toInt() % 255,
              180,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Pattern old) => false;
}

class _ReferenceBlur extends StatelessWidget {
  const _ReferenceBlur({
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
