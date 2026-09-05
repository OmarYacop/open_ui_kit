import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Star (or configurable-icon) rating input.
///
/// Renders [count] icons in a row, filled up to [value]. Pass `null` to
/// [onChanged] for a display-only control (e.g. showing an average rating
/// nobody can edit); use [readOnly] when a callback exists but the value
/// must not change from this widget, and [enabled] for the fully muted,
/// non-interactive state.
///
/// Each icon is its own [UiPressable] tap target, matching how
/// [UiRadioGroup] composes multiple [UiRadio] items rather than reading a
/// single drag gesture across the whole row.
///
/// ```dart
/// UiRating(
///   value: rating,
///   allowHalfRating: true,
///   label: 'Your rating',
///   onChanged: (value) => setState(() => rating = value),
/// )
/// ```
class UiRating extends StatefulWidget {
  const UiRating({
    super.key,
    required this.value,
    this.onChanged,
    this.count = 5,
    this.allowHalfRating = false,
    this.size = 24,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.semanticLabel,
    this.icon,
    this.focusNode,
    this.autofocus = false,
  }) : assert(count > 0, 'count must be greater than zero'),
       assert(value >= 0, 'value must not be negative');

  /// Current rating value. Supports half-values (e.g. `3.5`) when
  /// [allowHalfRating] is `true`; otherwise callers should pass whole
  /// numbers.
  final double value;

  /// Called with the new value when the user taps an icon or adjusts it
  /// with the keyboard. `null` renders a display-only control.
  final ValueChanged<double>? onChanged;

  /// Number of icons rendered.
  final int count;

  /// Whether tapping the left/right half of an icon sets a `.5` value
  /// instead of always rounding up to the whole icon.
  final bool allowHalfRating;

  /// Icon size in logical pixels.
  final double size;

  /// Optional label shown above the icons.
  final String? label;

  /// Optional helper text shown below the icons when there is no error.
  final String? helper;

  /// Optional validation error shown below the icons.
  final String? errorText;

  /// Whether the control can be interacted with at all. Disabled renders
  /// muted and ignores every input, which is distinct from [readOnly].
  final bool enabled;

  /// Whether the control only displays a value (e.g. an aggregate rating)
  /// even though [onChanged] may be set. Unlike [enabled], read-only keeps
  /// the normal (non-muted) fill colors — it just can't be changed here.
  final bool readOnly;

  /// Accessibility label announced instead of the generated
  /// "Rating: x out of y stars" string.
  final String? semanticLabel;

  /// Icon used for filled/empty/partial icons. Defaults to
  /// [LucideIcons.star].
  final IconData? icon;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<UiRating> createState() => _UiRatingState();
}

class _UiRatingState extends State<UiRating> {
  bool _focused = false;
  bool get _interactive =>
      widget.enabled && !widget.readOnly && widget.onChanged != null;

  double get _step => widget.allowHalfRating ? 0.5 : 1.0;

  void _setValue(double next) {
    final clamped = next.clamp(0.0, widget.count.toDouble());
    if (clamped != widget.value) {
      widget.onChanged?.call(clamped);
    }
  }

  void _adjust(double delta) => _setValue(widget.value + delta);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_interactive || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _adjust(rtl ? -_step : _step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _adjust(rtl ? _step : -_step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String get _computedSemanticsLabel {
    final formatted = widget.value == widget.value.roundToDouble()
        ? widget.value.toStringAsFixed(0)
        : widget.value.toStringAsFixed(1);
    return UiLocalizations.of(context).ratingLabel(formatted, widget.count);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final icon = widget.icon ?? LucideIcons.star;

    final filledColor = widget.enabled ? c.warning : c.mutedForeground;
    final emptyColor = c.mutedForeground;

    final stars = List<Widget>.generate(widget.count, (index) {
      return Padding(
        padding: EdgeInsetsDirectional.only(
          end: index == widget.count - 1 ? 0 : tokens.spacing.x1,
        ),
        child: _RatingStar(
          index: index,
          value: widget.value,
          size: widget.size,
          icon: icon,
          allowHalfRating: widget.allowHalfRating,
          interactive: _interactive,
          filledColor: filledColor,
          emptyColor: emptyColor,
          onSelect: _setValue,
        ),
      );
    });

    return Semantics(
      label: widget.semanticLabel ?? _computedSemanticsLabel,
      enabled: _interactive,
      slider: true,
      onIncrease: _interactive ? () => _adjust(_step) : null,
      onDecrease: _interactive ? () => _adjust(-_step) : null,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: _interactive,
        onKeyEvent: _handleKey,
        onFocusChange: (value) => setState(() => _focused = value),
        child: Column(
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
            UiFocusRing(
              visible: _focused,
              child: ExcludeFocus(
                child: Row(mainAxisSize: MainAxisSize.min, children: stars),
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
        ),
      ),
    );
  }
}

/// One icon slot within [UiRating].
///
/// Each slot has one 48-pixel target; half values follow the reading direction.
class _RatingStar extends StatefulWidget {
  const _RatingStar({
    required this.index,
    required this.value,
    required this.size,
    required this.icon,
    required this.allowHalfRating,
    required this.interactive,
    required this.filledColor,
    required this.emptyColor,
    required this.onSelect,
  });

  final int index;
  final double value;
  final double size;
  final IconData icon;
  final bool allowHalfRating;
  final bool interactive;
  final Color filledColor;
  final Color emptyColor;
  final ValueChanged<double> onSelect;

  @override
  State<_RatingStar> createState() => _RatingStarState();
}

class _RatingStarState extends State<_RatingStar> {
  double? _pointerX;

  @override
  Widget build(BuildContext context) {
    final tapSize = widget.size < 48 ? 48.0 : widget.size;
    final iconWidget = _StarIcon(
      icon: widget.icon,
      size: widget.size,
      fill: (widget.value - widget.index).clamp(0.0, 1.0),
      allowHalf: widget.allowHalfRating,
      filledColor: widget.filledColor,
      emptyColor: widget.emptyColor,
    );
    return SizedBox(
      width: tapSize,
      height: tapSize,
      child: Listener(
        onPointerDown: (event) => _pointerX = event.localPosition.dx,
        onPointerCancel: (_) => _pointerX = null,
        child: UiPressable(
          enabled: widget.interactive,
          minTapSize: tapSize,
          excludeFromSemantics: true,
          onPressed: widget.interactive
              ? () {
                  final x = _pointerX;
                  _pointerX = null;
                  final startHalf =
                      x != null &&
                      (Directionality.of(context) == TextDirection.rtl
                          ? x > tapSize / 2
                          : x < tapSize / 2);
                  widget.onSelect(
                    widget.index +
                        (widget.allowHalfRating && startHalf ? .5 : 1),
                  );
                }
              : null,
          builder: (context, state, _) => Center(child: iconWidget),
        ),
      ),
    );
  }
}

/// Draws a single icon glyph, proportionally filled from the start edge.
///
/// `fill >= 1` is a fully filled icon, `fill <= 0` (or half-rating
/// disabled) is fully empty, and anything in between clips a filled copy
/// over an empty one so the visible fraction matches [fill] exactly — not
/// just the `.5` increments [UiRating.allowHalfRating] exposes for input.
class _StarIcon extends StatelessWidget {
  const _StarIcon({
    required this.icon,
    required this.size,
    required this.fill,
    required this.allowHalf,
    required this.filledColor,
    required this.emptyColor,
  });

  final IconData icon;
  final double size;
  final double fill;
  final bool allowHalf;
  final Color filledColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    if (fill >= 1.0) {
      return Icon(icon, size: size, color: filledColor);
    }
    if (fill <= 0.0 || !allowHalf) {
      return Icon(icon, size: size, color: emptyColor);
    }

    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        Icon(icon, size: size, color: emptyColor),
        ClipRect(
          clipper: _FractionClipper(fill, Directionality.of(context)),
          child: Icon(icon, size: size, color: filledColor),
        ),
      ],
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  const _FractionClipper(this.fraction, this.direction);

  final TextDirection direction;

  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    direction == TextDirection.rtl ? size.width * (1 - fraction) : 0,
    0,
    size.width * fraction,
    size.height,
  );

  @override
  bool shouldReclip(covariant _FractionClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.direction != direction;
}
