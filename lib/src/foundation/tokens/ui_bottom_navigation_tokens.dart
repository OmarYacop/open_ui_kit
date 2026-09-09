import 'package:flutter/foundation.dart';

/// Geometry and motion for the canonical expanding bottom navigation.
/// Colors, typography, radii and shadows use the shared theme palettes.
@immutable
class UiBottomNavigationTokens {
  const UiBottomNavigationTokens({
    this.compactHeight = 64.0,
    this.iconArea = 44.0,
    this.iconSize = 24.0,
    this.selectionInset = 2.0,
    this.iconTitleGap = 10.0,
    this.minRowHeight = 82.0,
    this.gridHorizontalInset = 6.0,
    this.gridBottomPadding = 12.0,
    this.editActionHeight = 56.0,
    this.checkCornerInset = 12.0,
    this.accessoryGap = 8.0,
    this.handleWidth = 32.0,
    this.handleThickness = 4.0,
    this.scrimOpacity = 0.16,
    this.wiggleAngle = 0.022,
    this.wigglePeriod = const Duration(milliseconds: 240),
    this.drawerDuration = const Duration(milliseconds: 450),
    this.reorderDuration = const Duration(milliseconds: 180),
  }) : assert(iconArea >= 44),
       assert(iconSize > 0 && iconSize <= iconArea),
       assert(compactHeight >= iconArea),
       assert(selectionInset >= 0 && selectionInset * 2 < iconArea),
       assert(iconTitleGap >= 0),
       assert(minRowHeight >= iconArea),
       assert(gridHorizontalInset >= 0 && gridBottomPadding >= 0),
       assert(editActionHeight >= 44 && checkCornerInset >= 0),
       assert(accessoryGap >= 0),
       assert(wiggleAngle >= 0),
       assert(scrimOpacity >= 0 && scrimOpacity <= 1);

  static const defaults = UiBottomNavigationTokens();
  final double compactHeight;
  final double iconArea;
  final double iconSize;
  final double selectionInset;
  final double iconTitleGap;
  final double minRowHeight;
  final double gridHorizontalInset;
  final double gridBottomPadding;
  final double editActionHeight;
  final double checkCornerInset;
  final double accessoryGap;
  final double handleWidth;
  final double handleThickness;
  final double scrimOpacity;
  final double wiggleAngle;
  final Duration wigglePeriod;
  final Duration drawerDuration;
  final Duration reorderDuration;
  UiBottomNavigationTokens copyWith({
    double? compactHeight,
    double? iconArea,
    double? iconSize,
    double? selectionInset,
    double? iconTitleGap,
    double? minRowHeight,
    double? gridHorizontalInset,
    double? gridBottomPadding,
    double? editActionHeight,
    double? checkCornerInset,
    double? accessoryGap,
    double? handleWidth,
    double? handleThickness,
    double? scrimOpacity,
    double? wiggleAngle,
    Duration? wigglePeriod,
    Duration? drawerDuration,
    Duration? reorderDuration,
  }) => UiBottomNavigationTokens(
    compactHeight: compactHeight ?? this.compactHeight,
    iconArea: iconArea ?? this.iconArea,
    iconSize: iconSize ?? this.iconSize,
    selectionInset: selectionInset ?? this.selectionInset,
    iconTitleGap: iconTitleGap ?? this.iconTitleGap,
    minRowHeight: minRowHeight ?? this.minRowHeight,
    gridHorizontalInset: gridHorizontalInset ?? this.gridHorizontalInset,
    gridBottomPadding: gridBottomPadding ?? this.gridBottomPadding,
    editActionHeight: editActionHeight ?? this.editActionHeight,
    checkCornerInset: checkCornerInset ?? this.checkCornerInset,
    accessoryGap: accessoryGap ?? this.accessoryGap,
    handleWidth: handleWidth ?? this.handleWidth,
    handleThickness: handleThickness ?? this.handleThickness,
    scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    wiggleAngle: wiggleAngle ?? this.wiggleAngle,
    wigglePeriod: wigglePeriod ?? this.wigglePeriod,
    drawerDuration: drawerDuration ?? this.drawerDuration,
    reorderDuration: reorderDuration ?? this.reorderDuration,
  );
  static UiBottomNavigationTokens lerp(
    UiBottomNavigationTokens a,
    UiBottomNavigationTokens b,
    double t,
  ) => UiBottomNavigationTokens(
    compactHeight: a.compactHeight + (b.compactHeight - a.compactHeight) * t,
    iconArea: a.iconArea + (b.iconArea - a.iconArea) * t,
    iconSize: a.iconSize + (b.iconSize - a.iconSize) * t,
    selectionInset:
        a.selectionInset + (b.selectionInset - a.selectionInset) * t,
    iconTitleGap: a.iconTitleGap + (b.iconTitleGap - a.iconTitleGap) * t,
    minRowHeight: a.minRowHeight + (b.minRowHeight - a.minRowHeight) * t,
    gridHorizontalInset:
        a.gridHorizontalInset +
        (b.gridHorizontalInset - a.gridHorizontalInset) * t,
    gridBottomPadding:
        a.gridBottomPadding + (b.gridBottomPadding - a.gridBottomPadding) * t,
    editActionHeight:
        a.editActionHeight + (b.editActionHeight - a.editActionHeight) * t,
    checkCornerInset:
        a.checkCornerInset + (b.checkCornerInset - a.checkCornerInset) * t,
    accessoryGap: a.accessoryGap + (b.accessoryGap - a.accessoryGap) * t,
    handleWidth: a.handleWidth + (b.handleWidth - a.handleWidth) * t,
    handleThickness:
        a.handleThickness + (b.handleThickness - a.handleThickness) * t,
    scrimOpacity: a.scrimOpacity + (b.scrimOpacity - a.scrimOpacity) * t,
    wiggleAngle: a.wiggleAngle + (b.wiggleAngle - a.wiggleAngle) * t,
    wigglePeriod: Duration(
      microseconds:
          (a.wigglePeriod.inMicroseconds +
                  (b.wigglePeriod.inMicroseconds -
                          a.wigglePeriod.inMicroseconds) *
                      t)
              .round(),
    ),
    drawerDuration: Duration(
      microseconds:
          (a.drawerDuration.inMicroseconds +
                  (b.drawerDuration.inMicroseconds -
                          a.drawerDuration.inMicroseconds) *
                      t)
              .round(),
    ),
    reorderDuration: Duration(
      microseconds:
          (a.reorderDuration.inMicroseconds +
                  (b.reorderDuration.inMicroseconds -
                          a.reorderDuration.inMicroseconds) *
                      t)
              .round(),
    ),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiBottomNavigationTokens &&
          compactHeight == other.compactHeight &&
          iconArea == other.iconArea &&
          iconSize == other.iconSize &&
          selectionInset == other.selectionInset &&
          iconTitleGap == other.iconTitleGap &&
          minRowHeight == other.minRowHeight &&
          gridHorizontalInset == other.gridHorizontalInset &&
          gridBottomPadding == other.gridBottomPadding &&
          editActionHeight == other.editActionHeight &&
          checkCornerInset == other.checkCornerInset &&
          accessoryGap == other.accessoryGap &&
          handleWidth == other.handleWidth &&
          handleThickness == other.handleThickness &&
          scrimOpacity == other.scrimOpacity &&
          wiggleAngle == other.wiggleAngle &&
          wigglePeriod == other.wigglePeriod &&
          drawerDuration == other.drawerDuration &&
          reorderDuration == other.reorderDuration;
  @override
  int get hashCode => Object.hashAll([
    compactHeight,
    iconArea,
    iconSize,
    selectionInset,
    iconTitleGap,
    minRowHeight,
    gridHorizontalInset,
    gridBottomPadding,
    editActionHeight,
    checkCornerInset,
    accessoryGap,
    handleWidth,
    handleThickness,
    scrimOpacity,
    wiggleAngle,
    wigglePeriod,
    drawerDuration,
    reorderDuration,
  ]);
}
