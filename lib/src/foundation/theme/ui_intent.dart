import 'package:flutter/widgets.dart';

import '../tokens/ui_color_tokens.dart';

/// Semantic emphasis shared by intent-aware UI components.
///
/// Components may interpret [defaultIntent] differently. For example, buttons
/// use a primary default while passive status surfaces use a neutral default.
enum UiIntent {
  defaultIntent,
  neutral,
  primary,
  secondary,
  destructive,
  danger,
  ghost,
  link,
}

/// Rest-state colors shared by intent-aware surfaces.
///
/// Interaction states such as hover, press, and disabled remain owned by each
/// component because those states are behavioral rather than purely semantic.
@immutable
class UiIntentPalette {
  const UiIntentPalette({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;

  /// Resolves the rest-state colors for [intent] from [colors].
  static UiIntentPalette rest(UiIntent intent, UiColorTokens colors) {
    final isDarkTheme = colors.background.computeLuminance() < 0.2;

    switch (intent) {
      case UiIntent.primary:
        return UiIntentPalette(
          background: colors.primary,
          foreground: colors.onPrimary,
        );
      case UiIntent.secondary:
        return UiIntentPalette(
          background: colors.secondary,
          foreground: colors.onSecondary,
          border: colors.border,
        );
      case UiIntent.destructive:
      case UiIntent.danger:
        return UiIntentPalette(
          background: colors.danger.withValues(
            alpha: isDarkTheme ? 0.18 : 0.10,
          ),
          foreground: colors.danger,
        );
      case UiIntent.ghost:
        return UiIntentPalette(
          background: const Color(0x00000000),
          foreground: colors.accentForeground,
        );
      case UiIntent.link:
        return UiIntentPalette(
          background: const Color(0x00000000),
          foreground: colors.primary,
        );
      case UiIntent.neutral:
      case UiIntent.defaultIntent:
        if (isDarkTheme) {
          return UiIntentPalette(
            background: colors.surface.withValues(alpha: 0.62),
            foreground: Color.lerp(
              colors.mutedForeground,
              colors.foreground,
              0.55,
            )!,
            border: colors.borderStrong.withValues(alpha: 0.9),
          );
        }
        return UiIntentPalette(
          background: colors.surface,
          foreground: colors.foreground,
          border: colors.border,
        );
    }
  }
}
