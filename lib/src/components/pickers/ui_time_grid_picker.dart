import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/overlay/ui_anchored_overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/theme/ui_intent.dart';
import '../forms/button.dart' show UiButton, UiSize;
import 'ui_picker_models.dart';

/// Time format used by [UiTimeGridPicker] and [UiTimePickerField].
enum UiTimePickerClockFormat { h12, h24 }

/// Compact column-based time picker inspired by popover time controls.
///
/// Unlike [UiTimePicker], which uses native-feeling wheels, this picker uses
/// tappable hour/minute/period option columns. It is useful in drawers, popovers,
/// and forms where all available time parts should be visible at once.
///
/// Prefer [UiTimePickerField] for normal form inputs. Use this widget directly
/// when the time control is already inside drawer, sheet, dialog, or card
/// content. In those cases, usually disable the wrapper border/padding so the
/// parent surface owns the chrome:
///
/// ```dart
/// UiTimeGridPicker(
///   value: startsAt,
///   minuteStep: 15,
///   onChanged: (value) => setState(() => startsAt = value),
///   showBorder: false,
///   chromePadding: EdgeInsets.zero,
/// )
/// ```
class UiTimeGridPicker extends StatelessWidget {
  const UiTimeGridPicker({
    super.key,
    this.value,
    this.onChanged,
    this.minuteStep = 5,
    this.format = UiTimePickerClockFormat.h12,
    this.hourDisabled,
    this.label = 'Time',
    this.onDone,
    this.doneLabel = 'Done',
    this.semanticsPrefix,
    this.showChrome = true,
    this.showBorder = true,
    this.chromePadding,
    this.boxShadow,
  }) : assert(
          minuteStep > 0 && 60 % minuteStep == 0,
          'minuteStep must divide 60',
        );

  final UiTimeValue? value;
  final ValueChanged<UiTimeValue>? onChanged;
  final int minuteStep;
  final UiTimePickerClockFormat format;

  /// Returns `true` for hours (0..23) that cannot be chosen.
  final bool Function(int hour)? hourDisabled;

  /// Header label shown above the active time.
  final String label;

  /// Optional action shown at the bottom of the picker.
  final VoidCallback? onDone;
  final String doneLabel;

  /// Optional spoken prefix applied to option semantics labels.
  final String? semanticsPrefix;

  /// Whether to render the outer popover/drawer surface.
  ///
  /// Set to `false` only when the caller completely owns background, radius,
  /// padding, and border. For most embedded use, keep this `true` and adjust
  /// [showBorder] / [chromePadding].
  final bool showChrome;

  /// Whether [showChrome] includes an outline.
  ///
  /// Defaults to `true` for standalone popovers. Set to `false` when embedded
  /// inside an already bordered surface.
  final bool showBorder;

  /// Padding applied by [showChrome]. Defaults to compact picker padding.
  final EdgeInsetsGeometry? chromePadding;

  /// Optional shadow for the outer surface. Defaults to medium popover shadow.
  final List<BoxShadow>? boxShadow;

  UiTimeValue get _effectiveValue =>
      value ?? const UiTimeValue(hour: 9, minute: 0);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final time = _effectiveValue;
    final selectedPeriod = time.hour >= 12 ? _Period.pm : _Period.am;
    final minuteItems = 60 ~/ minuteStep;
    final hours = format == UiTimePickerClockFormat.h12
        ? List<int>.generate(12, (i) => i + 1)
        : List<int>.generate(24, (i) => i);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiBox(
          background: c.surfaceMuted,
          borderRadius: tokens.radius.mdAll,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x3,
            vertical: tokens.spacing.x2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              UiText(
                label,
                variant: UiTextVariant.caption,
                tone: UiTextTone.muted,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              UiText(
                _formatValue(time),
                variant: UiTextVariant.body,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.x3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TimePickerColumn(
                label: 'Hour',
                child: _ScrollableOptionList(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final hour in hours)
                        _TimePickerOption(
                          label: _hourLabel(hour),
                          selected: _isHourSelected(time.hour, hour),
                          disabled: _hourDisabled(hour, selectedPeriod),
                          semanticsLabel: _semanticsLabel(
                            'hour ${_hourLabel(hour)}',
                            selected: _isHourSelected(time.hour, hour),
                            disabled: _hourDisabled(hour, selectedPeriod),
                          ),
                          onPressed: () => _pickHour(hour, selectedPeriod),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.x2),
            Expanded(
              child: _TimePickerColumn(
                label: 'Minute',
                child: _ScrollableOptionList(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < minuteItems; i++)
                        _TimePickerOption(
                          label: (i * minuteStep).toString().padLeft(2, '0'),
                          selected: time.minute == i * minuteStep,
                          semanticsLabel: _semanticsLabel(
                            'minute ${(i * minuteStep).toString().padLeft(2, '0')}',
                            selected: time.minute == i * minuteStep,
                          ),
                          onPressed: () => _pickMinute(i * minuteStep),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (format == UiTimePickerClockFormat.h12) ...[
              SizedBox(width: tokens.spacing.x2),
              SizedBox(
                width: 72,
                child: _TimePickerColumn(
                  label: 'Period',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final period in _Period.values)
                        _TimePickerOption(
                          label: period.label,
                          selected: selectedPeriod == period,
                          semanticsLabel: _semanticsLabel(
                            period.label,
                            selected: selectedPeriod == period,
                          ),
                          onPressed: () => _pickPeriod(period),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (onDone != null) ...[
          SizedBox(height: tokens.spacing.x3),
          UiBox(height: 1, background: c.border),
          SizedBox(height: tokens.spacing.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: UiButton(
              label: doneLabel,
              size: UiSize.sm,
              intent: UiIntent.neutral,
              onPressed: onDone,
            ),
          ),
        ],
      ],
    );

    if (!showChrome) return content;

    return UiBox(
      background: c.popover,
      border: showBorder ? Border.all(color: c.border) : null,
      borderRadius: tokens.radius.lgAll,
      boxShadow: boxShadow ?? tokens.shadows.md,
      padding: chromePadding ?? EdgeInsets.all(tokens.spacing.x3),
      child: content,
    );
  }

  String _formatValue(UiTimeValue time) {
    switch (format) {
      case UiTimePickerClockFormat.h12:
        return time.formatted12();
      case UiTimePickerClockFormat.h24:
        return time.formatted24();
    }
  }

  String _hourLabel(int hour) {
    if (format == UiTimePickerClockFormat.h24) {
      return hour.toString().padLeft(2, '0');
    }
    return hour.toString().padLeft(2, '0');
  }

  bool _isHourSelected(int selectedHour, int optionHour) {
    if (format == UiTimePickerClockFormat.h24) {
      return selectedHour == optionHour;
    }
    return _toTwelveHour(selectedHour) == optionHour;
  }

  bool _hourDisabled(int optionHour, _Period period) {
    final disabled = hourDisabled;
    if (disabled == null) return false;
    final hour = format == UiTimePickerClockFormat.h24
        ? optionHour
        : _toTwentyFourHour(optionHour, period);
    return disabled(hour);
  }

  void _pickHour(int hour, _Period period) {
    if (_hourDisabled(hour, period)) return;
    final nextHour = format == UiTimePickerClockFormat.h24
        ? hour
        : _toTwentyFourHour(hour, period);
    onChanged
        ?.call(UiTimeValue(hour: nextHour, minute: _effectiveValue.minute));
  }

  void _pickMinute(int minute) {
    onChanged?.call(UiTimeValue(hour: _effectiveValue.hour, minute: minute));
  }

  void _pickPeriod(_Period period) {
    if (format == UiTimePickerClockFormat.h24) return;
    final current = _effectiveValue;
    final hour = _toTwentyFourHour(_toTwelveHour(current.hour), period);
    if (hourDisabled?.call(hour) ?? false) return;
    onChanged?.call(UiTimeValue(hour: hour, minute: current.minute));
  }

  String _semanticsLabel(
    String value, {
    required bool selected,
    bool disabled = false,
  }) {
    final prefix = semanticsPrefix?.trim();
    return [
      if (prefix != null && prefix.isNotEmpty) prefix,
      value,
      if (selected) 'selected',
      if (disabled) 'disabled',
    ].join(', ');
  }
}

/// Read-only form trigger that opens [UiTimeGridPicker] in an anchored overlay.
///
/// This is the default time picker for forms. It keeps input chrome, helper and
/// error text, overlay positioning, and done handling consistent with the rest
/// of the kit.
///
/// ```dart
/// UiTimePickerField(
///   label: 'Starts at',
///   value: startsAt,
///   minuteStep: 15,
///   onChanged: (value) => setState(() => startsAt = value),
/// )
/// ```
class UiTimePickerField extends StatefulWidget {
  const UiTimePickerField({
    super.key,
    this.value,
    this.onChanged,
    this.minuteStep = 5,
    this.format = UiTimePickerClockFormat.h12,
    this.hourDisabled,
    this.label,
    this.hint = 'Choose time',
    this.helper,
    this.errorText,
    this.enabled = true,
    this.doneLabel = 'Done',
    this.semanticsPrefix,
  }) : assert(
          minuteStep > 0 && 60 % minuteStep == 0,
          'minuteStep must divide 60',
        );

  final UiTimeValue? value;
  final ValueChanged<UiTimeValue>? onChanged;
  final int minuteStep;
  final UiTimePickerClockFormat format;
  final bool Function(int hour)? hourDisabled;
  final String? label;
  final String hint;
  final String? helper;
  final String? errorText;
  final bool enabled;
  final String doneLabel;
  final String? semanticsPrefix;

  @override
  State<UiTimePickerField> createState() => _UiTimePickerFieldState();
}

class _UiTimePickerFieldState extends State<UiTimePickerField> {
  final GlobalKey _targetKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _entry;
  UiTimeValue? _overlayValue;
  bool _openAbove = false;
  double _horizontalOffset = 0;
  double _menuWidth = 288;
  Rect? _targetOverlayRect;
  Rect? _targetGlobalRect;

  bool get _interactive => widget.enabled && widget.onChanged != null;
  bool get _hasError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;
  UiTimeValue? get _displayValue =>
      widget.value ?? (_entry != null ? _overlayValue : null);

  @override
  void didUpdateWidget(covariant UiTimePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _overlayValue = widget.value;
      _markOverlayNeedsBuildAfterFrame();
    }
  }

  @override
  void dispose() {
    _hide(notify: false);
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_interactive) return;
    _entry == null ? _show() : _hide();
  }

  void _show() {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _overlayValue = widget.value;
    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: 340,
      maxHeight: 360,
      minWidth: 288,
      allowOverflowWhenCramped: true,
      crampedAvailableHeight: 220,
    );
    if (geometry == null) return;
    _openAbove = geometry.openAbove;
    _horizontalOffset = geometry.horizontalOffset;
    _menuWidth = geometry.width;
    _targetOverlayRect = geometry.targetOverlayRect;
    _targetGlobalRect = geometry.targetGlobalRect;
    _entry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_entry!);
    _focusNode.requestFocus();
    setState(() {});
  }

  void _hide({bool notify = true}) {
    _entry?.remove();
    _entry = null;
    if (notify && mounted) setState(() {});
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    final targetRect = _targetGlobalRect;
    if (targetRect == null || targetRect.contains(event.position)) {
      _hide();
      return;
    }
    _hide();
  }

  void _handleChanged(UiTimeValue value) {
    _overlayValue = value;
    widget.onChanged?.call(value);
    _entry?.markNeedsBuild();
    if (mounted) setState(() {});
  }

  void _markOverlayNeedsBuildAfterFrame() {
    final entry = _entry;
    if (entry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_entry, entry)) {
        entry.markNeedsBuild();
      }
    });
  }

  Widget _buildOverlay() {
    final tokens = UiThemeTokens.of(context);
    final verticalOffset = tokens.spacing.x1;

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleOverlayPointerDown,
          ),
        ),
        if (_targetOverlayRect != null)
          Positioned.fromRect(
            rect: _targetOverlayRect!,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _hide(),
            ),
          ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _openAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _openAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(
            _horizontalOffset,
            _openAbove ? -verticalOffset : verticalOffset,
          ),
          child: SizedBox(
            width: _menuWidth,
            child: UiTimeGridPicker(
              value: _overlayValue ?? widget.value,
              onChanged: _handleChanged,
              minuteStep: widget.minuteStep,
              format: widget.format,
              hourDisabled: widget.hourDisabled,
              label: 'Time',
              doneLabel: widget.doneLabel,
              semanticsPrefix: widget.semanticsPrefix,
              onDone: _hide,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final selected = _displayValue;
    final displayValue = selected == null
        ? widget.hint
        : widget.format == UiTimePickerClockFormat.h12
            ? selected.formatted12()
            : selected.formatted24();
    final helperText = _hasError ? widget.errorText : widget.helper;
    final borderColor = _hasError
        ? c.destructive
        : _entry != null
            ? c.ring
            : c.input;
    final bg = _interactive ? c.surface : c.muted;
    final fg = _interactive ? c.foreground : c.mutedForeground;
    final valueTone = selected == null ? UiTextTone.muted : UiTextTone.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          UiText(
            widget.label!,
            variant: UiTextVariant.label,
            tone: _interactive ? UiTextTone.primary : UiTextTone.muted,
          ),
          SizedBox(height: tokens.spacing.x2),
        ],
        CompositedTransformTarget(
          link: _link,
          child: UiPressable(
            key: _targetKey,
            enabled: _interactive,
            onPressed: _toggle,
            focusNode: _focusNode,
            semanticsLabel: widget.label ?? widget.hint,
            minTapSize: 44,
            builder: (context, state, _) {
              return UiFocusRing(
                visible: state.focused && !_hasError,
                borderRadius: tokens.radius.mdAll,
                child: UiBox(
                  background: bg,
                  border: Border.all(color: borderColor),
                  borderRadius: tokens.radius.mdAll,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.x3,
                    vertical: tokens.spacing.x2,
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.clock3, size: 18, color: fg),
                      SizedBox(width: tokens.spacing.x2),
                      Expanded(
                        child: UiText(
                          displayValue,
                          variant: UiTextVariant.body,
                          tone: valueTone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (helperText != null && helperText.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            helperText,
            variant: UiTextVariant.caption,
            tone: _hasError ? UiTextTone.danger : UiTextTone.muted,
          ),
        ],
      ],
    );
  }
}

class _TimePickerColumn extends StatelessWidget {
  const _TimePickerColumn({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: tokens.spacing.x1),
          child: UiText(
            label,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: tokens.spacing.x2),
        child,
      ],
    );
  }
}

class _ScrollableOptionList extends StatelessWidget {
  const _ScrollableOptionList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 224),
      child: SingleChildScrollView(
        primary: false,
        child: child,
      ),
    );
  }
}

class _TimePickerOption extends StatelessWidget {
  const _TimePickerOption({
    required this.label,
    required this.selected,
    required this.semanticsLabel,
    required this.onPressed,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.x1),
      child: UiPressable(
        enabled: !disabled,
        onPressed: disabled ? null : onPressed,
        minTapSize: 32,
        excludeFromSemantics: true,
        builder: (context, state, _) {
          final active = selected;
          final bg = active
              ? c.primary
              : state.hovered || state.pressed
                  ? c.accent
                  : const Color(0x00000000);
          final fg = disabled
              ? c.mutedForeground
              : active
                  ? c.primaryForeground
                  : c.foreground;

          return Semantics(
            button: true,
            selected: selected,
            enabled: !disabled,
            label: semanticsLabel,
            child: UiBox(
              height: 32,
              background: bg,
              borderRadius: tokens.radius.mdAll,
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x2),
              alignment: Alignment.center,
              child: ExcludeSemantics(
                child: UiText(
                  label,
                  variant: UiTextVariant.body,
                  style: TextStyle(color: fg),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _Period {
  am('AM'),
  pm('PM');

  const _Period(this.label);

  final String label;
}

int _toTwelveHour(int hour) {
  if (hour == 0) return 12;
  if (hour > 12) return hour - 12;
  return hour;
}

int _toTwentyFourHour(int hour, _Period period) {
  if (period == _Period.am) return hour == 12 ? 0 : hour;
  return hour == 12 ? 12 : hour + 12;
}
