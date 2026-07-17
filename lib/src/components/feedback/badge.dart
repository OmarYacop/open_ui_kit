import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart' show UiIntent, UiIntentPalette, UiSize;

/// Compact label surface for statuses and counts.
///
/// Shares its colour recipe with [UiButton] via [UiIntentPalette] so the
/// destructive/primary/secondary/etc. variants read as the same family
/// — the badge is just a smaller, non-interactive pill. Padding is
/// intentionally tighter than the button (shadcn sizes badges at
/// `text-xs px-2 py-0.5` rather than the button's `h-9 px-4`) so rows
/// of badges don't visually drown their surroundings.
///
/// Set [outlined] to render a transparent fill with a 1pt border in the
/// intent colour — useful for status chips on busy surfaces.
class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    required this.label,
    this.intent = UiIntent.defaultIntent,
    this.size = UiSize.sm,
    this.outlined = false,
    this.color,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius,
    this.leading,
    this.trailing,
  });

  final String label;
  final UiIntent intent;
  final UiSize size;

  /// Transparent fill + intent-colored border.
  final bool outlined;

  /// Optional custom status color. When supplied, this overrides [intent] and
  /// renders a soft tinted badge by default.
  final Color? color;

  /// Explicit background override. Use this when a design system needs a badge
  /// on a custom surface instead of the intent/status-color recipes.
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  /// Optional shape override for design systems that use less-rounded badges.
  ///
  /// Defaults to the theme pill radius for backwards compatibility.
  final BorderRadius? borderRadius;

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final palette = UiIntentPalette.rest(intent, tokens.colors);

    final resolvedForeground = foregroundColor ?? color ?? palette.foreground;
    final background = backgroundColor ??
        (color == null
            ? (outlined ? const Color(0x00000000) : palette.background)
            : (outlined ? const Color(0x00000000) : color!.withAlpha(30)));
    final resolvedBorder = borderColor ??
        (backgroundColor != null
            ? null
            : color == null
                ? (outlined ? palette.foreground : palette.border)
                : color!.withAlpha(100));

    return UiBox(
      background: background,
      border: resolvedBorder == null
          ? null
          : Border.all(color: resolvedBorder, width: 1),
      borderRadius: borderRadius ?? tokens.radius.pillAll,
      padding: _paddingFor(size, tokens),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(
                color: resolvedForeground,
                size: _iconSizeFor(size),
              ),
              child: leading!,
            ),
            SizedBox(width: tokens.spacing.x1),
          ],
          Flexible(
            child: UiText(
              label,
              variant: _textVariantFor(size),
              style: TextStyle(
                color: resolvedForeground,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: tokens.spacing.x1),
            IconTheme.merge(
              data: IconThemeData(
                color: resolvedForeground,
                size: _iconSizeFor(size),
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }

  /// Compact padding with enough vertical breathing room for the badge to
  /// read as a pill rather than highlighted inline text.
  ///
  /// Horizontal padding uses the same 4pt-step scale as the button, so
  /// a small badge next to a small button reads as a related pair.
  static EdgeInsets _paddingFor(UiSize size, UiThemeTokens t) {
    switch (size) {
      case UiSize.sm:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case UiSize.md:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 5);
      case UiSize.lg:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    }
  }

  static UiTextVariant _textVariantFor(UiSize size) {
    switch (size) {
      case UiSize.sm:
      case UiSize.md:
        return UiTextVariant.caption;
      case UiSize.lg:
        return UiTextVariant.label;
    }
  }

  static double _iconSizeFor(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 12;
      case UiSize.md:
        return 14;
      case UiSize.lg:
        return 16;
    }
  }
}
