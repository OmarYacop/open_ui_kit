import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_date_picker.dart';
import 'ui_date_range_picker.dart';
import 'ui_picker_models.dart';
import 'ui_time_range_picker.dart';

/// Composite picker for a date range *and* a time range. Emits a
/// [UiDateTimeRange] whose start uses the range's first date + start
/// time, and whose end uses the last date + end time.
class UiDateTimeRangePicker extends StatefulWidget {
  const UiDateTimeRangePicker({
    super.key,
    this.value,
    this.min,
    this.max,
    this.disabled,
    this.onChanged,
    this.minuteStep = 5,
  });

  final UiDateTimeRange? value;
  final DateTime? min;
  final DateTime? max;
  final UiDatePredicate? disabled;
  final ValueChanged<UiDateTimeRange>? onChanged;
  final int minuteStep;

  @override
  State<UiDateTimeRangePicker> createState() => _UiDateTimeRangePickerState();
}

class _UiDateTimeRangePickerState extends State<UiDateTimeRangePicker> {
  UiDateRange? _dates;
  UiTimeRange _times = const UiTimeRange(
    start: UiTimeValue(hour: 9, minute: 0),
    end: UiTimeValue(hour: 17, minute: 0),
  );

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    if (v != null) {
      _dates = UiDateRange(start: v.start, end: v.end);
      _times = UiTimeRange(
        start: UiTimeValue(hour: v.start.hour, minute: v.start.minute),
        end: UiTimeValue(hour: v.end.hour, minute: v.end.minute),
      );
    }
  }

  void _emit() {
    final d = _dates;
    if (d == null) return;
    final start = DateTime(d.start.year, d.start.month, d.start.day,
        _times.start.hour, _times.start.minute);
    final end = DateTime(
        d.end.year, d.end.month, d.end.day, _times.end.hour, _times.end.minute);
    widget.onChanged?.call(UiDateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          label: 'Date range',
          child: UiDateRangePicker(
            value: _dates,
            min: widget.min,
            max: widget.max,
            disabled: widget.disabled,
            onChanged: (r) {
              setState(() => _dates = r);
              _emit();
            },
          ),
        ),
        SizedBox(height: tokens.spacing.x3),
        const UiDivider(),
        SizedBox(height: tokens.spacing.x3),
        Semantics(
          header: true,
          child: UiText('Time window', variant: UiTextVariant.label),
        ),
        SizedBox(height: tokens.spacing.x1),
        UiTimeRangePicker(
          value: _times,
          minuteStep: widget.minuteStep,
          onChanged: (r) {
            setState(() => _times = r);
            _emit();
          },
        ),
      ],
    );
  }
}
