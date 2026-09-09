import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../theme/ui_theme_extensions.dart';

/// Shared clip geometry for token-shaped surfaces and their hit regions.
class UiCornerClip extends StatelessWidget {
  const UiCornerClip({
    super.key,
    required this.borderRadius,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    this.continuous,
  });

  final BorderRadiusGeometry borderRadius;
  final Widget child;
  final Clip clipBehavior;
  final bool? continuous;

  @override
  Widget build(BuildContext context) {
    final smooth = continuous ?? UiThemeTokens.radiusOf(context).isContinuous;
    final clip = smooth
        ? ClipRSuperellipse(
            borderRadius: borderRadius,
            clipBehavior: clipBehavior,
            child: child,
          )
        : ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: clipBehavior,
            child: child,
          );
    if (clipBehavior == Clip.none) return clip;
    return _CornerHitRegion(
      shape: smooth
          ? RoundedSuperellipseBorder(borderRadius: borderRadius)
          : RoundedRectangleBorder(borderRadius: borderRadius),
      direction: Directionality.maybeOf(context),
      child: clip,
    );
  }
}

// Framework RRect/superellipse clips paint the shape but their default hit
// testing is rectangular. Cache the matching outline only when input needs it.
class _CornerHitRegion extends SingleChildRenderObjectWidget {
  const _CornerHitRegion({
    required this.shape,
    required this.direction,
    required super.child,
  });
  final ShapeBorder shape;
  final TextDirection? direction;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCornerHitRegion(shape, direction);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCornerHitRegion renderObject,
  ) {
    renderObject.update(shape, direction);
  }
}

class _RenderCornerHitRegion extends RenderProxyBox {
  _RenderCornerHitRegion(this._shape, this._direction);
  ShapeBorder _shape;
  TextDirection? _direction;
  Path? _path;
  Size? _pathSize;

  void update(ShapeBorder shape, TextDirection? direction) {
    if (shape == _shape && direction == _direction) return;
    _shape = shape;
    _direction = direction;
    _path = null;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_path == null || _pathSize != size) {
      _path = _shape.getOuterPath(
        Offset.zero & size,
        textDirection: _direction,
      );
      _pathSize = size;
    }
    return _path!.contains(position) &&
        super.hitTest(result, position: position);
  }
}
