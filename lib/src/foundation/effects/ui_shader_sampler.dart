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
  static final _pendingPrograms = <String, Future<ui.FragmentProgram>>{};

  ui.FragmentShader? _shader;
  final _contentKey = GlobalKey();

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
      var program = _programs[assetKey];
      if (program == null) {
        try {
          program = await _pendingPrograms.putIfAbsent(
            assetKey,
            () => _loadProgram(assetKey),
          );
          _programs[assetKey] = program;
        } finally {
          _pendingPrograms.remove(assetKey);
        }
      }
      if (!mounted || assetKey != widget.assetKey) return;
      final shader = program.fragmentShader();
      setState(() {
        _shader?.dispose();
        _shader = shader;
      });
    } catch (error, stackTrace) {
      _programs.remove(assetKey);
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
    // Loading inserts a shader wrapper around the live page. Retain its state
    // while moving it into that wrapper (including focus, forms and scroll).
    final child = KeyedSubtree(key: _contentKey, child: widget.child);
    return shader == null ? child : widget.builder(context, shader, child);
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
    this.sampleBounds,
    this.paintChild = false,
    this.childPaintBounds,
  });

  final UiShaderSamplerPainter painter;

  /// Optional texture region in child-local logical coordinates. The painter
  /// receives this region's size and a canvas whose origin is its top-left.
  final Rect Function(Size size)? sampleBounds;

  /// Paint the original child before the sampled overlay. Useful when only
  /// a small region needs a shader, avoiding a full-page intermediate texture.
  final bool paintChild;

  /// Optional unfiltered region. Separating it from the shader overlay avoids
  /// double compositing translucent pixels at the sampled edge.
  final Rect Function(Size size)? childPaintBounds;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderUiShaderSampler(
      painter: painter,
      sampleBounds: sampleBounds,
      paintChild: paintChild,
      childPaintBounds: childPaintBounds,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderUiShaderSampler)
      ..painter = painter
      ..sampleBounds = sampleBounds
      ..paintChild = paintChild
      ..childPaintBounds = childPaintBounds
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class _RenderUiShaderSampler extends RenderProxyBox {
  _RenderUiShaderSampler({
    required this._painter,
    required this._devicePixelRatio,
    this._sampleBounds,
    this._paintChild = false,
    this._childPaintBounds,
  });

  UiShaderSamplerPainter _painter;
  set painter(UiShaderSamplerPainter value) {
    if (_painter == value) return;
    _painter = value;
    markNeedsCompositedLayerUpdate();
  }

  Rect Function(Size)? _sampleBounds;
  set sampleBounds(Rect Function(Size)? value) {
    if (_sampleBounds == value) return;
    _sampleBounds = value;
    markNeedsCompositedLayerUpdate();
  }

  Rect Function(Size)? _childPaintBounds;
  set childPaintBounds(Rect Function(Size)? value) {
    if (_childPaintBounds == value) return;
    _childPaintBounds = value;
    markNeedsCompositedLayerUpdate();
  }

  bool _paintChild;
  set paintChild(bool value) {
    if (_paintChild == value) return;
    _paintChild = value;
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
      ..sampleBounds = _sampleBounds?.call(size)
      ..paintChild = _paintChild
      ..childPaintBounds = _childPaintBounds?.call(size)
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
  Rect? _childPaintBounds;
  set childPaintBounds(Rect? value) {
    if (_childPaintBounds == value) return;
    _childPaintBounds = value;
    markNeedsAddToScene();
  }

  Rect? _sampleBounds;
  bool _paintChild = false;

  set sampleBounds(Rect? value) {
    if (_sampleBounds == value) return;
    _sampleBounds = value;
    markNeedsAddToScene();
  }

  set paintChild(bool value) {
    if (_paintChild == value) return;
    _paintChild = value;
    markNeedsAddToScene();
  }

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

    if (_paintChild) {
      final clip = _childPaintBounds;
      if (clip != null) {
        builder.pushClipRect(clip.shift(offset), clipBehavior: Clip.hardEdge);
      }
      super.addToScene(builder);
      if (clip != null) builder.pop();
    }
    final bounds = (_sampleBounds ?? (Offset.zero & _logicalSize)).intersect(
      Offset.zero & _logicalSize,
    );
    if (bounds.isEmpty) return;
    final childSceneBuilder = ui.SceneBuilder();
    final transform = Matrix4.diagonal3Values(
      _devicePixelRatio,
      _devicePixelRatio,
      1,
    );
    transform.setTranslationRaw(
      -bounds.left * _devicePixelRatio,
      -bounds.top * _devicePixelRatio,
      0,
    );
    childSceneBuilder.pushTransform(transform.storage);
    addChildrenToScene(childSceneBuilder);
    childSceneBuilder.pop();
    final scene = childSceneBuilder.build();
    final ui.Image childImage;
    try {
      childImage = scene.toImageSync(
        (bounds.width * _devicePixelRatio).ceil(),
        (bounds.height * _devicePixelRatio).ceil(),
      );
    } finally {
      scene.dispose();
    }

    final recorder = ui.PictureRecorder();
    try {
      _painter!(childImage, bounds.size, ui.Canvas(recorder));
    } finally {
      childImage.dispose();
    }
    final picture = recorder.endRecording();
    _lastPicture?.dispose();
    _lastPicture = picture;
    builder.addPicture(offset + bounds.topLeft, picture);
  }

  @override
  void dispose() {
    _lastPicture?.dispose();
    super.dispose();
  }
}
