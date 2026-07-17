import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Corner radius tokens.
@immutable
class UiRadiusTokens {
  const UiRadiusTokens({
    this.none = Radius.zero,
    this.sm = const Radius.circular(8),
    this.md = const Radius.circular(10),
    this.lg = const Radius.circular(12),
    this.xl = const Radius.circular(18),
    this.pill = const Radius.circular(999),
  });

  final Radius none;
  final Radius sm;
  final Radius md;
  final Radius lg;
  final Radius xl;
  final Radius pill;

  BorderRadius get noneAll => BorderRadius.all(none);
  BorderRadius get smAll => BorderRadius.all(sm);
  BorderRadius get mdAll => BorderRadius.all(md);
  BorderRadius get lgAll => BorderRadius.all(lg);
  BorderRadius get xlAll => BorderRadius.all(xl);
  BorderRadius get pillAll => BorderRadius.all(pill);

  static const UiRadiusTokens standard = UiRadiusTokens();

  UiRadiusTokens copyWith({
    Radius? none,
    Radius? sm,
    Radius? md,
    Radius? lg,
    Radius? xl,
    Radius? pill,
  }) {
    return UiRadiusTokens(
      none: none ?? this.none,
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
      none: l(a.none, b.none),
      sm: l(a.sm, b.sm),
      md: l(a.md, b.md),
      lg: l(a.lg, b.lg),
      xl: l(a.xl, b.xl),
      pill: l(a.pill, b.pill),
    );
  }
}
