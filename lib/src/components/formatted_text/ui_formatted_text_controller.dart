import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_formatted_text.dart';
import 'ui_formatted_text_rule.dart';

/// A controller that previews formatting without hiding its source operators.
class UiFormattedTextController extends TextEditingController {
  UiFormattedTextController({super.text, List<UiFormattedTextRule>? rules})
    : rules = rules ?? UiFormattedTextRule.defaults();

  final List<UiFormattedTextRule> rules;

  UiFormattedTextRule? rule(String id) {
    for (final candidate in rules) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }

  /// Wraps or unwraps a selection, or inserts a pair at the caret.
  bool toggle(String id) {
    final format = rule(id);
    if (format == null) return false;
    final current = value;
    final selection = current.selection;
    final start = selection.isValid ? selection.start : current.text.length;
    final end = selection.isValid ? selection.end : current.text.length;
    final safeStart = start.clamp(0, current.text.length);
    final safeEnd = end.clamp(safeStart, current.text.length);
    final selected = current.text.substring(safeStart, safeEnd);
    final wrappedStart = safeStart - format.open.length;
    final wrappedEnd = safeEnd + format.close.length;
    final isWrapped =
        wrappedStart >= 0 &&
        wrappedEnd <= current.text.length &&
        current.text.substring(wrappedStart, safeStart) == format.open &&
        current.text.substring(safeEnd, wrappedEnd) == format.close;

    if (isWrapped) {
      final next = current.text.replaceRange(
        wrappedStart,
        wrappedEnd,
        selected,
      );
      value = current.copyWith(
        text: next,
        selection: TextSelection(
          baseOffset: wrappedStart,
          extentOffset: wrappedStart + selected.length,
        ),
        composing: TextRange.empty,
      );
      return true;
    }

    final replacement = '${format.open}$selected${format.close}';
    final next = current.text.replaceRange(safeStart, safeEnd, replacement);
    final contentStart = safeStart + format.open.length;
    value = current.copyWith(
      text: next,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: contentStart)
          : TextSelection(
              baseOffset: contentStart,
              extentOffset: contentStart + selected.length,
            ),
      composing: TextRange.empty,
    );
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing && !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
    }
    final tokens = UiThemeTokens.of(context);
    final base = style ?? DefaultTextStyle.of(context).style;
    return buildUiFormattedTextSpan(
      context,
      text,
      rules: rules,
      baseStyle: base,
      showOperators: true,
      operatorStyle: base.copyWith(
        color: tokens.colors.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
