import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_radio.dart';

@immutable

/// One selectable item rendered by [UiRadioGroup].
///
/// Use a stable, typed [value] instead of relying on display text. This keeps
/// generated code resilient when labels are localized or copy changes.
class UiRadioGroupOption<T> {
  const UiRadioGroupOption({
    required this.value,
    required this.label,
    this.helper,
    this.enabled = true,
  });

  /// Typed identity emitted by [UiRadioGroup.onChanged].
  final T value;

  /// Visible text shown beside the radio control.
  final String label;

  /// Optional supporting text shown below this option.
  final String? helper;

  /// Whether this option can be selected.
  final bool enabled;
}

/// Controlled, accessible group of radio options.
///
/// Use [value] and [onChanged] the same way as [UiRadio], but let the group own
/// spacing, optional label/helper/error text, and per-option disabled state.
///
/// Prefer this widget over manually arranging several [UiRadio] widgets. The
/// group keeps labels, helper/error copy, disabled state, and horizontal wrapping
/// consistent across apps.
///
/// ```dart
/// UiRadioGroup<String>(
///   label: 'Billing cadence',
///   value: cadence,
///   onChanged: (value) => setState(() => cadence = value),
///   options: const [
///     UiRadioGroupOption(value: 'monthly', label: 'Monthly'),
///     UiRadioGroupOption(value: 'yearly', label: 'Yearly'),
///   ],
/// )
/// ```
class UiRadioGroup<T> extends StatelessWidget {
  const UiRadioGroup({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.axis = Axis.vertical,
    this.spacing,
    this.runSpacing,
  });

  /// Options rendered by the group.
  final List<UiRadioGroupOption<T>> options;

  /// Currently selected option value. `null` means no option is selected.
  final T? value;

  /// Called with the selected option value. `null` makes the group read-only.
  final ValueChanged<T>? onChanged;

  /// Optional group label shown above the options.
  final String? label;

  /// Optional group helper text shown below the options when there is no error.
  final String? helper;

  /// Optional validation error shown below the options.
  final String? errorText;

  /// Whether the whole group can be changed.
  final bool enabled;

  /// Option layout direction. Use [Axis.horizontal] for short option labels
  /// that should wrap across rows.
  final Axis axis;

  /// Gap between options.
  final double? spacing;

  /// Vertical gap between wrapped rows when [axis] is horizontal.
  final double? runSpacing;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final gap = spacing ?? tokens.spacing.x3;
    final wrapGap = runSpacing ?? gap;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final groupHelper = hasError ? errorText : helper;

    final children = options
        .map(
          (option) => _RadioGroupItem<T>(
            option: option,
            groupValue: value,
            enabled: _interactive && option.enabled,
            onChanged: onChanged,
          ),
        )
        .toList(growable: false);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            UiText(
              label!,
              variant: UiTextVariant.label,
              tone: _interactive ? UiTextTone.primary : UiTextTone.muted,
            ),
            SizedBox(height: tokens.spacing.x2),
          ],
          if (axis == Axis.vertical)
            _SpacedColumn(spacing: gap, children: children)
          else
            Wrap(spacing: gap, runSpacing: wrapGap, children: children),
          if (groupHelper != null && groupHelper.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.x2),
            UiText(
              groupHelper,
              variant: UiTextVariant.caption,
              tone: hasError ? UiTextTone.danger : UiTextTone.muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _RadioGroupItem<T> extends StatelessWidget {
  const _RadioGroupItem({
    required this.option,
    required this.groupValue,
    required this.enabled,
    required this.onChanged,
  });

  final UiRadioGroupOption<T> option;
  final T? groupValue;
  final bool enabled;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UiRadio<T>(
          value: option.value,
          groupValue: groupValue,
          label: option.label,
          enabled: enabled,
          onChanged: enabled ? onChanged : null,
        ),
        if (option.helper != null && option.helper!.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.x1),
          Padding(
            padding: EdgeInsetsDirectional.only(start: tokens.spacing.x6),
            child: UiText(
              option.helper!,
              variant: UiTextVariant.caption,
              tone: UiTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpacedColumn extends StatelessWidget {
  const _SpacedColumn({
    required this.spacing,
    required this.children,
  });

  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
    );
  }
}
