import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Corner geometry, independent of the radius magnitude.
enum UiCornerStyle {
  /// Continuous on iOS/macOS; circular rounded on other platforms.
  platform,
  circular,
  continuous,
}

/// Corner radius and platform shape tokens.
@immutable
class UiRadiusTokens {
  const UiRadiusTokens({
    this.cornerStyle = UiCornerStyle.platform,
    this.none = Radius.zero,
    this.xs = const Radius.circular(6),
    this.sm = const Radius.circular(10),
    this.md = const Radius.circular(12),
    this.lg = const Radius.circular(16),
    this.xl = const Radius.circular(24),
    this.pill = const Radius.circular(999),
  });

  final UiCornerStyle cornerStyle;

  /// Flutter folds native platform selection in non-debug builds. Web resolves
  /// the browser platform; no platform channel or asynchronous device query.
  UiCornerStyle get resolvedCornerStyle => cornerStyle != UiCornerStyle.platform
      ? cornerStyle
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS ||
          TargetPlatform.macOS => UiCornerStyle.continuous,
          _ => UiCornerStyle.circular,
        };

  bool get isContinuous => resolvedCornerStyle == UiCornerStyle.continuous;

  OutlinedBorder shape({
    BorderRadiusGeometry? borderRadius,
    BorderSide side = BorderSide.none,
  }) => isContinuous
      ? RoundedSuperellipseBorder(borderRadius: borderRadius, side: side)
      : RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.zero,
          side: side,
        );

  /// Shared outline/fill selection. Nonuniform edge borders keep BoxDecoration
  /// semantics because a rounded-superellipse border has one uniform side.
  Decoration decoration({
    Color? color,
    BorderRadiusGeometry? borderRadius,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
  }) {
    if (isContinuous && (border == null || border.isUniform)) {
      return ShapeDecoration(
        color: color,
        shadows: boxShadow,
        shape: shape(
          borderRadius: borderRadius,
          side: border?.top ?? BorderSide.none,
        ),
      );
    }
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );
  }

  final Radius none;
  final Radius xs;
  final Radius sm;
  final Radius md;
  final Radius lg;
  final Radius xl;
  final Radius pill;

  BorderRadius get noneAll => BorderRadius.all(none);
  BorderRadius get xsAll => BorderRadius.all(xs);
  BorderRadius get smAll => BorderRadius.all(sm);
  BorderRadius get mdAll => BorderRadius.all(md);
  BorderRadius get lgAll => BorderRadius.all(lg);
  BorderRadius get xlAll => BorderRadius.all(xl);
  BorderRadius get pillAll => BorderRadius.all(pill);

  BorderRadiusDirectional get xsStart =>
      BorderRadiusDirectional.horizontal(start: xs);
  BorderRadiusDirectional get smStart =>
      BorderRadiusDirectional.horizontal(start: sm);
  BorderRadiusDirectional get mdStart =>
      BorderRadiusDirectional.horizontal(start: md);
  BorderRadiusDirectional get lgStart =>
      BorderRadiusDirectional.horizontal(start: lg);
  BorderRadiusDirectional get xlStart =>
      BorderRadiusDirectional.horizontal(start: xl);

  BorderRadiusDirectional get xsEnd =>
      BorderRadiusDirectional.horizontal(end: xs);
  BorderRadiusDirectional get smEnd =>
      BorderRadiusDirectional.horizontal(end: sm);
  BorderRadiusDirectional get mdEnd =>
      BorderRadiusDirectional.horizontal(end: md);
  BorderRadiusDirectional get lgEnd =>
      BorderRadiusDirectional.horizontal(end: lg);
  BorderRadiusDirectional get xlEnd =>
      BorderRadiusDirectional.horizontal(end: xl);

  BorderRadius get xsTop => BorderRadius.vertical(top: xs);
  BorderRadius get smTop => BorderRadius.vertical(top: sm);
  BorderRadius get mdTop => BorderRadius.vertical(top: md);
  BorderRadius get lgTop => BorderRadius.vertical(top: lg);
  BorderRadius get xlTop => BorderRadius.vertical(top: xl);

  BorderRadius get xsBottom => BorderRadius.vertical(bottom: xs);
  BorderRadius get smBottom => BorderRadius.vertical(bottom: sm);
  BorderRadius get mdBottom => BorderRadius.vertical(bottom: md);
  BorderRadius get lgBottom => BorderRadius.vertical(bottom: lg);
  BorderRadius get xlBottom => BorderRadius.vertical(bottom: xl);

  static const UiRadiusTokens standard = UiRadiusTokens();

  UiRadiusTokens copyWith({
    UiCornerStyle? cornerStyle,
    Radius? none,
    Radius? xs,
    Radius? sm,
    Radius? md,
    Radius? lg,
    Radius? xl,
    Radius? pill,
  }) {
    return UiRadiusTokens(
      cornerStyle: cornerStyle ?? this.cornerStyle,
      none: none ?? this.none,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  static UiRadiusTokens lerp(UiRadiusTokens a, UiRadiusTokens b, double t) {
    Radius l(Radius x, Radius y) => Radius.lerp(x, y, t)!;
    return UiRadiusTokens(
      cornerStyle: t < .5 ? a.cornerStyle : b.cornerStyle,
      none: l(a.none, b.none),
      sm: l(a.sm, b.sm),
      xs: l(a.xs, b.xs),
      md: l(a.md, b.md),
      lg: l(a.lg, b.lg),
      xl: l(a.xl, b.xl),
      pill: l(a.pill, b.pill),
    );
  }
}
