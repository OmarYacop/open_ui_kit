import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Elevation shadows tuned for shadcn-style surfaces.
@immutable
class UiShadowTokens {
  const UiShadowTokens({
    this.none = const <BoxShadow>[],
    this.sm = const <BoxShadow>[
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
    this.md = const <BoxShadow>[
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 6,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 2,
        offset: Offset(0, 2),
      ),
    ],
    this.lg = const <BoxShadow>[
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 16,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 6,
        offset: Offset(0, 4),
      ),
    ],
  });

  final List<BoxShadow> none;
  final List<BoxShadow> sm;
  final List<BoxShadow> md;
  final List<BoxShadow> lg;

  static const UiShadowTokens standard = UiShadowTokens();

  UiShadowTokens copyWith({
    List<BoxShadow>? none,
    List<BoxShadow>? sm,
    List<BoxShadow>? md,
    List<BoxShadow>? lg,
  }) {
    return UiShadowTokens(
      none: none ?? this.none,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
    );
  }

  static UiShadowTokens lerp(UiShadowTokens a, UiShadowTokens b, double t) {
    List<BoxShadow> l(List<BoxShadow> x, List<BoxShadow> y) =>
        BoxShadow.lerpList(x, y, t) ?? const <BoxShadow>[];
    return UiShadowTokens(
      none: l(a.none, b.none),
      sm: l(a.sm, b.sm),
      md: l(a.md, b.md),
      lg: l(a.lg, b.lg),
    );
  }
}
