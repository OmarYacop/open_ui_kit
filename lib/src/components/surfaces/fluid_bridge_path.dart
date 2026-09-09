import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_fluid_motion.dart';

/// Leave time for low-strength deformation to converge onto the surface.
double fluidBridgeStrength(double progress) {
  final remaining = (1 - progress / .9).clamp(0.0, 1.0);
  return remaining * remaining;
}

/// Internal outline for the connection and its separated, retracting lobes.
/// Proximity decides connectivity; strength controls remaining deformation.
Path fluidBridgePath(
  UiFluidGeometry source,
  UiFluidGeometry target,
  double strength,
) {
  final path = Path();
  if (strength <= 0) return path;
  final delta = target.rect.center - source.rect.center;
  if (delta.distance < .01) return path;
  final direction = delta / delta.distance;
  final perpendicular = Offset(-direction.dy, direction.dx);
  Offset endCenter(Rect rect, Offset toward) {
    final radius = rect.shortestSide / 2;
    return rect.center +
        Offset(
          toward.dx * (rect.width / 2 - radius),
          toward.dy * (rect.height / 2 - radius),
        );
  }

  final a = endCenter(source.rect, direction);
  final b = endCenter(target.rect, -direction);
  final ra = source.rect.shortestSide / 2;
  final rb = target.rect.shortestSide / 2;
  final gap = (b - a).distance - ra - rb;
  if (gap <= 0) return path;
  final reach = math.min(ra, rb) * 1.5 * math.sqrt(strength);
  final proximity = gap / reach;
  final angle = math.pi / 3 * math.sqrt(strength);
  final sine = math.sin(angle);
  final cosine = math.cos(angle);
  final aTop = a + direction * (ra * cosine) + perpendicular * (ra * sine);
  final bTop = b - direction * (rb * cosine) + perpendicular * (rb * sine);
  final aBottom = a + direction * (ra * cosine) - perpendicular * (ra * sine);
  final bBottom = b - direction * (rb * cosine) - perpendicular * (rb * sine);
  final handle = math.min(
    (bTop - aTop).distance * .5,
    math.min(ra, rb) * math.tan(angle) * .8,
  );
  final tangent = direction * (handle * sine);
  final inward = perpendicular * (handle * cosine);
  final c1 = aTop + tangent - inward;
  final c2 = bTop - tangent - inward;
  final c3 = bBottom - tangent + inward;
  final c4 = aBottom + tangent + inward;
  final middle = (a + direction * ra + b - direction * rb) / 2;

  double ease(double t) {
    final p = t.clamp(0.0, 1.0);
    return p * p * (3 - 2 * p);
  }

  // Preserve the accepted connected contour until close to its pinch point.
  final pinch = ease((proximity - .7) / .3);
  if (pinch == 0) {
    return path
      ..moveTo(aTop.dx, aTop.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, bTop.dx, bTop.dy)
      ..lineTo(bBottom.dx, bBottom.dy)
      ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, aBottom.dx, aBottom.dy)
      ..close();
  }

  // Split the original cubic at its midpoint. Its two halves evolve into
  // lobes, making the topology change continuous rather than removing paint.
  final oldMidTop = (aTop + c1 * 3 + c2 * 3 + bTop) / 8;
  final oldMidBottom = (bBottom + c3 * 3 + c4 * 3 + aBottom) / 8;
  final halfTopA = (aTop + c1 * 2 + c2) / 4;
  final halfTopB = (c1 + c2 * 2 + bTop) / 4;
  final halfBottomA = (c3 + c4 * 2 + aBottom) / 4;
  final halfBottomB = (bBottom + c3 * 2 + c4) / 4;
  final top = Offset.lerp(oldMidTop, middle, pinch)!;
  final bottom = Offset.lerp(oldMidBottom, middle, pinch)!;
  if (proximity <= 1) {
    final shiftTop = top - oldMidTop;
    final shiftBottom = bottom - oldMidBottom;
    return path
      ..moveTo(aTop.dx, aTop.dy)
      ..cubicTo(
        (aTop + c1).dx / 2,
        (aTop + c1).dy / 2,
        (halfTopA + shiftTop).dx,
        (halfTopA + shiftTop).dy,
        top.dx,
        top.dy,
      )
      ..cubicTo(
        (halfTopB + shiftTop).dx,
        (halfTopB + shiftTop).dy,
        (c2 + bTop).dx / 2,
        (c2 + bTop).dy / 2,
        bTop.dx,
        bTop.dy,
      )
      ..lineTo(bBottom.dx, bBottom.dy)
      ..cubicTo(
        (bBottom + c3).dx / 2,
        (bBottom + c3).dy / 2,
        (halfBottomB + shiftBottom).dx,
        (halfBottomB + shiftBottom).dy,
        bottom.dx,
        bottom.dy,
      )
      ..cubicTo(
        (halfBottomA + shiftBottom).dx,
        (halfBottomA + shiftBottom).dy,
        (c4 + aBottom).dx / 2,
        (c4 + aBottom).dy / 2,
        aBottom.dx,
        aBottom.dy,
      )
      ..close();
  }

  final retract = ease((proximity - 1) / 1.5);
  final extension = gap / 2 * (1 - retract);
  void lobe(
    Offset center,
    Offset toward,
    double radius,
    Offset upper,
    Offset lower,
    Offset upperControl,
    Offset lowerControl,
    Offset upperMid,
    Offset lowerMid,
  ) {
    final tip = center + toward * (radius + extension);
    var tipUpper = upperMid;
    var tipLower = lowerMid;
    // End on the actual circular arc, including its tangents. Collapsing
    // controls onto the attachment chord left a pointed silhouette that
    // vanished as the parent surface covered it.
    final arcHandle = radius * 4 / 3 * math.tan(angle / 4);
    final restingTip = center + toward * radius;
    final restingUpperControl =
        upper + (toward * sine - perpendicular * cosine) * arcHandle;
    final restingLowerControl =
        lower + (toward * sine + perpendicular * cosine) * arcHandle;
    upperControl = Offset.lerp(upperControl, restingUpperControl, retract)!;
    lowerControl = Offset.lerp(lowerControl, restingLowerControl, retract)!;
    tipUpper = Offset.lerp(
      tipUpper,
      restingTip + perpendicular * arcHandle,
      retract,
    )!;
    tipLower = Offset.lerp(
      tipLower,
      restingTip - perpendicular * arcHandle,
      retract,
    )!;
    path
      ..moveTo(upper.dx, upper.dy)
      ..cubicTo(
        upperControl.dx,
        upperControl.dy,
        tipUpper.dx,
        tipUpper.dy,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        tipLower.dx,
        tipLower.dy,
        lowerControl.dx,
        lowerControl.dy,
        lower.dx,
        lower.dy,
      )
      ..close();
  }

  lobe(
    a,
    direction,
    ra,
    aTop,
    aBottom,
    (aTop + c1) / 2,
    (aBottom + c4) / 2,
    halfTopA + middle - oldMidTop,
    halfBottomA + middle - oldMidBottom,
  );
  lobe(
    b,
    -direction,
    rb,
    bTop,
    bBottom,
    (bTop + c2) / 2,
    (bBottom + c3) / 2,
    halfTopB + middle - oldMidTop,
    halfBottomB + middle - oldMidBottom,
  );
  return path;
}

/// Union of token-shaped surfaces and their bridges. Stroke this outside
/// contour once to avoid border seams through a split/merge connection.
Path fluidUnionOutline({
  required List<UiFluidGeometry> surfaces,
  required List<(UiFluidGeometry, UiFluidGeometry, double)> connections,
  bool continuous = false,
}) {
  Path? outline;
  void unite(Path path) {
    if (path.getBounds().isEmpty) return;
    outline = outline == null
        ? path
        : Path.combine(PathOperation.union, outline!, path);
  }

  for (final surface in surfaces) {
    final shape = continuous
        ? RoundedSuperellipseBorder(borderRadius: surface.borderRadius)
        : RoundedRectangleBorder(borderRadius: surface.borderRadius);
    unite(shape.getOuterPath(surface.rect));
  }
  for (final connection in connections) {
    if (connection.$3 > 0) {
      unite(fluidBridgePath(connection.$1, connection.$2, connection.$3));
    }
  }
  return outline ?? Path();
}
