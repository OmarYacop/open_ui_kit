import 'package:flutter/foundation.dart';

/// Spacing scale (4pt base).
@immutable
class UiSpacingTokens {
  const UiSpacingTokens({
    this.x0 = 0,
    this.x1 = 4,
    this.x2 = 8,
    this.x3 = 12,
    this.x4 = 16,
    this.x5 = 20,
    this.x6 = 24,
    this.x8 = 32,
    this.x10 = 40,
    this.x12 = 48,
    this.x16 = 64,
  });

  final double x0;
  final double x1;
  final double x2;
  final double x3;
  final double x4;
  final double x5;
  final double x6;
  final double x8;
  final double x10;
  final double x12;
  final double x16;

  static const UiSpacingTokens standard = UiSpacingTokens();

  UiSpacingTokens copyWith({
    double? x0,
    double? x1,
    double? x2,
    double? x3,
    double? x4,
    double? x5,
    double? x6,
    double? x8,
    double? x10,
    double? x12,
    double? x16,
  }) {
    return UiSpacingTokens(
      x0: x0 ?? this.x0,
      x1: x1 ?? this.x1,
      x2: x2 ?? this.x2,
      x3: x3 ?? this.x3,
      x4: x4 ?? this.x4,
      x5: x5 ?? this.x5,
      x6: x6 ?? this.x6,
      x8: x8 ?? this.x8,
      x10: x10 ?? this.x10,
      x12: x12 ?? this.x12,
      x16: x16 ?? this.x16,
    );
  }

  static UiSpacingTokens lerp(UiSpacingTokens a, UiSpacingTokens b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return UiSpacingTokens(
      x0: l(a.x0, b.x0),
      x1: l(a.x1, b.x1),
      x2: l(a.x2, b.x2),
      x3: l(a.x3, b.x3),
      x4: l(a.x4, b.x4),
      x5: l(a.x5, b.x5),
      x6: l(a.x6, b.x6),
      x8: l(a.x8, b.x8),
      x10: l(a.x10, b.x10),
      x12: l(a.x12, b.x12),
      x16: l(a.x16, b.x16),
    );
  }
}
