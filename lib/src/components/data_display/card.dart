import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Visual density of a card surface.
enum UiCardVariant { standard, outlined, elevated, muted }

/// Neutral card surface.
///
/// When [onPressed] is supplied the card becomes interactive (hover/press
/// feedback) without losing its compositional slots.
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    this.header,
    this.footer,
    this.child,
    this.padding,
    this.variant = UiCardVariant.standard,
    this.borderRadius,
    this.onPressed,
  });

  final Widget? header;
  final Widget? footer;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final UiCardVariant variant;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final resolvedPadding = padding ?? EdgeInsets.all(tokens.spacing.x6);

    Widget surface(UiPressableState? state) {
      final pressed = state?.pressed ?? false;
      final hovered = state?.hovered ?? false;
      Color bg;
      Color border;
      List<BoxShadow>? shadow;

      switch (variant) {
        case UiCardVariant.standard:
          bg = c.card;
          border = c.border;
          break;
        case UiCardVariant.outlined:
          bg = const Color(0x00000000);
          border = c.border;
          break;
        case UiCardVariant.elevated:
          bg = c.card;
          border = c.border;
          shadow = tokens.shadows.sm;
          break;
        case UiCardVariant.muted:
          bg = c.muted;
          border = c.border;
          break;
      }

      if (pressed) bg = _shift(bg, -0.03);
      if (hovered && !pressed) bg = _shift(bg, -0.015);

      return UiBox(
        background: bg,
        border: Border.all(color: border, width: 1),
        borderRadius: borderRadius ?? tokens.radius.xlAll,
        boxShadow: shadow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.x6,
                  vertical: tokens.spacing.x4,
                ),
                child: header,
              ),
            if (header != null) const UiDivider(),
            if (child != null) Padding(padding: resolvedPadding, child: child),
            if (footer != null) const UiDivider(),
            if (footer != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.x6,
                  vertical: tokens.spacing.x4,
                ),
                child: footer,
              ),
          ],
        ),
      );
    }

    if (onPressed == null) return surface(null);

    return UiPressable(
      onPressed: onPressed,
      minTapSize: 0,
      builder: (context, state, _) => surface(state),
    );
  }

  static Color _shift(Color base, double amount) {
    if (base.a == 0) return base;
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/// Convenience header cell with title + optional subtitle/trailing.
class UiCardHeader extends StatelessWidget {
  const UiCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiText(title, variant: UiTextVariant.subheading),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spacing.x1),
                UiText(
                  subtitle!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
