import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// Geometry shared by anchored floating surfaces such as selects,
/// comboboxes, and menus.
///
/// The resolver keeps viewport-safe placement policy in one place while
/// individual components still own their content height estimates and selected
/// row anchoring.
@immutable
class UiAnchoredOverlayGeometry {
  const UiAnchoredOverlayGeometry({
    required this.openAbove,
    required this.maxHeight,
    required this.width,
    required this.horizontalOffset,
    required this.targetOverlayRect,
    required this.targetGlobalRect,
    required this.triggerWidth,
    required this.topLimit,
    required this.bottomLimit,
    required this.gap,
  });

  final bool openAbove;
  final double maxHeight;
  final double width;
  final double horizontalOffset;
  final Rect targetOverlayRect;
  final Rect targetGlobalRect;
  final double triggerWidth;
  final double topLimit;
  final double bottomLimit;
  final double gap;
}

UiAnchoredOverlayGeometry? resolveUiAnchoredOverlayGeometry({
  required BuildContext context,
  required GlobalKey targetKey,
  required OverlayState overlay,
  required double desiredHeight,
  required double maxHeight,
  double minWidth = 0,
  double crampedAvailableHeight = 0,
  bool allowOverflowWhenCramped = false,
}) {
  final targetContext = targetKey.currentContext;
  if (targetContext == null) return null;

  final targetBox = targetContext.findRenderObject() as RenderBox?;
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (targetBox == null || overlayBox == null) return null;

  final tokens = UiThemeTokens.of(context);
  final media = MediaQuery.maybeOf(overlay.context);
  final boundaryMargin = tokens.spacing.x1;
  final gap = tokens.spacing.x1;
  final topLimit = (media?.padding.top ?? 0) + boundaryMargin;
  final bottomLimit = overlayBox.size.height -
      (media?.padding.bottom ?? 0) -
      (media?.viewInsets.bottom ?? 0) -
      boundaryMargin;
  final leftLimit = (media?.padding.left ?? 0) + boundaryMargin;
  final rightLimit =
      overlayBox.size.width - (media?.padding.right ?? 0) - boundaryMargin;

  final targetTopLeft = targetBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final targetRect = targetTopLeft & targetBox.size;
  final targetGlobalRect =
      targetBox.localToGlobal(Offset.zero) & targetBox.size;
  final spaceAbove = math.max(0.0, targetRect.top - topLimit - gap);
  final spaceBelow = math.max(0.0, bottomLimit - targetRect.bottom - gap);
  final openAbove = spaceBelow < desiredHeight && spaceAbove > spaceBelow;
  final available = openAbove ? spaceAbove : spaceBelow;
  final resolvedMaxHeight =
      allowOverflowWhenCramped && available <= crampedAvailableHeight
          ? maxHeight
          : math.max(0.0, math.min(maxHeight, available));

  final availableWidth = math.max(0.0, rightLimit - leftLimit);
  final width = math.min(math.max(minWidth, targetRect.width), availableWidth);
  var horizontalOffset = 0.0;
  final menuRight = targetRect.left + width;
  if (menuRight > rightLimit) {
    horizontalOffset = rightLimit - menuRight;
  }
  if (targetRect.left + horizontalOffset < leftLimit) {
    horizontalOffset = leftLimit - targetRect.left;
  }

  return UiAnchoredOverlayGeometry(
    openAbove: openAbove,
    maxHeight: resolvedMaxHeight,
    width: width,
    horizontalOffset: horizontalOffset,
    targetOverlayRect: targetRect,
    targetGlobalRect: targetGlobalRect,
    triggerWidth: targetRect.width,
    topLimit: topLimit,
    bottomLimit: bottomLimit,
    gap: gap,
  );
}
