import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Preferred physical side of a floating surface relative to its trigger.
enum UiAnchoredSurfaceSide { top, bottom, left, right }

/// Keeps a floating surface attached to its trigger during layout and scrolling.
///
/// The surface inherits the trigger's theme and locale, flips to the opposite
/// side when that side fits, and remains within the overlay's safe viewport.
/// Content, focus, outside-tap policy, and visibility remain caller-owned.
/// Use inside the nearest overlay, not beneath a CompositedTransformFollower;
/// Flutter needs the trigger's transform to be available during layout.
class UiAnchoredSurface extends StatelessWidget {
  const UiAnchoredSurface({
    super.key,
    required this.controller,
    required this.child,
    required this.overlayChild,
    this.side = UiAnchoredSurfaceSide.bottom,
    this.gap = 8,
    this.margin = 8,
  }) : assert(gap >= 0),
       assert(margin >= 0);

  final OverlayPortalController controller;
  final Widget child;
  final Widget overlayChild;
  final UiAnchoredSurfaceSide side;
  final double gap;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: controller,
      child: child,
      overlayChildBuilder: (context, info) {
        final anchor = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final viewport = Offset.zero & info.overlaySize;
        if (!anchor.overlaps(viewport)) return const SizedBox.shrink();
        final media = MediaQuery.maybeOf(context);
        final padding = media?.padding ?? EdgeInsets.zero;
        final keyboard = media?.viewInsets.bottom ?? 0;
        final left = math.min(info.overlaySize.width, padding.left + margin);
        final top = math.min(info.overlaySize.height, padding.top + margin);
        final right = math.max(
          left,
          info.overlaySize.width - padding.right - margin,
        );
        final bottom = math.max(
          top,
          info.overlaySize.height - math.max(padding.bottom, keyboard) - margin,
        );
        return Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _SurfaceLayout(
              anchor,
              Rect.fromLTRB(left, top, right, bottom),
              side,
              gap,
            ),
            child: overlayChild,
          ),
        );
      },
    );
  }
}

class _SurfaceLayout extends SingleChildLayoutDelegate {
  const _SurfaceLayout(this.anchor, this.bounds, this.side, this.gap);
  final Rect anchor;
  final Rect bounds;
  final UiAnchoredSurfaceSide side;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: bounds.width, maxHeight: bounds.height);

  Offset _position(UiAnchoredSurfaceSide side, Size child) => switch (side) {
    UiAnchoredSurfaceSide.top => Offset(
      anchor.center.dx - child.width / 2,
      anchor.top - child.height - gap,
    ),
    UiAnchoredSurfaceSide.bottom => Offset(
      anchor.center.dx - child.width / 2,
      anchor.bottom + gap,
    ),
    UiAnchoredSurfaceSide.left => Offset(
      anchor.left - child.width - gap,
      anchor.center.dy - child.height / 2,
    ),
    UiAnchoredSurfaceSide.right => Offset(
      anchor.right + gap,
      anchor.center.dy - child.height / 2,
    ),
  };

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var position = _position(side, childSize);
    final opposite = switch (side) {
      UiAnchoredSurfaceSide.top => UiAnchoredSurfaceSide.bottom,
      UiAnchoredSurfaceSide.bottom => UiAnchoredSurfaceSide.top,
      UiAnchoredSurfaceSide.left => UiAnchoredSurfaceSide.right,
      UiAnchoredSurfaceSide.right => UiAnchoredSurfaceSide.left,
    };
    bool fits(Offset p) =>
        p.dx >= bounds.left &&
        p.dy >= bounds.top &&
        p.dx + childSize.width <= bounds.right &&
        p.dy + childSize.height <= bounds.bottom;
    if (!fits(position)) {
      final alternate = _position(opposite, childSize);
      if (fits(alternate)) position = alternate;
    }
    return Offset(
      position.dx.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      position.dy.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(covariant _SurfaceLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      side != oldDelegate.side ||
      gap != oldDelegate.gap;
}
