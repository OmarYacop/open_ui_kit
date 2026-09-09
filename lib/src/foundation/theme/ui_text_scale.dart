import 'package:flutter/widgets.dart';

/// Default ceiling for [uiChromeScale].
const double kUiChromeScaleMax = 1.3;

/// How much fixed-size *chrome* should grow with the user's text scale.
///
/// Content icons (an `Icon` in a list row, a message, a card) ride the full
/// [MediaQuery] text scale because the root `IconTheme` in `UiApp` enables
/// `applyTextScaling`. Chrome — tab bars, rails, marker tiles —
/// lives inside fixed boxes that would clip a 2x or 3x icon, and a bar that
/// tripled in height would eat the screen. So chrome follows the text scale
/// only up to [max] (1.3x by default, roughly iOS "Large" accessibility
/// sizes): the container *and* the icon inside it are multiplied by this
/// factor, with `applyTextScaling: false` on the icon so it is not scaled a
/// second time.
///
/// Icon-only buttons use fixed geometry independently of this helper.
///
/// Never returns less than 1.0 — chrome does not shrink for small text.
double uiChromeScale(BuildContext context, {double max = kUiChromeScaleMax}) =>
    uiChromeScaleFor(MediaQuery.textScalerOf(context), max: max);

/// [uiChromeScale] for a [TextScaler] you already hold (for example inside a
/// cached layout pass that measures with the same scaler).
double uiChromeScaleFor(TextScaler scaler, {double max = kUiChromeScaleMax}) =>
    scaler.scale(1).clamp(1.0, max).toDouble();
