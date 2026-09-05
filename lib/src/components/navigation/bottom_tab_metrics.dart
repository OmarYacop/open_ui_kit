import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

double resolveBottomTabBarHeight(
  BuildContext context,
  Iterable<String> labels, {
  double minimum = 54,
  double iconSize = 24,
  double iconGap = 2,
}) {
  final tokens = UiThemeTokens.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);
  final captionHeight = labels.fold<double>(0, (height, label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: tokens.typography.caption),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    return math.max(height, painter.height);
  });
  return math
      .max(minimum, iconSize + iconGap + captionHeight + tokens.spacing.x1)
      .ceilToDouble();
}
