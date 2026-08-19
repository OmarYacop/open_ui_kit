import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Semantic typography scale.
@immutable
class UiTypographyTokens {
  const UiTypographyTokens({
    required this.displayXl,
    required this.displayLg,
    required this.displayMd,
    required this.title,
    required this.heading,
    required this.subheading,
    required this.bodyLg,
    required this.body,
    required this.bodySm,
    required this.label,
    required this.labelSm,
    required this.caption,
    required this.micro,
    required this.mono,
  });

  final TextStyle displayXl;
  final TextStyle displayLg;
  final TextStyle displayMd;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle subheading;
  final TextStyle bodyLg;
  final TextStyle body;
  final TextStyle bodySm;
  final TextStyle label;
  final TextStyle labelSm;
  final TextStyle caption;
  final TextStyle micro;
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
    displayXl: _base.copyWith(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    displayLg: _base.copyWith(
      fontSize: 32,
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
    title: _base.copyWith(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    heading: _base.copyWith(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    subheading: _base.copyWith(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLg: _base.copyWith(
      fontSize: 17,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    body: _base.copyWith(
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w400,
    ),
    bodySm: _base.copyWith(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
    ),
    label: _base.copyWith(
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    labelSm: _base.copyWith(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    caption: _base.copyWith(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
    ),
    micro: _base.copyWith(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    mono: _base.copyWith(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      fontFamilyFallback: const ['Menlo', 'Courier', 'monospace'],
    ),
  );

  UiTypographyTokens copyWith({
    TextStyle? displayXl,
    TextStyle? displayLg,
    TextStyle? displayMd,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? subheading,
    TextStyle? bodyLg,
    TextStyle? body,
    TextStyle? bodySm,
    TextStyle? label,
    TextStyle? labelSm,
    TextStyle? caption,
    TextStyle? micro,
    TextStyle? mono,
  }) {
    return UiTypographyTokens(
      displayXl: displayXl ?? this.displayXl,
      displayLg: displayLg ?? this.displayLg,
      displayMd: displayMd ?? this.displayMd,
      title: title ?? this.title,
      heading: heading ?? this.heading,
      subheading: subheading ?? this.subheading,
      bodyLg: bodyLg ?? this.bodyLg,
      body: body ?? this.body,
      bodySm: bodySm ?? this.bodySm,
      label: label ?? this.label,
      labelSm: labelSm ?? this.labelSm,
      caption: caption ?? this.caption,
      micro: micro ?? this.micro,
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
      displayXl: l(a.displayXl, b.displayXl),
      displayLg: l(a.displayLg, b.displayLg),
      displayMd: l(a.displayMd, b.displayMd),
      title: l(a.title, b.title),
      heading: l(a.heading, b.heading),
      subheading: l(a.subheading, b.subheading),
      bodyLg: l(a.bodyLg, b.bodyLg),
      body: l(a.body, b.body),
      bodySm: l(a.bodySm, b.bodySm),
      label: l(a.label, b.label),
      labelSm: l(a.labelSm, b.labelSm),
      caption: l(a.caption, b.caption),
      micro: l(a.micro, b.micro),
      mono: l(a.mono, b.mono),
    );
  }
}
