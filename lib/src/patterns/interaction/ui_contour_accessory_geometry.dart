import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show immutable;

/// Input to [UiContourAccessoryGeometrySolver.solve].
///
/// Unlike [UiContourActionGeometrySolver] (one persistent capsule
/// containing everything), this models **two independent surfaces** that
/// share only a progress timeline and a material identity (same color
/// tokens) — no common parent container. This is the shape needed when a
/// released accessory (e.g. a search field) separates from persistent
/// chrome (e.g. a bottom navigation bar) that itself visibly recedes to
/// make room, rather than growing to contain the accessory.
@immutable
class UiContourAccessoryGeometryInput {
  const UiContourAccessoryGeometryInput({
    required this.barSize,
    required this.sourceRect,
    required this.accessorySize,
    required this.progress,
    this.contentThreshold = 0.5,
  });

  /// Natural size of the persistent bar at rest (fully expanded).
  final Size barSize;

  /// Where the accessory originates from, in the bar's local coordinate
  /// space — typically the trigger icon's own rect within the bar. The
  /// accessory starts co-located with this rect (not zero-size — see
  /// [UiContourAccessoryGeometry.accessoryRect]) and grows from it.
  final Rect sourceRect;

  /// Natural size of the fully-expanded accessory surface.
  final Size accessorySize;

  /// Transition progress, expected in `[0, 1]`. Values outside that range
  /// are clamped defensively.
  final double progress;

  /// Progress past which the bar's own content is considered handed off
  /// (e.g. trailing bar items fully faded) — content-only, not geometry.
  final double contentThreshold;
}

/// Resolved geometry for one instant of an accessory-release transition.
///
/// [barRect] and [accessoryRect] are two **independent** rects — there is
/// no shared outer bounds. Both are pure linear interpolations between
/// fixed endpoints derived from the same `progress`, so each is monotonic
/// on its own and forward/reverse paths are identical by construction (see
/// `doc/contour.md`).
@immutable
class UiContourAccessoryGeometry {
  const UiContourAccessoryGeometry({
    required this.barRect,
    required this.accessoryRect,
    required this.accessoryVisibility,
    required this.barContentVisibility,
    required this.accessoryInteractive,
  });

  /// The bar's current rect. Recedes (shrinks) by exactly the width the
  /// accessory claims, anchored at its leading edge, so the two surfaces
  /// never overlap once separated.
  final Rect barRect;

  /// The accessory's current rect, growing from [UiContourAccessoryGeometryInput.sourceRect]
  /// to its full size at the bar's trailing edge.
  final Rect accessoryRect;

  /// 0..1 emergence fraction — legibility-assist opacity for the accessory,
  /// not the primary spatial signal.
  final double accessoryVisibility;

  /// 0..1 fade for the bar's own receding trailing content (icons that lose
  /// their space) — independent of [accessoryVisibility] so the bar's
  /// content handoff can be tuned separately from the accessory's reveal.
  final double barContentVisibility;

  final bool accessoryInteractive;
}

/// Deterministic, pure geometry for a persistent-chrome accessory release:
/// a bar recedes by exactly the width an accessory claims, while that
/// accessory grows from a source point inside the bar to an independent
/// floating surface. See `doc/contour.md`.
abstract final class UiContourAccessoryGeometrySolver {
  static UiContourAccessoryGeometry solve(
    UiContourAccessoryGeometryInput input,
  ) {
    final t = input.progress.clamp(0.0, 1.0);
    final bar = input.barSize;
    final accessory = input.accessorySize;

    final barDest = Rect.fromLTWH(
      0,
      0,
      (bar.width - accessory.width).clamp(0.0, bar.width),
      bar.height,
    );
    final barStart = Rect.fromLTWH(0, 0, bar.width, bar.height);
    final barRect = Rect.lerp(barStart, barDest, t)!;

    final accessoryDest = Rect.fromLTWH(
      barDest.width,
      (bar.height - accessory.height) / 2,
      accessory.width,
      accessory.height,
    );
    final accessoryRect = Rect.lerp(input.sourceRect, accessoryDest, t)!;

    // Unlike UiContourActionGeometrySolver's zero-size source point, this
    // solver's source rect is the search icon's real footprint (non-zero),
    // so a width-ratio visibility would never reach 0 at rest — the
    // accessory surface would coincide with, and duplicate, the visible
    // search icon. Progress itself is the correct fade here: fully hidden
    // at t=0 (exactly coincident with the icon), ramping to fully visible.
    final accessoryVisibility = t.clamp(0.0, 1.0);

    return UiContourAccessoryGeometry(
      barRect: barRect,
      accessoryRect: accessoryRect,
      accessoryVisibility: accessoryVisibility,
      barContentVisibility: (1 - (t / input.contentThreshold)).clamp(0.0, 1.0),
      accessoryInteractive: t >= 0.92,
    );
  }
}
