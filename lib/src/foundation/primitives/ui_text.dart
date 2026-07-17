import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';
import '../tokens/ui_typography_tokens.dart';

/// Semantic text roles mapped to [UiTypographyTokens].
enum UiTextVariant {
  displayLg,
  displayMd,
  heading,
  subheading,
  bodyLg,
  body,
  bodySm,
  label,
  caption,
  mono,
}

/// Intent drives the resolved color: neutral by default, muted for hints,
/// inverse for on-dark surfaces, danger for errors.
enum UiTextTone { primary, muted, inverse, danger, success, warning }

/// Typography primitive.
///
/// Resolves a [TextStyle] from the ambient [UiThemeTokens] based on
/// [variant] and [tone]. All styling decisions flow through the theme —
/// avoid reaching for [Text] directly inside components.
class UiText extends StatelessWidget {
  const UiText(
    this.data, {
    super.key,
    this.variant = UiTextVariant.body,
    this.tone = UiTextTone.primary,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.style,
  });

  final String data;
  final UiTextVariant variant;
  final UiTextTone tone;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// Optional overrides merged on top of the resolved style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final base = _resolveVariant(tokens.typography, variant);
    final color = _resolveTone(context, tone);
    final merged = base.copyWith(color: color).merge(style);
    return Text(
      data,
      style: merged,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }

  static TextStyle _resolveVariant(UiTypographyTokens t, UiTextVariant v) {
    switch (v) {
      case UiTextVariant.displayLg:
        return t.displayLg;
      case UiTextVariant.displayMd:
        return t.displayMd;
      case UiTextVariant.heading:
        return t.heading;
      case UiTextVariant.subheading:
        return t.subheading;
      case UiTextVariant.bodyLg:
        return t.bodyLg;
      case UiTextVariant.body:
        return t.body;
      case UiTextVariant.bodySm:
        return t.bodySm;
      case UiTextVariant.label:
        return t.label;
      case UiTextVariant.caption:
        return t.caption;
      case UiTextVariant.mono:
        return t.mono;
    }
  }

  static Color _resolveTone(BuildContext context, UiTextTone tone) {
    final c = UiThemeTokens.of(context).colors;
    switch (tone) {
      case UiTextTone.primary:
        return c.textPrimary;
      case UiTextTone.muted:
        return c.textMuted;
      case UiTextTone.inverse:
        return c.textInverse;
      case UiTextTone.danger:
        return c.danger;
      case UiTextTone.success:
        return c.success;
      case UiTextTone.warning:
        return c.warning;
    }
  }
}
