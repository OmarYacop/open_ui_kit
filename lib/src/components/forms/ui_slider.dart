import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Intent fired by arrow keys to nudge a [UiSlider] up or down by one step.
class _AdjustSliderIntent extends Intent {
  const _AdjustSliderIntent(this.direction);

  /// `1` increases the value, `-1` decreases it.
  final int direction;
}

/// A single-value range slider (min/max/value/onChanged) — think volume or
/// brightness, not a two-handle range selector.
///
/// Mirrors Flutter's own [Slider] API where it makes sense (`min`, `max`,
/// `divisions`, `onChangeStart`/`onChangeEnd`) while following Open UI Kit's
/// label/helper/errorText slot conventions used by `UiCheckbox` and
/// `UiInput`. The thumb responds to drag, to a tap anywhere on the track, and
/// to arrow keys while focused.
class UiSlider extends StatefulWidget {
  const UiSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.onChangeStart,
    this.onChangeEnd,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  })  : assert(min < max, 'min must be less than max'),
        assert(
          value >= min && value <= max,
          'value must be within [min, max]',
        ),
        assert(
          divisions == null || divisions > 0,
          'divisions must be greater than zero',
        );

  /// The current value. Must be within [min]..[max].
  final double value;

  /// Called with the new value while the thumb is dragged, tapped, or
  /// adjusted with arrow keys. Leave null to render a disabled, read-only
  /// slider.
  final ValueChanged<double>? onChanged;

  final double min;
  final double max;

  /// When set, the slider snaps to this many discrete steps between [min]
  /// and [max] instead of moving continuously.
  final int? divisions;

  final String? label;
  final String? helper;
  final String? errorText;
  final bool enabled;

  /// Called once when a drag gesture begins, before the first [onChanged].
  final ValueChanged<double>? onChangeStart;

  /// Called once when a drag gesture ends, after the last [onChanged].
  final ValueChanged<double>? onChangeEnd;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Overrides the label announced to assistive technology. Falls back to
  /// [label], then a generic "slider".
  final String? semanticLabel;

  @override
  State<UiSlider> createState() => _UiSliderState();
}

class _UiSliderState extends State<UiSlider> {
  FocusNode? _ownFocusNode;
  bool _hovered = false;
  bool _focused = false;
  bool _dragging = false;

  static const double _thumbSize = 18;
  static const double _trackHeight = 6;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  bool get _interactive => widget.enabled && widget.onChanged != null;

  double get _range => widget.max - widget.min;

  /// One keyboard/discrete step: `1 / divisions` of the range when
  /// [UiSlider.divisions] is set, otherwise 1% of the range.
  double get _step {
    final divisions = widget.divisions;
    return divisions != null ? _range / divisions : _range * 0.01;
  }

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(widget.min, widget.max);

  double _snap(double v) {
    final divisions = widget.divisions;
    if (divisions == null) return v;
    final fraction = ((v - widget.min) / _range * divisions).round();
    return widget.min + (fraction / divisions) * _range;
  }

  double _resolve(double v) => _snap(_clamp(v));

  void _setHovered(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  void _setFocused(bool v) {
    if (_focused != v) setState(() => _focused = v);
  }

  double _fractionToValue(double fraction) =>
      widget.min + fraction.clamp(0.0, 1.0) * _range;

  double _localDxToFraction(double dx, double width) {
    if (width <= _thumbSize) return 0;
    final travel = width - _thumbSize;
    final x = (dx - _thumbSize / 2).clamp(0.0, travel);
    return x / travel;
  }

  void _handleDragStart(DragStartDetails details, double width) {
    if (!_interactive) return;
    setState(() => _dragging = true);
    widget.onChangeStart?.call(widget.value);
    _updateFromDx(details.localPosition.dx, width);
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    if (!_interactive) return;
    _updateFromDx(details.localPosition.dx, width);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_interactive) return;
    setState(() => _dragging = false);
    widget.onChangeEnd?.call(widget.value);
  }

  void _handleTapDown(TapDownDetails details, double width) {
    if (!_interactive) return;
    _focusNode.requestFocus();
    widget.onChangeStart?.call(widget.value);
    _updateFromDx(details.localPosition.dx, width);
    widget.onChangeEnd?.call(_resolve(widget.value));
  }

  void _updateFromDx(double dx, double width) {
    final next = _resolve(_fractionToValue(_localDxToFraction(dx, width)));
    if (next != widget.value) widget.onChanged?.call(next);
  }

  void _handleAdjust(int direction) {
    if (!_interactive) return;
    final next = _resolve(widget.value + direction * _step);
    if (next == widget.value) return;
    widget.onChangeStart?.call(widget.value);
    widget.onChanged?.call(next);
    widget.onChangeEnd?.call(next);
  }

  String _formatValue(double v) {
    final divisions = widget.divisions;
    if (divisions != null) {
      final step = _range / divisions;
      // Whole-step divisions read better without decimals.
      return step % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    }
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final disabled = !_interactive;

    final trackColor = disabled ? c.muted : c.input;
    final fillColor = disabled ? c.mutedForeground : c.primary;
    final thumbBorderColor = hasError
        ? c.destructive
        : disabled
            ? c.mutedForeground
            : c.primary;

    final fraction = _range == 0
        ? 0.0
        : ((widget.value - widget.min) / _range).clamp(0.0, 1.0);

    final semanticValue = _formatValue(widget.value);
    final increasedValue = _formatValue(_resolve(widget.value + _step));
    final decreasedValue = _formatValue(_resolve(widget.value - _step));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          UiText(
            widget.label!,
            variant: UiTextVariant.label,
            tone: disabled ? UiTextTone.muted : UiTextTone.primary,
          ),
          SizedBox(height: tokens.spacing.x1),
        ],
        Semantics(
          slider: true,
          enabled: _interactive,
          label: widget.semanticLabel ?? widget.label ?? 'slider',
          value: semanticValue,
          increasedValue: increasedValue,
          decreasedValue: decreasedValue,
          onIncrease: _interactive ? () => _handleAdjust(1) : null,
          onDecrease: _interactive ? () => _handleAdjust(-1) : null,
          child: Focus(
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            canRequestFocus: _interactive,
            onFocusChange: _setFocused,
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.arrowRight):
                    _AdjustSliderIntent(1),
                SingleActivator(LogicalKeyboardKey.arrowLeft):
                    _AdjustSliderIntent(-1),
                SingleActivator(LogicalKeyboardKey.arrowUp):
                    _AdjustSliderIntent(1),
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    _AdjustSliderIntent(-1),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _AdjustSliderIntent: CallbackAction<_AdjustSliderIntent>(
                    onInvoke: (intent) {
                      _handleAdjust(intent.direction);
                      return null;
                    },
                  ),
                },
                child: MouseRegion(
                  cursor: disabled
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onEnter: (_) => _setHovered(true),
                  onExit: (_) => _setHovered(false),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final thumbLeft = width <= _thumbSize
                          ? 0.0
                          : fraction * (width - _thumbSize);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown:
                            disabled ? null : (d) => _handleTapDown(d, width),
                        onHorizontalDragStart:
                            disabled ? null : (d) => _handleDragStart(d, width),
                        onHorizontalDragUpdate: disabled
                            ? null
                            : (d) => _handleDragUpdate(d, width),
                        onHorizontalDragEnd: disabled ? null : _handleDragEnd,
                        excludeFromSemantics: true,
                        child: SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.none,
                            children: [
                              // Base track.
                              Container(
                                height: _trackHeight,
                                decoration: BoxDecoration(
                                  color: trackColor,
                                  borderRadius: tokens.radius.pillAll,
                                ),
                              ),
                              // Filled portion up to the thumb.
                              Container(
                                height: _trackHeight,
                                width: thumbLeft + _thumbSize / 2,
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: tokens.radius.pillAll,
                                ),
                              ),
                              AnimatedPositioned(
                                duration: _dragging
                                    ? Duration.zero
                                    : tokens.motion.fast,
                                curve: tokens.motion.standardCurve,
                                left: thumbLeft,
                                child: UiFocusRing(
                                  visible: _focused && !hasError,
                                  borderRadius: tokens.radius.pillAll,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: thumbBorderColor,
                                        width: 2,
                                      ),
                                      boxShadow:
                                          (_hovered || _dragging) && !disabled
                                              ? tokens.shadows.sm
                                              : null,
                                    ),
                                    child: SizedBox(
                                      width: _thumbSize,
                                      height: _thumbSize,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            widget.errorText!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.danger,
          ),
        ] else if (widget.helper != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            widget.helper!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
          ),
        ],
      ],
    );
  }
}
