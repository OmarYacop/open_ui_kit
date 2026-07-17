import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Semantic typography scale.
@immutable
class UiTypographyTokens {
  const UiTypographyTokens({
    required this.displayLg,
    required this.displayMd,
    required this.heading,
    required this.subheading,
    required this.bodyLg,
    required this.body,
    required this.bodySm,
    required this.label,
    required this.caption,
    required this.mono,
  });

  final TextStyle displayLg;
  final TextStyle displayMd;
  final TextStyle heading;
  final TextStyle subheading;
  final TextStyle bodyLg;
  final TextStyle body;
  final TextStyle bodySm;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle mono;

  static const _base = TextStyle(
    inherit: false,
    fontFamily: null,
    package: null,
    decoration: TextDecoration.none,
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static final UiTypographyTokens standard = UiTypographyTokens(
    displayLg: _base.copyWith(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    displayMd: _base.copyWith(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    heading: _base.copyWith(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    subheading: _base.copyWith(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLg: _base.copyWith(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    body: _base.copyWith(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodySm: _base.copyWith(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    label: _base.copyWith(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    caption: _base.copyWith(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
    ),
    mono: _base.copyWith(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w400,
      fontFamilyFallback: const ['Menlo', 'Courier', 'monospace'],
    ),
  );

  UiTypographyTokens copyWith({
    TextStyle? displayLg,
    TextStyle? displayMd,
    TextStyle? heading,
    TextStyle? subheading,
    TextStyle? bodyLg,
    TextStyle? body,
    TextStyle? bodySm,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? mono,
  }) {
    return UiTypographyTokens(
      displayLg: displayLg ?? this.displayLg,
      displayMd: displayMd ?? this.displayMd,
      heading: heading ?? this.heading,
      subheading: subheading ?? this.subheading,
      bodyLg: bodyLg ?? this.bodyLg,
      body: body ?? this.body,
      bodySm: bodySm ?? this.bodySm,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      mono: mono ?? this.mono,
    );
  }

  static UiTypographyTokens lerp(
    UiTypographyTokens a,
    UiTypographyTokens b,
    double t,
  ) {
    TextStyle l(TextStyle x, TextStyle y) => TextStyle.lerp(x, y, t)!;
    return UiTypographyTokens(
      displayLg: l(a.displayLg, b.displayLg),
      displayMd: l(a.displayMd, b.displayMd),
      heading: l(a.heading, b.heading),
      subheading: l(a.subheading, b.subheading),
      bodyLg: l(a.bodyLg, b.bodyLg),
      body: l(a.body, b.body),
      bodySm: l(a.bodySm, b.bodySm),
      label: l(a.label, b.label),
      caption: l(a.caption, b.caption),
      mono: l(a.mono, b.mono),
    );
  }
}
