import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_date_picker.dart';
import 'ui_picker_models.dart';
import 'ui_time_picker.dart';

/// Combined date + time picker. Emits a single [DateTime] on change.
class UiDateTimePicker extends StatefulWidget {
  const UiDateTimePicker({
    super.key,
    this.value,
    this.min,
    this.max,
    this.disabled,
    this.onChanged,
    this.minuteStep = 5,
  });

  final DateTime? value;
  final DateTime? min;
  final DateTime? max;
  final UiDatePredicate? disabled;
  final ValueChanged<DateTime>? onChanged;
  final int minuteStep;

  @override
  State<UiDateTimePicker> createState() => _UiDateTimePickerState();
}

class _UiDateTimePickerState extends State<UiDateTimePicker> {
  late DateTime _date;
  late UiTimeValue _time;

  @override
  void initState() {
    super.initState();
    final seed = widget.value ?? DateTime.now();
    _date = DateTime(seed.year, seed.month, seed.day);
    _time = UiTimeValue(hour: seed.hour, minute: seed.minute);
  }

  void _emit() {
    widget.onChanged?.call(DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    ));
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
          label: 'Date',
          child: UiDatePicker(
            value: _date,
            daySemanticsPrefix: 'Date',
            min: widget.min,
            max: widget.max,
            disabled: widget.disabled,
            onChanged: (d) {
              setState(() => _date = DateTime(d.year, d.month, d.day));
              _emit();
            },
          ),
        ),
        SizedBox(height: tokens.spacing.x3),
        const UiDivider(),
        SizedBox(height: tokens.spacing.x3),
        Semantics(
          header: true,
          child: UiText('Time', variant: UiTextVariant.label),
        ),
        SizedBox(height: tokens.spacing.x1),
        UiTimePicker(
          value: _time,
          minuteStep: widget.minuteStep,
          semanticsPrefix: 'Time',
          onChanged: (t) {
            setState(() => _time = t);
            _emit();
          },
        ),
      ],
    );
  }
}
