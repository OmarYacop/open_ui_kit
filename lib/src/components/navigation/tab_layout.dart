import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Tuning knobs for the priority-compression layout.
///
/// Both [UiBottomTabBar] and [UiTabs] feed a [TabLayoutPolicy] into
/// [TabLayout.resolve] so their width compression, selected emphasis, and
/// overflow fallback behave identically.
class TabLayoutPolicy {
  const TabLayoutPolicy({
    required this.inactiveMin,
    required this.inactiveExpandCap,
    required this.selectedExtraRoom,
    required this.selectedAbsMin,
    required this.selectedMax,
  });

  final double inactiveMin;
  final double inactiveExpandCap;
  final double selectedExtraRoom;
  final double selectedAbsMin;
  final double selectedMax;
}

/// Resolved tab widths, left offsets, and per-candidate selection centres.
@immutable
class TabLayout {
  const TabLayout({
    required this.widths,
    required this.lefts,
    required this.selectionCenters,
    required this.selectedIndex,
  });

  final List<double> widths;
  final List<double> lefts;
  final List<double> selectionCenters;
  final int selectedIndex;

  double get selectedLeft => lefts[selectedIndex];

  /// Builds the full layout including per-candidate selection centres.
  static TabLayout resolve({
    required List<double> naturalWidths,
    required int selectedIndex,
    required double availableWidth,
    required TabLayoutPolicy policy,
  }) {
    final widths = _widthsForSelected(
      naturalWidths: naturalWidths,
      selectedIndex: selectedIndex,
      availableWidth: availableWidth,
      policy: policy,
    );
    final selectionCenters = [
      for (var i = 0; i < naturalWidths.length; i++)
        _centerForSelected(
          naturalWidths: naturalWidths,
          selectedIndex: i,
          availableWidth: availableWidth,
          policy: policy,
        ),
    ];
    return TabLayout.fromWidths(
      widths: widths,
      selectionCenters: selectionCenters,
      selectedIndex: selectedIndex,
    );
  }

  /// Builds from already-computed widths (used by [resolve] and in tests).
  static TabLayout fromWidths({
    required List<double> widths,
    List<double>? selectionCenters,
    required int selectedIndex,
  }) {
    var left = 0.0;
    final lefts = <double>[];
    for (final w in widths) {
      lefts.add(left);
      left += w;
    }
    return TabLayout(
      widths: widths,
      lefts: lefts,
      selectionCenters: selectionCenters ??
          [
            for (var i = 0; i < widths.length; i++) lefts[i] + widths[i] / 2,
          ],
      selectedIndex: selectedIndex,
    );
  }

  // ---------------------------------------------------------------------------
  // Layout algorithm
  // ---------------------------------------------------------------------------

  static List<double> _widthsForSelected({
    required List<double> naturalWidths,
    required int selectedIndex,
    required double availableWidth,
    required TabLayoutPolicy policy,
  }) {
    final n = naturalWidths.length;
    if (n == 0) return const <double>[];
    if (availableWidth <= 0) return List<double>.filled(n, 0);

    // 1. Desired widths: selected gets natural + extra (clamped), inactives
    //    keep their natural widths.
    final selectedNatural = naturalWidths[selectedIndex];
    final selectedFloor = selectedNatural > policy.selectedAbsMin
        ? selectedNatural
        : policy.selectedAbsMin;
    final selectedCap =
        selectedFloor > policy.selectedMax ? selectedFloor : policy.selectedMax;
    final selectedPreferred = (selectedNatural + policy.selectedExtraRoom)
        .clamp(selectedFloor, selectedCap)
        .toDouble();

    final widths = [
      for (var i = 0; i < n; i++)
        i == selectedIndex ? selectedPreferred : naturalWidths[i],
    ];
    final total = widths.fold<double>(0, (s, w) => s + w);

    // 2. Fits: distribute extra space proportionally to per-tab headroom.
    if (total <= availableWidth + 0.01) {
      final extra = availableWidth - total;
      if (extra > 0.01) {
        final selectedHead = selectedCap - widths[selectedIndex];
        var totalHead = selectedHead > 0 ? selectedHead : 0.0;
        for (var i = 0; i < n; i++) {
          if (i == selectedIndex) continue;
          final head = policy.inactiveExpandCap - widths[i];
          if (head > 0) totalHead += head;
        }
        if (totalHead > 0) {
          final share = (extra < totalHead ? extra : totalHead) / totalHead;
          if (selectedHead > 0) widths[selectedIndex] += share * selectedHead;
          for (var i = 0; i < n; i++) {
            if (i == selectedIndex) continue;
            final head = policy.inactiveExpandCap - widths[i];
            if (head > 0) widths[i] += share * head;
          }
        }
      }
      return widths;
    }

    // 3. Overflow: shrink inactives toward inactiveMin first.
    var overflow = total - availableWidth;
    var shrinkable = 0.0;
    for (var i = 0; i < n; i++) {
      if (i == selectedIndex) continue;
      final room = widths[i] - policy.inactiveMin;
      if (room > 0) shrinkable += room;
    }
    if (shrinkable >= overflow) {
      final share = overflow / shrinkable;
      for (var i = 0; i < n; i++) {
        if (i == selectedIndex) continue;
        final room = widths[i] - policy.inactiveMin;
        if (room > 0) widths[i] -= share * room;
      }
      return widths;
    }
    for (var i = 0; i < n; i++) {
      if (i == selectedIndex) continue;
      if (widths[i] > policy.inactiveMin) widths[i] = policy.inactiveMin;
    }
    overflow -= shrinkable;

    // 4. Still overflow: shrink selected toward selectedAbsMin.
    final selectedShrink = widths[selectedIndex] - policy.selectedAbsMin;
    if (selectedShrink >= overflow) {
      widths[selectedIndex] -= overflow;
      return widths;
    }

    // 5. Last resort: equal widths to prevent layout overflow.
    final equal = availableWidth / n;
    return List<double>.filled(n, equal);
  }

  static double _centerForSelected({
    required List<double> naturalWidths,
    required int selectedIndex,
    required double availableWidth,
    required TabLayoutPolicy policy,
  }) {
    final widths = _widthsForSelected(
      naturalWidths: naturalWidths,
      selectedIndex: selectedIndex,
      availableWidth: availableWidth,
      policy: policy,
    );
    final left = widths.take(selectedIndex).fold<double>(0, (s, w) => s + w);
    return left + widths[selectedIndex] / 2;
  }
}

// ---------------------------------------------------------------------------
// Drag zone helpers
// ---------------------------------------------------------------------------

/// Returns true if [localDx] is horizontally within the pill at [pillLeft]
/// (with [pillWidth]). Only horizontal alignment is considered — vertical
/// drift above or below the tab row does not invalidate a drag.
bool isInsideDraggedPillHorizontalZone({
  required double localDx,
  required double pillLeft,
  required double pillWidth,
}) {
  final horizontalInset = math.min(8.0, pillWidth * 0.15);
  return localDx >= pillLeft + horizontalInset &&
      localDx <= pillLeft + pillWidth - horizontalInset;
}

/// Returns true when [localDx] is close enough to the pill center to resume
/// tracking. This is intentionally stricter than [isInsideDraggedPillHorizontalZone]
/// so re-entering the tab row at the pill edge does not restart movement.
bool isInsideDraggedPillCenterZone({
  required double localDx,
  required double pillLeft,
  required double pillWidth,
}) {
  final center = pillLeft + pillWidth / 2;
  final radius = math.min(24.0, math.max(10.0, pillWidth * 0.25));
  return (localDx - center).abs() <= radius;
}

/// Converts a global pointer [globalPosition] to the local coordinate space of
/// the render box identified by [key]. Returns null if the render box is not
/// yet available or has no size.
///
/// Prefer [tabRowLocalPositionFromBox] inside drag updates so the render box
/// can be resolved once at drag start and reused, instead of walking the
/// render tree on every pointer event.
Offset? tabRowLocalPosition(GlobalKey key, Offset globalPosition) {
  final renderObject = key.currentContext?.findRenderObject();
  return tabRowLocalPositionFromBox(
    renderObject is RenderBox ? renderObject : null,
    globalPosition,
  );
}

/// Like [tabRowLocalPosition] but takes a pre-resolved [RenderBox]. Returns
/// null if [box] is null, detached, or has no size — callers can safely hold
/// a cached [RenderBox] for the duration of a drag and rely on this null
/// return to short-circuit the update.
Offset? tabRowLocalPositionFromBox(RenderBox? box, Offset globalPosition) {
  if (box == null || !box.attached || !box.hasSize) return null;
  return box.globalToLocal(globalPosition);
}

double? tabRowLocalDxFromBox(
  RenderBox? box,
  Offset globalPosition, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  final local = tabRowLocalPositionFromBox(box, globalPosition);
  if (local == null) return null;
  if (textDirection == TextDirection.rtl) {
    return box!.size.width - local.dx;
  }
  return local.dx;
}

// ---------------------------------------------------------------------------
// Shared drag state machine
// ---------------------------------------------------------------------------

/// Immutable snapshot of a tab pill drag in progress.
///
/// - [dragLeft] is the current pill left-offset in the row's local coordinate
///   space, or null if no drag is active.
/// - [trackingPaused] is true when the pointer has drifted horizontally out of
///   the pill zone. While paused the pill is frozen; it resumes when the
///   pointer catches up to the frozen pill.
@immutable
class TabDragState {
  const TabDragState({this.dragLeft, this.trackingPaused = false});

  final double? dragLeft;
  final bool trackingPaused;

  bool get isActive => dragLeft != null;

  static const TabDragState idle = TabDragState();
}

/// Result of ending a drag: the next state (always idle) and the selection
/// index to apply, or null if no selection change should be emitted.
@immutable
class TabDragEnd {
  const TabDragEnd({required this.state, this.selectionIndex});

  final TabDragState state;
  final int? selectionIndex;
}

/// Begins a drag if [globalPosition] lands inside the selected pill's
/// horizontal zone. Returns [TabDragState.idle] if the gesture should be
/// ignored.
TabDragState beginTabDrag({
  required Offset globalPosition,
  required RenderBox? rowBox,
  required TabLayout layout,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final localDx = tabRowLocalDxFromBox(
    rowBox,
    globalPosition,
    textDirection: textDirection,
  );
  if (localDx == null) return TabDragState.idle;
  final pillWidth = layout.widths[layout.selectedIndex];
  if (!isInsideDraggedPillHorizontalZone(
    localDx: localDx,
    pillLeft: layout.selectedLeft,
    pillWidth: pillWidth,
  )) {
    return TabDragState.idle;
  }
  return TabDragState(dragLeft: layout.selectedLeft);
}

/// Advances the drag state by one update.
///
/// Behaviour:
/// - If paused, the pill stays frozen. Resume only when the pointer catches
///   up to the frozen pill's center zone. On the resume frame we do not
///   apply the incoming delta — tracking continues on the next update.
/// - If active, the pill moves by [primaryDelta] but only if the proposed new
///   center still aligns with the pointer's horizontal position. Otherwise
///   the pill freezes in place and tracking pauses.
/// - Vertical motion never pauses or cancels.
TabDragState updateTabDrag({
  required TabDragState state,
  required double primaryDelta,
  required Offset globalPosition,
  required RenderBox? rowBox,
  required TabLayout layout,
  required double maxLeft,
  TextDirection textDirection = TextDirection.ltr,
}) {
  if (!state.isActive) return state;
  final localDx = tabRowLocalDxFromBox(
    rowBox,
    globalPosition,
    textDirection: textDirection,
  );
  if (localDx == null) return state;

  final pillWidth = layout.widths[layout.selectedIndex];
  final currentLeft = state.dragLeft!;

  if (state.trackingPaused) {
    final caughtUp = isInsideDraggedPillCenterZone(
      localDx: localDx,
      pillLeft: currentLeft,
      pillWidth: pillWidth,
    );
    if (!caughtUp) return state;
    // Resume on the next update; freeze-frame stays this frame so there is
    // no visible jump when the pointer re-enters.
    return TabDragState(dragLeft: currentLeft);
  }

  final proposedLeft = (currentLeft + primaryDelta).clamp(0.0, maxLeft);
  final proposedCenter = proposedLeft + pillWidth / 2;
  if ((localDx - proposedCenter).abs() <= pillWidth / 2) {
    return TabDragState(dragLeft: proposedLeft);
  }
  return TabDragState(dragLeft: currentLeft, trackingPaused: true);
}

/// Ends a drag.
///
/// - If the drag never started, returns idle with no selection.
/// - Otherwise, including while paused outside the tracking zone, picks the
///   nearest [TabLayout.selectionCenters] to the dragged pill's center and
///   returns it as [TabDragEnd.selectionIndex].
TabDragEnd endTabDrag({
  required TabDragState state,
  required TabLayout layout,
}) {
  if (!state.isActive) {
    return const TabDragEnd(state: TabDragState.idle);
  }
  final dragCenter = state.dragLeft! + layout.widths[layout.selectedIndex] / 2;
  var nextIndex = 0;
  var closestDistance = double.infinity;
  for (var i = 0; i < layout.selectionCenters.length; i++) {
    final center = layout.selectionCenters[i];
    final distance = (center - dragCenter).abs();
    if (distance < closestDistance) {
      closestDistance = distance;
      nextIndex = i;
    }
  }
  return TabDragEnd(
    state: TabDragState.idle,
    selectionIndex: nextIndex,
  );
}

/// Cancels the drag, returning idle state.
TabDragState cancelTabDrag() => TabDragState.idle;
