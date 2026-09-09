import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_text_scale.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/tokens/ui_bottom_navigation_tokens.dart';

/// Bar height for the paged/drawer tab bars. [iconSize] is the *design*
/// size; the bar reserves the chrome-scaled size (see [uiChromeScale]) so a
/// larger system font never squeezes the icon into the caption.
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
  final scaledIconSize = iconSize * uiChromeScaleFor(textScaler);
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
      .max(
        minimum,
        scaledIconSize + iconGap + captionHeight + tokens.spacing.x1,
      )
      .ceilToDouble();
}

/// The theme's [UiBottomNavigationTokens] with its icon geometry grown by
/// [uiChromeScale]. The expanding dock and the scaffold's body inset both
/// read this so the bar, its tiles and the space reserved beneath the body
/// agree at every text scale. `compactHeight` only grows when the scaled
/// icon area would no longer fit with 4pt of breathing room on each side.
UiBottomNavigationTokens resolveScaledBottomNavigationTokens(
  BuildContext context,
) {
  final base = UiThemeTokens.of(context).bottomNavigation;
  final scale = uiChromeScale(context);
  if (scale == 1.0) return base;
  final iconArea = base.iconArea * scale;
  return base.copyWith(
    iconArea: iconArea,
    iconSize: base.iconSize * scale,
    compactHeight: math.max(base.compactHeight, iconArea + 8),
    minRowHeight: math.max(base.minRowHeight, iconArea),
  );
}
