import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';

/// Applies a [SystemUiOverlayStyle] to the subtree via `AnnotatedRegion`.
///
/// ### When to pass [style] vs let it be inferred
///
/// - **Pass an explicit [style]** when the screen has a non-standard
///   look (e.g. a full-bleed image header) and auto-contrast from the
///   background luminance wouldn't match what the user actually sees.
/// - **Pass only [backgroundColor]** when the status-bar region sits on
///   a solid surface color — [UiSystemBars] picks icon brightness so the
///   OS icons stay legible on top of that surface.
/// - **Pass neither** to let [UiSystemBars] read the ambient
///   [UiThemeTokens.colors.background]. This is the right default for a
///   page that uses the theme's base surface.
class UiSystemBars extends StatelessWidget {
  const UiSystemBars({
    super.key,
    required this.child,
    this.style,
    this.backgroundColor,
  });

  final Widget child;

  /// Explicit overlay style. When provided it wins over inference.
  final SystemUiOverlayStyle? style;

  /// Background used to pick icon brightness when [style] is null. If
  /// also null, the surrounding [UiThemeTokens.colors.background] is
  /// used.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    SystemUiOverlayStyle resolved;
    if (style != null) {
      resolved = style!;
    } else {
      final bg =
          backgroundColor ?? UiThemeTokens.maybeOf(context)?.colors.background;
      resolved = UiSystemBarsStyle.inferFromBackground(bg);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: resolved,
      child: child,
    );
  }
}

/// Helpers for building [SystemUiOverlayStyle] values from a background
/// color. Exposed so consumers can cache/reuse the result when they need
/// the raw style object (e.g. to pass into an external `AnnotatedRegion`).
class UiSystemBarsStyle {
  const UiSystemBarsStyle._();

  /// Icon brightnesses flip to stay legible on top of [color]. Semi- and
  /// fully-transparent colors fall back to the light-surface style since
  /// we cannot know what the user sees behind them.
  static SystemUiOverlayStyle inferFromBackground(Color? color) {
    if (color == null || color.a < 0.5) return light;
    return color.computeLuminance() < 0.42 ? dark : light;
  }

  /// Icons optimized for a light surface (dark icons).
  static const SystemUiOverlayStyle light = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0x00000000),
  );

  /// Icons optimized for a dark surface (light icons).
  static const SystemUiOverlayStyle dark = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0x00000000),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Color(0x00000000),
  );
}
