import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_picker_models.dart';
import 'ui_time_picker.dart';

/// Pair of [UiTimePicker]s for a start/end time range.
class UiTimeRangePicker extends StatefulWidget {
  const UiTimeRangePicker({
    super.key,
    this.value,
    this.onChanged,
    this.minuteStep = 5,
  });

  final UiTimeRange? value;
  final ValueChanged<UiTimeRange>? onChanged;
  final int minuteStep;

  @override
  State<UiTimeRangePicker> createState() => _UiTimeRangePickerState();
}

class _UiTimeRangePickerState extends State<UiTimeRangePicker> {
  late UiTimeValue _start;
  late UiTimeValue _end;

  @override
  void initState() {
    super.initState();
    _start = widget.value?.start ?? const UiTimeValue(hour: 9, minute: 0);
    _end = widget.value?.end ?? const UiTimeValue(hour: 17, minute: 0);
  }

  void _emit() {
    widget.onChanged?.call(UiTimeRange(start: _start, end: _end));
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
          child: UiText('Start', variant: UiTextVariant.label),
        ),
        SizedBox(height: tokens.spacing.x1),
        UiTimePicker(
          value: _start,
          minuteStep: widget.minuteStep,
          semanticsPrefix: 'Start time',
          onChanged: (v) {
            setState(() => _start = v);
            _emit();
          },
        ),
        SizedBox(height: tokens.spacing.x3),
        const UiDivider(),
        SizedBox(height: tokens.spacing.x3),
        Semantics(
          header: true,
          child: UiText('End', variant: UiTextVariant.label),
        ),
        SizedBox(height: tokens.spacing.x1),
        UiTimePicker(
          value: _end,
          minuteStep: widget.minuteStep,
          semanticsPrefix: 'End time',
          onChanged: (v) {
            setState(() => _end = v);
            _emit();
          },
        ),
      ],
    );
  }
}
