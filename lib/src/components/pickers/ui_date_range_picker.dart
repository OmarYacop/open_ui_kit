import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_date_picker.dart';
import 'ui_picker_models.dart';

/// Two-step date range picker.
///
/// The user first taps a start date, then taps an end date. Taps on
/// earlier days after a range is set reset to a fresh start.
class UiDateRangePicker extends StatefulWidget {
  const UiDateRangePicker({
    super.key,
    this.value,
    this.min,
    this.max,
    this.disabled,
    this.onChanged,
  });

  final UiDateRange? value;
  final DateTime? min;
  final DateTime? max;
  final UiDatePredicate? disabled;
  final ValueChanged<UiDateRange>? onChanged;

  @override
  State<UiDateRangePicker> createState() => _UiDateRangePickerState();
}

class _UiDateRangePickerState extends State<UiDateRangePicker> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.value?.start;
    _end = widget.value?.end;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _onTap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else {
        final a = _dateOnly(_start!);
        final b = _dateOnly(day);
        if (b.isBefore(a)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
        widget.onChanged?.call(UiDateRange(start: _start!, end: _end!));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    // We reuse UiDatePicker for chrome; selection logic sits here by
    // re-routing the picker's `onChanged` into our two-step flow and
    // feeding back whichever bound highlights through `value`.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiDatePicker(
          value: _end ?? _start,
          rangeStart: _start,
          rangeEnd: _end,
          daySemanticsPrefix: _start == null
              ? 'Start date'
              : _end == null
                  ? 'End date'
                  : 'Date range',
          min: widget.min,
          max: widget.max,
          disabled: widget.disabled,
          onChanged: _onTap,
        ),
        SizedBox(height: tokens.spacing.x2),
        UiText(
          _rangeLabel(),
          variant: UiTextVariant.caption,
          tone: UiTextTone.muted,
        ),
      ],
    );
  }

  String _rangeLabel() {
    if (_start == null) return 'Pick a start date.';
    if (_end == null) return 'Pick an end date.';
    return '${_format(_start!)} – ${_format(_end!)}';
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
