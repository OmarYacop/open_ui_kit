import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// The composited-layer capture model is adapted from Flutter's BSD-licensed
// flutter_shaders AnimatedSampler, with lifecycle and API ownership kept local
// to Open UI Kit.

typedef UiFragmentShaderBuilder = Widget Function(
  BuildContext context,
  ui.FragmentShader shader,
  Widget child,
);

/// Loads and caches a bundled fragment program without a package dependency.
class UiShaderBuilder extends StatefulWidget {
  const UiShaderBuilder({
    super.key,
    required this.assetKey,
    required this.builder,
    required this.child,
  });

  final String assetKey;
  final UiFragmentShaderBuilder builder;
  final Widget child;

  @override
  State<UiShaderBuilder> createState() => _UiShaderBuilderState();
}

class _UiShaderBuilderState extends State<UiShaderBuilder> {
  static final _programs = <String, ui.FragmentProgram>{};

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load(widget.assetKey);
  }

  @override
  void didUpdateWidget(UiShaderBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetKey != widget.assetKey) _load(widget.assetKey);
  }

  Future<void> _load(String assetKey) async {
    try {
      final program = _programs[assetKey] ?? await _loadProgram(assetKey);
      _programs[assetKey] = program;
      if (!mounted || assetKey != widget.assetKey) return;
      final shader = program.fragmentShader();
      setState(() {
        _shader?.dispose();
        _shader = shader;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }

  Future<ui.FragmentProgram> _loadProgram(String assetKey) async {
    try {
      return await ui.FragmentProgram.fromAsset(assetKey);
    } catch (_) {
      const packagePrefix = 'packages/open_ui_kit/';
      if (!assetKey.startsWith(packagePrefix)) rethrow;
      return ui.FragmentProgram.fromAsset(
        assetKey.substring(packagePrefix.length),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    return shader == null
        ? widget.child
        : widget.builder(context, shader, widget.child);
  }
}

typedef UiShaderSamplerPainter = void Function(
  ui.Image image,
  Size logicalSize,
  ui.Canvas canvas,
);

/// Captures its live child into a texture for custom shader painting.
class UiShaderSampler extends SingleChildRenderObjectWidget {
  const UiShaderSampler({
    super.key,
    required this.painter,
    required super.child,
  });

  final UiShaderSamplerPainter painter;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderUiShaderSampler(
      painter: painter,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderUiShaderSampler)
      ..painter = painter
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderUiShaderSampler extends RenderProxyBox {
  _RenderUiShaderSampler({
    required UiShaderSamplerPainter painter,
    required double devicePixelRatio,
  }) : _painter = painter,
       _devicePixelRatio = devicePixelRatio;

  UiShaderSamplerPainter _painter;
  set painter(UiShaderSamplerPainter value) {
    if (_painter == value) return;
    _painter = value;
    markNeedsCompositedLayerUpdate();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsCompositedLayerUpdate();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant _UiShaderSamplerLayer? oldLayer,
  }) {
    final layer = oldLayer ?? _UiShaderSamplerLayer();
    return layer
      ..painter = _painter
      ..logicalSize = size
      ..devicePixelRatio = _devicePixelRatio;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!size.isEmpty) super.paint(context, offset);
  }
}

class _UiShaderSamplerLayer extends OffsetLayer {
  ui.Picture? _lastPicture;
  UiShaderSamplerPainter? _painter;
  Size _logicalSize = Size.zero;
  double _devicePixelRatio = 1;

  set painter(UiShaderSamplerPainter value) {
    if (_painter == value) return;
    _painter = value;
    markNeedsAddToScene();
  }

  set logicalSize(Size value) {
    if (_logicalSize == value) return;
    _logicalSize = value;
    markNeedsAddToScene();
  }

  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsAddToScene();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (_logicalSize.isEmpty || _painter == null) return;

    final childSceneBuilder = ui.SceneBuilder();
    final transform = Matrix4.diagonal3Values(
      _devicePixelRatio,
      _devicePixelRatio,
      1,
    );
    childSceneBuilder.pushTransform(transform.storage);
    addChildrenToScene(childSceneBuilder);
    childSceneBuilder.pop();
    final childImage = childSceneBuilder.build().toImageSync(
      (_logicalSize.width * _devicePixelRatio).ceil(),
      (_logicalSize.height * _devicePixelRatio).ceil(),
    );

    final recorder = ui.PictureRecorder();
    try {
      _painter!(childImage, _logicalSize, ui.Canvas(recorder));
    } finally {
      childImage.dispose();
    }
    final picture = recorder.endRecording();
    _lastPicture?.dispose();
    _lastPicture = picture;
    builder.addPicture(offset, picture);
  }

  @override
  void dispose() {
    _lastPicture?.dispose();
    super.dispose();
  }
}
