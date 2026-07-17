import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Semantic color tokens.
///
/// Neutral by default (surfaces, borders, text). Brand colors are only
/// surfaced through intent tokens (`primary`, `secondary`, `danger`).
@immutable
class UiColorTokens {
  const UiColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceInverse,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.textInverse,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.danger,
    required this.onDanger,
    required this.success,
    required this.warning,
    required this.focusRing,
    required this.overlay,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceInverse;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textMuted;
  final Color textInverse;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color danger;
  final Color onDanger;
  final Color success;
  final Color warning;
  final Color focusRing;
  final Color overlay;

  /// Shadcn-style semantic aliases. Existing Open UI Kit names stay available,
  /// while newer components can depend on role-based surface tokens.
  Color get foreground => textPrimary;
  Color get card => surface;
  Color get cardForeground => textPrimary;
  Color get popover => surface;
  Color get popoverForeground => textPrimary;
  Color get muted => surfaceMuted;
  Color get mutedForeground => textMuted;
  Color get accent => surfaceMuted;
  Color get accentForeground => textPrimary;
  Color get input => border;
  Color get ring => focusRing;
  Color get primaryForeground => onPrimary;
  Color get secondaryForeground => onSecondary;
  Color get destructive => danger;
  Color get destructiveForeground => onDanger;

  static const UiColorTokens light = UiColorTokens(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    surfaceInverse: Color(0xFF0A0A0A),
    border: Color(0xFFE5E5E5),
    borderStrong: Color(0xFFD4D4D4),
    textPrimary: Color(0xFF0A0A0A),
    textMuted: Color(0xFF737373),
    textInverse: Color(0xFFFAFAFA),
    primary: Color(0xFF0A0A0A),
    onPrimary: Color(0xFFFAFAFA),
    secondary: Color(0xFFF5F5F5),
    onSecondary: Color(0xFF0A0A0A),
    danger: Color(0xFFDC2626),
    onDanger: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    focusRing: Color(0xFF0A0A0A),
    overlay: Color(0x99000000),
  );

  static const UiColorTokens dark = UiColorTokens(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF171717),
    surfaceMuted: Color(0xFF262626),
    surfaceInverse: Color(0xFFFAFAFA),
    border: Color(0xFF262626),
    borderStrong: Color(0xFF404040),
    textPrimary: Color(0xFFFAFAFA),
    textMuted: Color(0xFFA3A3A3),
    textInverse: Color(0xFF0A0A0A),
    primary: Color(0xFFFAFAFA),
    onPrimary: Color(0xFF0A0A0A),
    secondary: Color(0xFF262626),
    onSecondary: Color(0xFFFAFAFA),
    danger: Color(0xFFEF4444),
    onDanger: Color(0xFFFAFAFA),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    focusRing: Color(0xFFD4D4D4),
    overlay: Color(0xB3000000),
  );

  UiColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceInverse,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textMuted,
    Color? textInverse,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? danger,
    Color? onDanger,
    Color? success,
    Color? warning,
    Color? focusRing,
    Color? overlay,
  }) {
    return UiColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceInverse: surfaceInverse ?? this.surfaceInverse,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      focusRing: focusRing ?? this.focusRing,
      overlay: overlay ?? this.overlay,
    );
  }

  static UiColorTokens lerp(UiColorTokens a, UiColorTokens b, double t) {
    return UiColorTokens(
      background: Color.lerp(a.background, b.background, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceMuted: Color.lerp(a.surfaceMuted, b.surfaceMuted, t)!,
      surfaceInverse: Color.lerp(a.surfaceInverse, b.surfaceInverse, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textMuted: Color.lerp(a.textMuted, b.textMuted, t)!,
      textInverse: Color.lerp(a.textInverse, b.textInverse, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      onSecondary: Color.lerp(a.onSecondary, b.onSecondary, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      onDanger: Color.lerp(a.onDanger, b.onDanger, t)!,
      success: Color.lerp(a.success, b.success, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      focusRing: Color.lerp(a.focusRing, b.focusRing, t)!,
      overlay: Color.lerp(a.overlay, b.overlay, t)!,
    );
  }
}
