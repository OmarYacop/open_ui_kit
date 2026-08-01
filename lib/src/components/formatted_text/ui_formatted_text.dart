import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_formatted_text_rule.dart';

/// Renders lightweight, operator-based rich text while preserving plain source.
class UiFormattedText extends StatelessWidget {
  const UiFormattedText(
    this.data, {
    super.key,
    this.rules,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
    this.selectable = false,
  });

  final String data;
  final List<UiFormattedTextRule>? rules;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final base = tokens.typography.body
        .copyWith(color: tokens.colors.textPrimary)
        .merge(style);
    final span = buildUiFormattedTextSpan(
      context,
      data,
      rules: rules ?? UiFormattedTextRule.defaults(),
      baseStyle: base,
    );
    if (selectable) {
      return SelectableRegion(
        selectionControls: emptyTextSelectionControls,
        child: RichText(
          text: span,
          textAlign: textAlign ?? TextAlign.start,
          textDirection: textDirection,
          maxLines: maxLines,
        ),
      );
    }
    return RichText(
      text: span,
      textAlign: textAlign ?? TextAlign.start,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

TextSpan buildUiFormattedTextSpan(
  BuildContext context,
  String source, {
  required List<UiFormattedTextRule> rules,
  required TextStyle baseStyle,
  bool showOperators = false,
  TextStyle? operatorStyle,
}) {
  return TextSpan(
    style: baseStyle,
    children: _buildChildren(
      context,
      source,
      rules: rules,
      baseStyle: baseStyle,
      showOperators: showOperators,
      operatorStyle: operatorStyle,
    ),
  );
}

List<InlineSpan> _buildChildren(
  BuildContext context,
  String source, {
  required List<UiFormattedTextRule> rules,
  required TextStyle baseStyle,
  required bool showOperators,
  required TextStyle? operatorStyle,
}) {
  final matches = UiFormattedTextParser(rules).parse(source);
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.sourceStart > cursor) {
      children.add(TextSpan(text: source.substring(cursor, match.sourceStart)));
    }
    if (showOperators) {
      children.add(
        TextSpan(
          text: source.substring(match.sourceStart, match.contentStart),
          style: operatorStyle,
        ),
      );
    }
    final content = source.substring(match.contentStart, match.contentEnd);
    final formattedStyle = match.rule.styleBuilder(context, baseStyle);
    children.add(
      TextSpan(
        text: '',
        style: formattedStyle,
        semanticsLabel: match.rule.semanticLabel == null
            ? null
            : '${match.rule.semanticLabel}, $content',
        children: _buildChildren(
          context,
          content,
          rules: rules.where((rule) => rule != match.rule).toList(),
          baseStyle: formattedStyle,
          showOperators: showOperators,
          operatorStyle: operatorStyle,
        ),
      ),
    );
    if (showOperators) {
      children.add(
        TextSpan(
          text: source.substring(match.contentEnd, match.sourceEnd),
          style: operatorStyle,
        ),
      );
    }
    cursor = match.sourceEnd;
  }
  if (cursor < source.length) {
    children.add(TextSpan(text: source.substring(cursor)));
  }
  return children;
}
