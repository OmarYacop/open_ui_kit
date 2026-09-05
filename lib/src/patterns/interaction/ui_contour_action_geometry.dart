import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show immutable;

/// Input to [UiContourActionGeometrySolver.solve].
///
/// [triggerSize] and every entry in [actionSizes] are natural (intrinsic,
/// unconstrained) sizes measured once per layout pass — not interpolated,
/// not animated. [progress] is the only animated input; the solver itself
/// is a pure function with no notion of time, duration, or curve, which is
/// what makes it independently testable without pumping a widget tree.
@immutable
class UiContourActionGeometryInput {
  const UiContourActionGeometryInput({
    required this.triggerSize,
    required this.actionSizes,
    required this.spacing,
    required this.progress,
    this.activationThreshold = 0.92,
  });

  /// Natural size of the trigger surface. Constant for the duration of a
  /// transition — the trigger's own footprint does not change; only its
  /// internal content crosses over (see `UiContourRelease`'s trigger
  /// composition, which wraps a fixed-size content-handoff morph so the
  /// footprint this solver relies on stays a true constant).
  final Size triggerSize;

  /// Natural size of each released action, in order.
  final List<Size> actionSizes;

  /// Gap between the trigger and the first action, and between consecutive
  /// actions, at full expansion.
  final double spacing;

  /// Transition progress, expected in `[0, 1]`. Values outside that range
  /// are clamped defensively; the solver never produces overshoot on its
  /// own (see `doc/contour.md` on why geometry stays monotonic).
  final double progress;

  /// Fraction of full emergence (by rect width) an action must reach before
  /// it is eligible for pointer interaction and semantics.
  final double activationThreshold;
}

/// Resolved geometry for one instant of an action-release transition.
///
/// Every rectangle is in the same local coordinate space, start-relative
/// (as if `TextDirection.ltr`) — callers mirror for RTL at paint/hit-test
/// time using the ambient `Directionality`, so this solver never needs to
/// know about direction.
@immutable
class UiContourActionGeometry {
  const UiContourActionGeometry({
    required this.outerSize,
    required this.triggerRect,
    required this.actionRects,
    required this.actionVisibility,
    required this.actionInteractive,
  });

  final Size outerSize;
  final Rect triggerRect;
  final List<Rect> actionRects;

  /// 0..1 emergence fraction per action (rect width / natural width) —
  /// legibility-assist opacity, not the primary spatial signal.
  final List<double> actionVisibility;

  /// Whether each action has emerged far enough to accept pointer input and
  /// appear in semantics.
  final List<bool> actionInteractive;
}

/// Deterministic, pure geometry for the in-place action-release
/// interaction.
///
/// The model (Contour's "source surface separating into controls" variant
/// — see `doc/contour.md`): the trigger occupies a fixed rect. Each action
/// starts as a **zero-size point at the trigger's center** — materially
/// inside the trigger, overlapping with its siblings, not spread along an
/// edge and not merely invisible at its final position — and travels,
/// position and size together, to its final laid-out rect. Every
/// component of every rect is a linear interpolation between two fixed
/// endpoints, so the result is monotonic in `progress` by construction: no
/// oscillation, no recoil, and forward/reverse paths are the same function
/// evaluated at the same `progress`, so they are identical by definition.
abstract final class UiContourActionGeometrySolver {
  static UiContourActionGeometry solve(UiContourActionGeometryInput input) {
    final t = input.progress.clamp(0.0, 1.0);
    final trigger = input.triggerSize;

    var rowHeight = trigger.height;
    for (final size in input.actionSizes) {
      if (size.height > rowHeight) rowHeight = size.height;
    }

    final triggerRect = Rect.fromLTWH(
      0,
      (rowHeight - trigger.height) / 2,
      trigger.width,
      trigger.height,
    );

    final destRects = <Rect>[];
    var cursor = trigger.width;
    for (final size in input.actionSizes) {
      cursor += input.spacing;
      destRects.add(
        Rect.fromLTWH(
          cursor,
          (rowHeight - size.height) / 2,
          size.width,
          size.height,
        ),
      );
      cursor += size.width;
    }

    final actionRects = <Rect>[];
    final actionVisibility = <double>[];
    final actionInteractive = <bool>[];
    for (var i = 0; i < input.actionSizes.length; i++) {
      final naturalWidth = input.actionSizes[i].width;
      // Zero-size, at the trigger's trailing edge: every action shares this
      // exact point, so siblings overlap here at low progress — material
      // contained inside one source surface, not several independently
      // positioned controls. Anchoring at the edge (not centered deeper
      // inside the trigger) keeps outer-width growth immediate rather than
      // stalled while actions first travel back out past the trigger's own
      // bound.
      final source = Rect.fromLTWH(
        triggerRect.right,
        triggerRect.center.dy,
        0,
        0,
      );
      final rect = Rect.lerp(source, destRects[i], t)!;
      actionRects.add(rect);
      final visibility = naturalWidth <= 0
          ? 0.0
          : (rect.width / naturalWidth).clamp(0.0, 1.0);
      actionVisibility.add(visibility);
      actionInteractive.add(t >= input.activationThreshold);
    }

    var outerWidth = triggerRect.width;
    if (actionRects.isNotEmpty && actionRects.last.right > outerWidth) {
      outerWidth = actionRects.last.right;
    }

    return UiContourActionGeometry(
      outerSize: Size(outerWidth, rowHeight),
      triggerRect: triggerRect,
      actionRects: actionRects,
      actionVisibility: actionVisibility,
      actionInteractive: actionInteractive,
    );
  }
}
