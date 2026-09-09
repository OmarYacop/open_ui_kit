import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

/// Height of the shared compact navigation row, excluding safe insets and the
/// page-to-content gap. Measure text rather than scaling the whole toolbar.
double uiCompactNavigationRowHeight(
  BuildContext context, {
  double minimumHeight = 52,
  double controlExtent = 44,
  bool hasSubtitle = false,
}) {
  final tokens = UiThemeTokens.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  double lineHeight(TextStyle style) =>
      (scaler.scale(style.fontSize ?? 16) * (style.height ?? 1.2))
          .ceilToDouble();
  final textHeight =
      lineHeight(tokens.typography.subheading) +
      (hasSubtitle ? lineHeight(tokens.typography.caption) : 0);
  return math.max(
    minimumHeight - tokens.spacing.x2,
    math.max(controlExtent, textHeight),
  );
}
