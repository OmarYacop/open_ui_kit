import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_picker_models.dart';

/// Simple hour/minute wheel picker (24-hour clock).
///
/// Uses two `ListWheelScrollView`s for the hour and minute columns.
/// Disabled minute/hour values are skipped by the predicate hook.
///
/// ### Performance notes (PR-D)
///
/// The active-item styling for each wheel is driven by a
/// [ValueNotifier<int>] that the `ListWheelScrollView` updates on
/// every `onSelectedItemChanged`. The item builder listens via
/// `ValueListenableBuilder`, so only the one or two row widgets whose
/// active/inactive state just changed rebuild — the parent picker
/// does **not** `setState` on every wheel tick. Previously a fling
/// ran through `_UiTimePickerState.setState` for every snapped index,
/// which in turn rebuilt the outer `UiBox` + both wheel subtrees on
/// every frame of the fling deceleration. That was the visible
/// "scrolling lag" on low-powered Android devices: the minute column
/// was rebuilding 30–40 times during a normal fling even though its
/// structure hadn't changed.
///
/// `onChanged` is still invoked once per snapped index so external
/// listeners (form state, other pickers) see the full stream of
/// intermediate values during a fling, unchanged from before.
class UiTimePicker extends StatefulWidget {
  const UiTimePicker({
    super.key,
    this.value,
    this.onChanged,
    this.minuteStep = 1,
    this.hourDisabled,
    this.semanticsPrefix,
  }) : assert(
          minuteStep > 0 && 60 % minuteStep == 0,
          'minuteStep must divide 60',
        );

  final UiTimeValue? value;
  final ValueChanged<UiTimeValue>? onChanged;
  final int minuteStep;

  /// Returns `true` for hours (0..23) that cannot be chosen.
  final bool Function(int hour)? hourDisabled;

  /// Optional spoken prefix applied to wheel-row semantics labels.
  final String? semanticsPrefix;

  @override
  State<UiTimePicker> createState() => _UiTimePickerState();
}

class _UiTimePickerState extends State<UiTimePicker> {
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late final ValueNotifier<int> _hourNotifier;
  late final ValueNotifier<int> _minuteIndexNotifier;

  int get _hour => _hourNotifier.value;
  int get _minute => _minuteIndexNotifier.value * widget.minuteStep;

  @override
  void initState() {
    super.initState();
    final v = widget.value ?? const UiTimeValue(hour: 9, minute: 0);
    final minute = v.minute - (v.minute % widget.minuteStep);
    _hourNotifier = ValueNotifier<int>(v.hour);
    _minuteIndexNotifier = ValueNotifier<int>(minute ~/ widget.minuteStep);
    _hourCtrl = FixedExtentScrollController(initialItem: v.hour);
    _minuteCtrl = FixedExtentScrollController(
      initialItem: minute ~/ widget.minuteStep,
    );
  }

  @override
  void didUpdateWidget(covariant UiTimePicker old) {
    super.didUpdateWidget(old);
    // If the caller supplies a new `value` prop, quietly align the
    // controllers + notifiers without firing onChanged.
    final v = widget.value;
    if (v != null) {
      final minute = v.minute - (v.minute % widget.minuteStep);
      final minIdx = minute ~/ widget.minuteStep;
      if (_hourNotifier.value != v.hour) {
        _hourNotifier.value = v.hour;
        _hourCtrl.jumpToItem(v.hour);
      }
      if (_minuteIndexNotifier.value != minIdx) {
        _minuteIndexNotifier.value = minIdx;
        _minuteCtrl.jumpToItem(minIdx);
      }
    }
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourNotifier.dispose();
    _minuteIndexNotifier.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged?.call(UiTimeValue(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final minuteItems = 60 ~/ widget.minuteStep;

    return UiBox(
      background: c.surface,
      border: Border.all(color: c.border),
      borderRadius: tokens.radius.lgAll,
      padding: EdgeInsets.all(tokens.spacing.x3),
      child: SizedBox(
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: tokens.radius.smAll,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _Wheel(
                    semanticsLabel: 'Hours',
                    semanticsPrefix: widget.semanticsPrefix,
                    controller: _hourCtrl,
                    itemCount: 24,
                    activeIndex: _hourNotifier,
                    onSelectedItemChanged: (i) {
                      if (widget.hourDisabled?.call(i) ?? false) return;
                      _hourNotifier.value = i;
                      _emit();
                    },
                    itemBuilder: (i, active) {
                      final disabled = widget.hourDisabled?.call(i) ?? false;
                      final value = i.toString().padLeft(2, '0');
                      return _wheelLabel(
                        context,
                        value,
                        active: active,
                        disabled: disabled,
                        semanticsLabel: _wheelRowSemantics(
                          value: value,
                          unit: 'hour',
                          selected: active,
                          disabled: disabled,
                        ),
                      );
                    },
                  ),
                ),
                UiText(':', variant: UiTextVariant.heading),
                Expanded(
                  child: _Wheel(
                    semanticsLabel: 'Minutes',
                    semanticsPrefix: widget.semanticsPrefix,
                    controller: _minuteCtrl,
                    itemCount: minuteItems,
                    activeIndex: _minuteIndexNotifier,
                    onSelectedItemChanged: (i) {
                      _minuteIndexNotifier.value = i;
                      _emit();
                    },
                    itemBuilder: (i, active) {
                      final minuteValue = i * widget.minuteStep;
                      final mm = minuteValue.toString().padLeft(2, '0');
                      return _wheelLabel(
                        context,
                        mm,
                        active: active,
                        semanticsLabel: _wheelRowSemantics(
                          value: mm,
                          unit: 'minute',
                          selected: active,
                          disabled: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheelLabel(
    BuildContext context,
    String label, {
    required bool active,
    bool disabled = false,
    required String semanticsLabel,
  }) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return Semantics(
      container: true,
      selected: active,
      enabled: !disabled,
      label: semanticsLabel,
      child: Center(
        child: ExcludeSemantics(
          child: UiText(
            label,
            variant: UiTextVariant.heading,
            style: TextStyle(
              color: disabled ? c.textMuted : c.textPrimary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  String _wheelRowSemantics({
    required String value,
    required String unit,
    required bool selected,
    required bool disabled,
  }) {
    final parts = <String>[
      if (widget.semanticsPrefix != null &&
          widget.semanticsPrefix!.trim().isNotEmpty)
        widget.semanticsPrefix!.trim(),
      '$unit $value',
      if (selected) 'selected',
      if (disabled) 'disabled',
    ];
    return parts.join(', ');
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.semanticsLabel,
    required this.semanticsPrefix,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
    required this.activeIndex,
  });

  final String semanticsLabel;
  final String? semanticsPrefix;
  final FixedExtentScrollController controller;
  final int itemCount;
  final Widget Function(int index, bool active) itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;
  final ValueListenable<int> activeIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [
        if (semanticsPrefix != null && semanticsPrefix!.trim().isNotEmpty)
          semanticsPrefix!.trim(),
        semanticsLabel,
        'picker',
      ].join(', '),
      explicitChildNodes: true,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 36,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelectedItemChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
            // Only the row whose active/inactive state just changed
            // rebuilds. The parent does not setState on fling; see the
            // class doc for perf rationale.
            return ValueListenableBuilder<int>(
              valueListenable: activeIndex,
              builder: (context, current, _) =>
                  itemBuilder(index, index == current),
            );
          },
        ),
      ),
    );
  }
}

/// Imperative helper: shows a time picker inside a modal sheet and
/// resolves with the chosen [UiTimeValue], or `null` on cancel.
///
/// Requires `UiSheetScope.show` — kept separate to avoid a circular
/// import between pickers and surfaces. Callers can wire it up in a
/// few lines; see the README for the canonical pattern.
UiTimeValue selectedTime(DateTime d) =>
    UiTimeValue(hour: d.hour, minute: d.minute);
