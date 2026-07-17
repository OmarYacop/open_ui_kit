import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Motion tokens: duration and easing curves.
@immutable
class UiMotionTokens {
  const UiMotionTokens({
    this.instant = Duration.zero,
    this.fast = const Duration(milliseconds: 120),
    this.standard = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 320),
    this.standardCurve = Curves.easeOutCubic,
    this.emphasizedCurve = Curves.easeOutBack,
    this.linearCurve = Curves.linear,
  });

  final Duration instant;
  final Duration fast;
  final Duration standard;
  final Duration slow;
  final Curve standardCurve;
  final Curve emphasizedCurve;
  final Curve linearCurve;

  static const UiMotionTokens defaults = UiMotionTokens();

  UiMotionTokens copyWith({
    Duration? instant,
    Duration? fast,
    Duration? standard,
    Duration? slow,
    Curve? standardCurve,
    Curve? emphasizedCurve,
    Curve? linearCurve,
  }) {
    return UiMotionTokens(
      instant: instant ?? this.instant,
      fast: fast ?? this.fast,
      standard: standard ?? this.standard,
      slow: slow ?? this.slow,
      standardCurve: standardCurve ?? this.standardCurve,
      emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
      linearCurve: linearCurve ?? this.linearCurve,
    );
  }

  static UiMotionTokens lerp(UiMotionTokens a, UiMotionTokens b, double t) {
    Duration l(Duration x, Duration y) => Duration(
          microseconds:
              (x.inMicroseconds + (y.inMicroseconds - x.inMicroseconds) * t)
                  .round(),
        );
    return UiMotionTokens(
      instant: l(a.instant, b.instant),
      fast: l(a.fast, b.fast),
      standard: l(a.standard, b.standard),
      slow: l(a.slow, b.slow),
      standardCurve: t < 0.5 ? a.standardCurve : b.standardCurve,
      emphasizedCurve: t < 0.5 ? a.emphasizedCurve : b.emphasizedCurve,
      linearCurve: t < 0.5 ? a.linearCurve : b.linearCurve,
    );
  }
}
