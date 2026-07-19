import 'package:flutter/material.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart' show UiIntent, UiIntentPalette, UiSize;

/// Icon-only button primitive.
///
/// Use this for compact toolbar actions, card menus, close buttons, and other
/// controls where the visible label is an icon. [semanticsLabel] is required so
/// the control remains accessible.
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPressed,
    this.intent = UiIntent.ghost,
    this.size = UiSize.md,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final UiIntent intent;
  final UiSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final radius = borderRadius ?? tokens.radius.mdAll;
    final visualSize = _visualSize(size);
    final iconSize = _iconSize(size);

    return UiPressable(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      minTapSize: 44,
      builder: (context, state, _) {
        final palette = UiIntentPalette.rest(intent, tokens.colors);
        final fg = foregroundColor ?? palette.foreground;
        final bg = backgroundColor ?? palette.background;
        final border = borderColor ?? palette.border;
        final isTransparent = bg.a == 0;
        final effectiveBg = state.pressed
            ? (isTransparent
                ? tokens.colors.accent.withValues(alpha: 0.60)
                : _shift(bg, -0.03))
            : state.hovered
                ? (isTransparent
                    ? tokens.colors.accent.withValues(alpha: 0.35)
                    : _shift(bg, -0.015))
                : bg;

        return UiFocusRing(
          visible: state.focused,
          borderRadius: radius,
          child: Transform.scale(
            scale: state.pressed ? 0.96 : 1,
            child: UiBox(
              width: visualSize,
              height: visualSize,
              background: effectiveBg,
              border: border == null ? null : Border.all(color: border),
              borderRadius: radius,
              alignment: Alignment.center,
              child: IconTheme.merge(
                data: IconThemeData(color: fg, size: iconSize),
                child: icon,
              ),
            ),
          ),
        );
      },
    );
  }

  static double _visualSize(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 28;
      case UiSize.md:
        return 36;
      case UiSize.lg:
        return 44;
    }
  }

  static double _iconSize(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 17;
      case UiSize.md:
        return 20;
      case UiSize.lg:
        return 22;
    }
  }

  static Color _shift(Color base, double amount) {
    if (base.a == 0) return base;
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}
