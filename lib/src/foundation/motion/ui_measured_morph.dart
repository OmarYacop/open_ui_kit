import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Morphs between two independently measured widget states.
///
/// The widget interpolates its layout size, aligns both states to the same
/// origin, clips overflow, and crossfades the content. It is suitable for
/// trigger-to-menu, compact-to-expanded, and other in-place transformations.
///
/// Drive [progress] from an [AnimationController] transformed by
/// [UiMotionSpec]. Only the visually active state participates in hit testing
/// and semantics.
class UiMeasuredMorph extends StatelessWidget {
  const UiMeasuredMorph({
    super.key,
    required this.progress,
    required this.collapsed,
    required this.expanded,
    this.alignment = Alignment.center,
    this.switchPoint = 0.5,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(progress >= 0 && progress <= 1),
       assert(switchPoint >= 0 && switchPoint <= 1);

  final double progress;
  final Widget collapsed;
  final Widget expanded;
  final AlignmentGeometry alignment;
  final double switchPoint;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final showExpanded = progress >= switchPoint;
    return _UiMeasuredMorphLayout(
      progress: progress,
      alignment: alignment.resolve(Directionality.of(context)),
      switchPoint: switchPoint,
      clipBehavior: clipBehavior,
      collapsed: IgnorePointer(
        ignoring: showExpanded,
        child: ExcludeSemantics(excluding: showExpanded, child: collapsed),
      ),
      expanded: IgnorePointer(
        ignoring: !showExpanded,
        child: ExcludeSemantics(excluding: !showExpanded, child: expanded),
      ),
    );
  }
}

class _UiMeasuredMorphLayout extends MultiChildRenderObjectWidget {
  _UiMeasuredMorphLayout({
    required this.progress,
    required this.alignment,
    required this.switchPoint,
    required this.clipBehavior,
    required Widget collapsed,
    required Widget expanded,
  }) : super(children: [collapsed, expanded]);

  final double progress;
  final Alignment alignment;
  final double switchPoint;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUiMeasuredMorph(
        progress: progress,
        alignment: alignment,
        switchPoint: switchPoint,
        clipBehavior: clipBehavior,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderUiMeasuredMorph renderObject,
  ) {
    renderObject
      ..progress = progress
      ..alignment = alignment
      ..switchPoint = switchPoint
      ..clipBehavior = clipBehavior;
  }
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderUiMeasuredMorph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderUiMeasuredMorph({
    required this._progress,
    required this._alignment,
    required this._switchPoint,
    required this._clipBehavior,
  });

  double _progress;
  Alignment _alignment;
  double _switchPoint;
  Clip _clipBehavior;

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsLayout();
  }

  set alignment(Alignment value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  set switchPoint(double value) {
    if (_switchPoint == value) return;
    _switchPoint = value;
    markNeedsPaint();
  }

  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  void performLayout() {
    final collapsed = firstChild!;
    final expanded = childAfter(collapsed)!;
    final childConstraints = constraints.loosen();
    collapsed.layout(childConstraints, parentUsesSize: true);
    expanded.layout(childConstraints, parentUsesSize: true);

    size = constraints.constrain(
      Size.lerp(collapsed.size, expanded.size, _progress)!,
    );
    _position(collapsed);
    _position(expanded);
  }

  void _position(RenderBox child) {
    final data = child.parentData! as _MorphParentData;
    data.offset = _alignment.alongOffset(
      Offset(size.width - child.size.width, size.height - child.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintChildren(PaintingContext context, Offset offset) {
      final collapsed = firstChild!;
      final expanded = childAfter(collapsed)!;
      _paintWithOpacity(context, offset, collapsed, 1 - _progress);
      _paintWithOpacity(context, offset, expanded, _progress);
    }

    if (_clipBehavior == Clip.none) {
      paintChildren(context, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      offset & size,
      paintChildren,
      clipBehavior: _clipBehavior,
    );
  }

  void _paintWithOpacity(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    double opacity,
  ) {
    if (opacity <= 0) return;
    final data = child.parentData! as _MorphParentData;
    context.pushOpacity(
      offset + data.offset,
      (opacity * 255).round().clamp(0, 255),
      (context, offset) => context.paintChild(child, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final collapsed = firstChild!;
    final expanded = childAfter(collapsed)!;
    final child = _progress >= _switchPoint ? expanded : collapsed;
    final data = child.parentData! as _MorphParentData;
    return result.addWithPaintOffset(
      offset: data.offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}
