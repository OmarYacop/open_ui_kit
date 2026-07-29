import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Motion tokens: duration and easing curves.
@immutable
class UiMotionTokens {
  const UiMotionTokens({
    this.instant = Duration.zero,
    this.faster = const Duration(milliseconds: 20),
    this.fast = const Duration(milliseconds: 120),
    this.standard = const Duration(milliseconds: 200),
    this.slow = const Duration(milliseconds: 320),
    this.xslow = const Duration(milliseconds: 500),
    this.standardCurve = Curves.easeOutCubic,
    this.emphasizedCurve = Curves.easeOutBack,
    this.linearCurve = Curves.linear,
  });

  final Duration instant;
  final Duration faster;
  final Duration fast;
  final Duration standard;
  final Duration slow;
  final Duration xslow;
  final Curve standardCurve;
  final Curve emphasizedCurve;
  final Curve linearCurve;

  static const UiMotionTokens defaults = UiMotionTokens();
  static const UiMotionTokens reduced = UiMotionTokens(
    faster: Duration.zero,
    fast: Duration.zero,
    standard: Duration.zero,
    slow: Duration.zero,
    xslow: Duration.zero,
    standardCurve: Curves.linear,
    emphasizedCurve: Curves.linear,
  );

  UiMotionTokens copyWith({
    Duration? instant,
    Duration? faster,
    Duration? fast,
    Duration? standard,
    Duration? slow,
    Duration? xslow,
    Curve? standardCurve,
    Curve? emphasizedCurve,
    Curve? linearCurve,
  }) {
    return UiMotionTokens(
      instant: instant ?? this.instant,
      faster: faster ?? this.faster,
      fast: fast ?? this.fast,
      standard: standard ?? this.standard,
      slow: slow ?? this.slow,
      xslow: xslow ?? this.xslow,
      standardCurve: standardCurve ?? this.standardCurve,
      emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
      linearCurve: linearCurve ?? this.linearCurve,
    );
  }

  UiMotionTokens reduce() {
    return copyWith(
      fast: instant,
      faster: instant,
      standard: instant,
      slow: instant,
      xslow: instant,
      standardCurve: linearCurve,
      emphasizedCurve: linearCurve,
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
      faster: l(a.faster, b.faster),
      fast: l(a.fast, b.fast),
      standard: l(a.standard, b.standard),
      slow: l(a.slow, b.slow),
      xslow: l(a.xslow, b.xslow),
      standardCurve: t < 0.5 ? a.standardCurve : b.standardCurve,
      emphasizedCurve: t < 0.5 ? a.emphasizedCurve : b.emphasizedCurve,
      linearCurve: t < 0.5 ? a.linearCurve : b.linearCurve,
    );
  }
}
