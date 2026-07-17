import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Resolves a bottom offset for floating components that intentionally sit near
/// the physical screen edge.
///
/// On devices with a home indicator / rounded physical bottom edge, the safe
/// area bottom inset is usually larger than the visually useful gap. This
/// helper infers a conservative device-edge radius from [MediaQuery.viewPadding]
/// and lets components sit closer to that edge while preserving a caller-defined
/// minimum.
double resolveUiEdgeAwareBottomOffset(
  BuildContext context, {
  required double minimum,
}) {
  final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0;
  final viewBottomInset = MediaQuery.maybeViewPaddingOf(context)?.bottom ?? 0;
  if (bottomInset <= 0 || viewBottomInset <= 0) return minimum;

  final inferredRadius = viewBottomInset.clamp(14.0, 28.0);
  return math.max(minimum, bottomInset - inferredRadius);
}
