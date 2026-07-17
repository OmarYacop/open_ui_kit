import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_system_bars.dart';

/// Visually-scoped surface region.
///
/// Useful for full-bleed headers or any section whose background
/// temporarily replaces the page surface (e.g. a dark hero on top of a
/// light page). When [syncSystemBars] is true, the region also pushes a
/// matching [UiSystemBars] annotation — the system icons flip to stay
/// legible as long as this region sits under the status bar.
///
/// Prefer [UiPageScaffold] for page-wide surface + system-bar control;
/// keep [UiSurfaceRegion] for sectional use.
class UiSurfaceRegion extends StatelessWidget {
  const UiSurfaceRegion({
    super.key,
    required this.child,
    this.background,
    this.padding,
    this.border,
    this.borderRadius,
    this.systemOverlayStyle,
    this.syncSystemBars = false,
  });

  final Widget child;

  /// Surface color. Defaults to `UiThemeTokens.colors.surface`.
  final Color? background;

  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final BorderRadius? borderRadius;

  /// Explicit overlay style; only used when [syncSystemBars] is true.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Publish a [UiSystemBars] annotation so the OS status/navigation
  /// icons flip contrast against [background].
  final bool syncSystemBars;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final bg = background ?? tokens.colors.surface;

    Widget content = UiBox(
      background: bg,
      border: border,
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );

    if (syncSystemBars) {
      content = UiSystemBars(
        style: systemOverlayStyle,
        backgroundColor: bg,
        child: content,
      );
    }

    return content;
  }
}
