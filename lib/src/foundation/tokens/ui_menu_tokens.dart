import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Menu-specific surface and interaction tokens. Colors, spacing, typography
/// and radii resolve from the shared theme palettes.
@immutable
class UiMenuTokens {
  const UiMenuTokens({
    this.surfaceOpacity = .84,
    this.borderOpacity = .18,
    this.borderWidth = .5,
    this.borderColor,
    this.backdropBlurSigma = 16,
    this.parentScale = .96,
    this.scrimOpacity = .24,
    this.maxHeight = 420,
    this.iconSize = 17,
    this.pressExpansion = .15,
    this.springStrength = .25,
    this.travelArc = 24,
    this.rowPaddingVertical = 8,
    this.rowPaddingHorizontal = 10,
    this.rowMinHeight = 36,
    this.closeDuration = const Duration(milliseconds: 280),
    this.submenuDwellDuration = const Duration(milliseconds: 350),
  });
  static const defaults = UiMenuTokens();
  final double surfaceOpacity;
  final double borderOpacity;
  final double borderWidth;

  /// Exact outline color override, including alpha. Null uses the foreground
  /// color with [borderOpacity].
  final Color? borderColor;
  final double backdropBlurSigma;
  final double parentScale;
  final double scrimOpacity;
  final double maxHeight;
  final double iconSize;
  final double pressExpansion;
  final double springStrength;
  final double travelArc;
  final double rowPaddingVertical;
  final double rowPaddingHorizontal;
  final double rowMinHeight;
  final Duration closeDuration;
  final Duration submenuDwellDuration;
  UiMenuTokens copyWith({
    double? surfaceOpacity,
    double? borderOpacity,
    double? borderWidth,
    Color? borderColor,
    double? backdropBlurSigma,
    double? parentScale,
    double? scrimOpacity,
    double? maxHeight,
    double? iconSize,
    double? pressExpansion,
    double? springStrength,
    double? travelArc,
    double? rowPaddingVertical,
    double? rowPaddingHorizontal,
    double? rowMinHeight,
    Duration? closeDuration,
    Duration? submenuDwellDuration,
  }) => UiMenuTokens(
    surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
    borderOpacity: borderOpacity ?? this.borderOpacity,
    borderWidth: borderWidth ?? this.borderWidth,
    borderColor: borderColor ?? this.borderColor,
    backdropBlurSigma: backdropBlurSigma ?? this.backdropBlurSigma,
    parentScale: parentScale ?? this.parentScale,
    scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    maxHeight: maxHeight ?? this.maxHeight,
    iconSize: iconSize ?? this.iconSize,
    pressExpansion: pressExpansion ?? this.pressExpansion,
    springStrength: springStrength ?? this.springStrength,
    travelArc: travelArc ?? this.travelArc,
    rowPaddingVertical: rowPaddingVertical ?? this.rowPaddingVertical,
    rowPaddingHorizontal: rowPaddingHorizontal ?? this.rowPaddingHorizontal,
    rowMinHeight: rowMinHeight ?? this.rowMinHeight,
    closeDuration: closeDuration ?? this.closeDuration,
    submenuDwellDuration: submenuDwellDuration ?? this.submenuDwellDuration,
  );
  static UiMenuTokens lerp(
    UiMenuTokens a,
    UiMenuTokens b,
    double t,
  ) => UiMenuTokens(
    surfaceOpacity:
        a.surfaceOpacity + (b.surfaceOpacity - a.surfaceOpacity) * t,
    borderOpacity: a.borderOpacity + (b.borderOpacity - a.borderOpacity) * t,
    borderWidth: a.borderWidth + (b.borderWidth - a.borderWidth) * t,
    borderColor: Color.lerp(a.borderColor, b.borderColor, t),
    backdropBlurSigma:
        a.backdropBlurSigma + (b.backdropBlurSigma - a.backdropBlurSigma) * t,
    parentScale: a.parentScale + (b.parentScale - a.parentScale) * t,
    scrimOpacity: a.scrimOpacity + (b.scrimOpacity - a.scrimOpacity) * t,
    maxHeight: a.maxHeight + (b.maxHeight - a.maxHeight) * t,
    iconSize: a.iconSize + (b.iconSize - a.iconSize) * t,
    travelArc: a.travelArc + (b.travelArc - a.travelArc) * t,
    pressExpansion:
        a.pressExpansion + (b.pressExpansion - a.pressExpansion) * t,
    springStrength:
        a.springStrength + (b.springStrength - a.springStrength) * t,
    rowPaddingVertical:
        a.rowPaddingVertical +
        (b.rowPaddingVertical - a.rowPaddingVertical) * t,
    rowPaddingHorizontal:
        a.rowPaddingHorizontal +
        (b.rowPaddingHorizontal - a.rowPaddingHorizontal) * t,
    rowMinHeight: a.rowMinHeight + (b.rowMinHeight - a.rowMinHeight) * t,
    closeDuration: Duration(
      microseconds:
          (a.closeDuration.inMicroseconds +
                  (b.closeDuration.inMicroseconds -
                          a.closeDuration.inMicroseconds) *
                      t)
              .round(),
    ),
    submenuDwellDuration: Duration(
      microseconds:
          (a.submenuDwellDuration.inMicroseconds +
                  (b.submenuDwellDuration.inMicroseconds -
                          a.submenuDwellDuration.inMicroseconds) *
                      t)
              .round(),
    ),
  );
  @override
  bool operator ==(Object other) =>
      other is UiMenuTokens &&
      surfaceOpacity == other.surfaceOpacity &&
      borderOpacity == other.borderOpacity &&
      borderWidth == other.borderWidth &&
      borderColor == other.borderColor &&
      backdropBlurSigma == other.backdropBlurSigma &&
      parentScale == other.parentScale &&
      scrimOpacity == other.scrimOpacity &&
      maxHeight == other.maxHeight &&
      iconSize == other.iconSize &&
      pressExpansion == other.pressExpansion &&
      springStrength == other.springStrength &&
      travelArc == other.travelArc &&
      rowPaddingVertical == other.rowPaddingVertical &&
      rowPaddingHorizontal == other.rowPaddingHorizontal &&
      rowMinHeight == other.rowMinHeight &&
      closeDuration == other.closeDuration &&
      submenuDwellDuration == other.submenuDwellDuration;
  @override
  int get hashCode => Object.hash(
    surfaceOpacity,
    borderOpacity,
    borderWidth,
    borderColor,
    backdropBlurSigma,
    parentScale,
    scrimOpacity,
    maxHeight,
    iconSize,
    pressExpansion,
    springStrength,
    travelArc,
    rowPaddingVertical,
    rowPaddingHorizontal,
    rowMinHeight,
    closeDuration,
    submenuDwellDuration,
  );
}
