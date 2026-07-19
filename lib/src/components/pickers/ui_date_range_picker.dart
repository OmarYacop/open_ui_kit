import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
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
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _start = widget.value?.start;
    _end = widget.value?.end;
    final seed = _start ?? DateTime.now();
    _visibleMonth = DateTime(seed.year, seed.month);
  }

  @override
  void didUpdateWidget(covariant UiDateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    _start = widget.value?.start;
    _end = widget.value?.end;
    final seed = _start ?? DateTime.now();
    _visibleMonth = DateTime(seed.year, seed.month);
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

  void _setVisibleMonth(DateTime month) {
    setState(() => _visibleMonth = DateTime(month.year, month.month));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final monthGap = tokens.spacing.x4;
    const monthWidth = 224.0;
    final twoMonthWidth = monthWidth * 2 + monthGap + tokens.spacing.x3 * 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleMonth =
            constraints.hasBoundedWidth && constraints.maxWidth < twoMonthWidth;
        final surface = UiBox(
          background: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(8),
          padding: EdgeInsets.all(tokens.spacing.x3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiDatePicker(
                value: _end ?? _start,
                visibleMonth: _visibleMonth,
                onVisibleMonthChanged: _setVisibleMonth,
                rangeStart: _start,
                rangeEnd: _end,
                daySemanticsPrefix: _daySemanticsPrefix(),
                min: widget.min,
                max: widget.max,
                disabled: widget.disabled,
                onChanged: _onTap,
                showChrome: false,
                showNextMonthButton: useSingleMonth,
                enableHeaderModeSelection: false,
              ),
              if (!useSingleMonth) ...[
                SizedBox(width: monthGap),
                UiDatePicker(
                  value: _end ?? _start,
                  visibleMonth: DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  ),
                  onVisibleMonthChanged: (month) => _setVisibleMonth(
                    DateTime(month.year, month.month - 1),
                  ),
                  rangeStart: _start,
                  rangeEnd: _end,
                  daySemanticsPrefix: _daySemanticsPrefix(),
                  min: widget.min,
                  max: widget.max,
                  disabled: widget.disabled,
                  onChanged: _onTap,
                  showChrome: false,
                  showPreviousMonthButton: false,
                  enableHeaderModeSelection: false,
                ),
              ],
            ],
          ),
        );

        return surface;
      },
    );
  }

  String _daySemanticsPrefix() {
    if (_start == null) return 'Start date';
    if (_end == null) return 'End date';
    return 'Date range';
  }
}
