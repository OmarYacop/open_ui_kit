import 'dart:ui';

/// Raw, context-free colors for media chrome and data visualization.
/// Prefer semantic `UiThemeTokens.colorsOf(context)` values for UI surfaces.
abstract final class UiPalette {
  static const transparent = Color(0x00000000);
  static const black = Color(0xFF000000);
  static const black54 = Color(0x8A000000);
  static const black87 = Color(0xDE000000);
  static const white = Color(0xFFFFFFFF);
  static const white54 = Color(0x8AFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const grey = Color(0xFF9E9E9E);
  static const red = Color(0xFFF44336);
  static const orange = Color(0xFFFF9800);
  static const green = Color(0xFF4CAF50);
  static const blue = Color(0xFF2196F3);
  static const purple = Color(0xFF9C27B0);
}
