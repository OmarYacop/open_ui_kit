import 'package:flutter/widgets.dart';

typedef UiFormattedTextStyleBuilder = TextStyle Function(
  BuildContext context,
  TextStyle baseStyle,
);

/// A delimiter pair and the visual treatment of the text it encloses.
class UiFormattedTextRule {
  const UiFormattedTextRule({
    required this.id,
    required this.open,
    String? close,
    required this.styleBuilder,
    this.semanticLabel,
  }) : close = close ?? open;

  final String id;
  final String open;
  final String close;
  final UiFormattedTextStyleBuilder styleBuilder;
  final String? semanticLabel;

  static List<UiFormattedTextRule> defaults() => [
    UiFormattedTextRule(
      id: 'bold',
      open: '**',
      semanticLabel: 'bold',
      styleBuilder: (_, style) => style.copyWith(fontWeight: FontWeight.w700),
    ),
    UiFormattedTextRule(
      id: 'italic',
      open: '_',
      semanticLabel: 'italic',
      styleBuilder: (_, style) => style.copyWith(fontStyle: FontStyle.italic),
    ),
    UiFormattedTextRule(
      id: 'strikethrough',
      open: '~~',
      semanticLabel: 'strikethrough',
      styleBuilder: (_, style) =>
          style.copyWith(decoration: TextDecoration.lineThrough),
    ),
    UiFormattedTextRule(
      id: 'code',
      open: '`',
      semanticLabel: 'code',
      styleBuilder: (_, style) => style.copyWith(fontFamily: 'monospace'),
    ),
    UiFormattedTextRule(
      id: 'underline',
      open: '__',
      semanticLabel: 'underline',
      styleBuilder: (_, style) =>
          style.copyWith(decoration: TextDecoration.underline),
    ),
    UiFormattedTextRule(
      id: 'highlight',
      open: '==',
      semanticLabel: 'highlight',
      styleBuilder: (context, style) {
        final color = style.color ?? DefaultTextStyle.of(context).style.color;
        return style.copyWith(backgroundColor: color?.withValues(alpha: .12));
      },
    ),
  ];
}

class UiFormattedTextMatch {
  const UiFormattedTextMatch({
    required this.rule,
    required this.sourceStart,
    required this.contentStart,
    required this.contentEnd,
    required this.sourceEnd,
  });

  final UiFormattedTextRule rule;
  final int sourceStart;
  final int contentStart;
  final int contentEnd;
  final int sourceEnd;
}

/// Stateless parser shared by display text and composing controllers.
class UiFormattedTextParser {
  const UiFormattedTextParser(this.rules);

  final List<UiFormattedTextRule> rules;

  List<UiFormattedTextMatch> parse(String source) {
    final matches = <UiFormattedTextMatch>[];
    final ordered = [...rules]
      ..sort((a, b) => b.open.length.compareTo(a.open.length));
    var cursor = 0;
    while (cursor < source.length) {
      UiFormattedTextRule? found;
      for (final rule in ordered) {
        if (source.startsWith(rule.open, cursor) &&
            !_isEscaped(source, cursor)) {
          found = rule;
          break;
        }
      }
      if (found == null) {
        cursor++;
        continue;
      }
      final contentStart = cursor + found.open.length;
      final close = _findClose(source, found, contentStart);
      if (close < 0 || close == contentStart) {
        cursor += found.open.length;
        continue;
      }
      matches.add(
        UiFormattedTextMatch(
          rule: found,
          sourceStart: cursor,
          contentStart: contentStart,
          contentEnd: close,
          sourceEnd: close + found.close.length,
        ),
      );
      cursor = close + found.close.length;
    }
    return matches;
  }

  int _findClose(String source, UiFormattedTextRule rule, int start) {
    var cursor = start;
    while (cursor <= source.length - rule.close.length) {
      if (source.startsWith(rule.close, cursor) &&
          !_isEscaped(source, cursor)) {
        return cursor;
      }
      cursor++;
    }
    return -1;
  }

  bool _isEscaped(String source, int index) {
    var slashes = 0;
    for (
      var cursor = index - 1;
      cursor >= 0 && source.codeUnitAt(cursor) == 92;
      cursor--
    ) {
      slashes++;
    }
    return slashes.isOdd;
  }
}
