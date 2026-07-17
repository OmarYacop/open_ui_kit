import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiButtonMetrics, UiSize;

/// Selectable chip for compact filters and option toggles.
///
/// This is intentionally a small form control rather than a status badge:
/// it is interactive, exposes selected semantics, and calls [onSelected] with
/// the next selected value.
class UiFilterChip extends StatelessWidget {
  const UiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.size = UiSize.md,
    this.leading,
    this.trailing,
    this.semanticsLabel,
    this.selectedBackgroundColor,
    this.selectedForegroundColor,
    this.selectedBorderColor,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final UiSize size;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticsLabel;

  final Color? selectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? selectedBorderColor;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  bool get _enabled => onSelected != null;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final radius = borderRadius ?? tokens.radius.pillAll;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: _enabled,
      label: semanticsLabel ?? label,
      onTap: _enabled ? () => onSelected!(!selected) : null,
      child: UiPressable(
        excludeFromSemantics: true,
        enabled: _enabled,
        onPressed: _enabled ? () => onSelected!(!selected) : null,
        minTapSize: 44,
        builder: (context, state, _) {
          final colors = _resolveColors(tokens, state);
          return UiFocusRing(
            visible: state.focused,
            borderRadius: radius,
            child: AnimatedOpacity(
              opacity: state.disabled ? 0.5 : 1,
              duration: tokens.motion.fast,
              child: AnimatedScale(
                scale: state.pressed ? 0.97 : 1,
                duration: tokens.motion.fast,
                curve: tokens.motion.standardCurve,
                child: UiBox(
                  background: colors.background,
                  border: Border.all(color: colors.border),
                  borderRadius: radius,
                  padding: _paddingFor(size, tokens),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        IconTheme.merge(
                          data: IconThemeData(
                            color: colors.foreground,
                            size: UiButtonMetrics.iconSize(size),
                          ),
                          child: leading!,
                        ),
                        SizedBox(
                            width: UiButtonMetrics.gap(size, tokens.spacing)),
                      ],
                      Flexible(
                        child: UiText(
                          label,
                          variant: UiButtonMetrics.textVariant(size),
                          style: UiButtonMetrics.textStyle(
                            size,
                            tokens,
                          ).copyWith(color: colors.foreground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailing != null) ...[
                        SizedBox(
                            width: UiButtonMetrics.gap(size, tokens.spacing)),
                        IconTheme.merge(
                          data: IconThemeData(
                            color: colors.foreground,
                            size: UiButtonMetrics.iconSize(size),
                          ),
                          child: trailing!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _ChipColors _resolveColors(
    UiThemeTokens tokens,
    UiPressableState state,
  ) {
    final c = tokens.colors;
    final selectedBg = selectedBackgroundColor ?? c.primary;
    final selectedFg = selectedForegroundColor ?? c.onPrimary;
    final unselectedBg = backgroundColor ?? c.surface;
    final unselectedFg = foregroundColor ?? c.textPrimary;

    var background = selected ? selectedBg : unselectedBg;
    final foreground = selected ? selectedFg : unselectedFg;
    final border =
        selected ? selectedBorderColor ?? selectedBg : borderColor ?? c.border;

    if (!state.disabled) {
      if (state.pressed) {
        background = _shift(background, selected ? -0.08 : -0.05);
      } else if (state.hovered) {
        background = _shift(background, selected ? -0.04 : -0.03);
      }
    }

    return _ChipColors(
      background: background,
      foreground: foreground,
      border: border,
    );
  }

  static EdgeInsets _paddingFor(UiSize size, UiThemeTokens tokens) {
    switch (size) {
      case UiSize.sm:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      case UiSize.md:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case UiSize.lg:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    }
  }

  static Color _shift(Color base, double amount) {
    if (base.a == 0) return base;
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

class _ChipColors {
  const _ChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
