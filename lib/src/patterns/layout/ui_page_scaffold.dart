import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_safe_viewport.dart';
import 'ui_system_bars.dart';

/// Preferred page shell: coordinates background, top/bottom bars, safe
/// viewport policy, and system bar syncing in a single widget.
///
/// Defaults are tuned for production use:
/// - Background comes from `UiThemeTokens.colors.background`.
/// - Scroll fade is enabled by default.
/// - Top and bottom system insets are moved into the faded body layer instead
///   of insetting the whole page.
/// - Status/navigation bar icons sync to the page background so they stay
///   legible when the theme flips between light and dark.
///
/// Wrap forms that present a keyboard in
/// `safeViewportMode: UiSafeViewportMode.keyboardAware` so the composer
/// stays above the keyboard without double-stacking the home-indicator
/// inset. Screens that do their own inset management can opt out with
/// `UiSafeViewportMode.none` and `syncSystemBars: false`.
class UiPageScaffold extends StatelessWidget {
  const UiPageScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomBar,
    this.backgroundColor,
    this.safeViewportMode = UiSafeViewportMode.none,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.systemOverlayStyle,
    this.syncSystemBars = true,
    this.leftSafeInset = true,
    this.rightSafeInset = true,
    this.showTopDivider = true,
    this.showBottomDivider = true,
    this.paintTopInsetWithTopBar = false,
    this.topInsetColor,
    this.scrollFade = true,
    this.scrollFadeExtent = 36,
    this.scrollFadeHorizontalInset = 18,
    this.scrollFadeMaxOpacity = 0.66,
    this.scrollFadeUsesSafeArea = true,
  });

  final Widget body;
  final Widget? topBar;
  final Widget? bottomBar;

  /// Page background. Defaults to `UiThemeTokens.colors.background`.
  final Color? backgroundColor;

  /// How insets are applied around [body]. See [UiSafeViewportMode].
  final UiSafeViewportMode safeViewportMode;

  /// Minimum inset enforced by the safe viewport even when the system
  /// reports zero padding (e.g. desktop / emulated devices).
  final EdgeInsets safeAreaMinimum;

  /// Explicit overlay style. Usually leave null and let [UiSystemBars]
  /// infer icon brightness from [backgroundColor].
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Install a [UiSystemBars] annotation above the scaffold. Default
  /// true — set false if an ancestor already owns system-bar styling.
  final bool syncSystemBars;

  final bool leftSafeInset;
  final bool rightSafeInset;

  /// Whether to draw a [UiDivider] between the top bar and the body.
  final bool showTopDivider;

  /// Whether to draw a [UiDivider] between the body and the bottom bar.
  final bool showBottomDivider;

  /// Paint the status-bar safe inset using a dedicated surface color,
  /// typically matching the top bar.
  final bool paintTopInsetWithTopBar;

  /// Color used when [paintTopInsetWithTopBar] is true.
  ///
  /// Defaults to [UiThemeTokens.colors.surface].
  final Color? topInsetColor;

  /// Applies a soft top/bottom edge mask to the page body.
  ///
  /// This is intended for pages whose scrollable content moves below floating
  /// chrome. Top/bottom bars are not masked.
  final bool scrollFade;

  /// Physical fade distance in logical pixels.
  final double scrollFadeExtent;

  /// Horizontal inset for the fade overlay so the edge treatment does not read
  /// as a full-width scrim.
  final double scrollFadeHorizontalInset;

  /// Maximum opacity used at the outer fade edge.
  final double scrollFadeMaxOpacity;

  /// Moves top/bottom safe-area padding into the faded body layer.
  ///
  /// Enabled by default so scroll-fade pages do not place scrollable content
  /// under hardware insets, while the fade still covers the protected edge.
  final bool scrollFadeUsesSafeArea;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final bg = backgroundColor ?? tokens.colors.background;

    // The background is painted full-bleed under system hardware. When scroll
    // fade is enabled, safe insets belong to the faded body layer instead of a
    // whole-page SafeArea, keeping floating chrome visually independent.
    final insetColor = topInsetColor ?? tokens.colors.surface;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    var effectiveSafeMode = paintTopInsetWithTopBar
        ? _withoutTopInset(safeViewportMode)
        : safeViewportMode;
    final consumeFadeTopInset = scrollFade &&
        scrollFadeUsesSafeArea &&
        topBar == null &&
        !paintTopInsetWithTopBar;
    final consumeFadeBottomInset =
        scrollFade && scrollFadeUsesSafeArea && bottomBar == null;
    if (consumeFadeTopInset && _usesTopInset(effectiveSafeMode)) {
      effectiveSafeMode = _withoutTopInset(effectiveSafeMode);
    }
    if (consumeFadeBottomInset && _usesBottomInset(effectiveSafeMode)) {
      effectiveSafeMode = _withoutBottomInset(effectiveSafeMode);
    }
    final scrollFadeSafePadding = EdgeInsets.only(
      top: consumeFadeTopInset ? _effectiveTopSafeInset(media) : 0,
      bottom: consumeFadeBottomInset
          ? _effectiveBottomSafeInset(media, safeViewportMode)
          : 0,
    );

    Widget content = Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (paintTopInsetWithTopBar && topInset > 0)
          UiBox(
            background: insetColor,
            width: double.infinity,
            height: topInset,
          ),
        if (topBar != null) topBar!,
        if (topBar != null && showTopDivider) const UiDivider(),
        Expanded(
          child: UiPageBodyInsets(
            insets: scrollFadeSafePadding,
            child: scrollFade
                ? _UiScrollFade(
                    extent: scrollFadeExtent,
                    horizontalInset: scrollFadeHorizontalInset,
                    maxOpacity: scrollFadeMaxOpacity,
                    backgroundColor: bg,
                    child: body,
                  )
                : body,
          ),
        ),
        if (bottomBar != null && showBottomDivider) const UiDivider(),
        if (bottomBar != null) bottomBar!,
      ],
    );

    content = UiSafeViewport(
      mode: effectiveSafeMode,
      left: leftSafeInset,
      right: rightSafeInset,
      minimum: safeAreaMinimum,
      child: content,
    );

    content = UiBox(
      background: bg,
      width: double.infinity,
      height: double.infinity,
      child: content,
    );

    if (syncSystemBars) {
      final barsColor = paintTopInsetWithTopBar ? insetColor : bg;
      content = UiSystemBars(
        style: systemOverlayStyle,
        backgroundColor: barsColor,
        child: content,
      );
    }

    return content;
  }

  UiSafeViewportMode _withoutTopInset(UiSafeViewportMode mode) {
    switch (mode) {
      case UiSafeViewportMode.none:
      case UiSafeViewportMode.bottom:
      case UiSafeViewportMode.keyboardAwareNoTop:
        return mode;
      case UiSafeViewportMode.top:
        return UiSafeViewportMode.none;
      case UiSafeViewportMode.all:
        return UiSafeViewportMode.bottom;
      case UiSafeViewportMode.keyboardAware:
        return UiSafeViewportMode.keyboardAwareNoTop;
    }
  }

  UiSafeViewportMode _withoutBottomInset(UiSafeViewportMode mode) {
    switch (mode) {
      case UiSafeViewportMode.none:
      case UiSafeViewportMode.top:
        return mode;
      case UiSafeViewportMode.bottom:
        return UiSafeViewportMode.none;
      case UiSafeViewportMode.all:
        return UiSafeViewportMode.top;
      case UiSafeViewportMode.keyboardAware:
        return UiSafeViewportMode.top;
      case UiSafeViewportMode.keyboardAwareNoTop:
        return UiSafeViewportMode.none;
    }
  }

  bool _usesTopInset(UiSafeViewportMode mode) {
    switch (mode) {
      case UiSafeViewportMode.top:
      case UiSafeViewportMode.all:
      case UiSafeViewportMode.keyboardAware:
        return true;
      case UiSafeViewportMode.none:
      case UiSafeViewportMode.bottom:
      case UiSafeViewportMode.keyboardAwareNoTop:
        return false;
    }
  }

  bool _usesBottomInset(UiSafeViewportMode mode) {
    switch (mode) {
      case UiSafeViewportMode.bottom:
      case UiSafeViewportMode.all:
      case UiSafeViewportMode.keyboardAware:
      case UiSafeViewportMode.keyboardAwareNoTop:
        return true;
      case UiSafeViewportMode.none:
      case UiSafeViewportMode.top:
        return false;
    }
  }

  double _effectiveTopSafeInset(MediaQueryData media) =>
      media.padding.top > safeAreaMinimum.top
          ? media.padding.top
          : safeAreaMinimum.top;

  double _effectiveBottomSafeInset(
    MediaQueryData media,
    UiSafeViewportMode mode,
  ) {
    final keyboardAware = mode == UiSafeViewportMode.keyboardAware ||
        mode == UiSafeViewportMode.keyboardAwareNoTop;
    final systemInset = keyboardAware && media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;
    return systemInset > safeAreaMinimum.bottom
        ? systemInset
        : safeAreaMinimum.bottom;
  }
}

/// Safe insets that page body scrollables should include in their content
/// padding when [UiPageScaffold.scrollFadeUsesSafeArea] is enabled.
///
/// The scaffold itself stays visually full-bleed. Scrollable page patterns use
/// these values to keep content clear of hardware insets while the fade remains
/// painted at the physical edges.
class UiPageBodyInsets extends InheritedWidget {
  const UiPageBodyInsets({
    super.key,
    required this.insets,
    required super.child,
  });

  final EdgeInsets insets;

  static EdgeInsets of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<UiPageBodyInsets>()
            ?.insets ??
        EdgeInsets.zero;
  }

  @override
  bool updateShouldNotify(UiPageBodyInsets oldWidget) {
    return insets != oldWidget.insets;
  }
}

class _UiScrollFade extends StatelessWidget {
  const _UiScrollFade({
    required this.child,
    required this.extent,
    required this.horizontalInset,
    required this.maxOpacity,
    required this.backgroundColor,
  });

  final Widget child;
  final double extent;
  final double horizontalInset;
  final double maxOpacity;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final edgeColor = backgroundColor.withValues(
      alpha: maxOpacity.clamp(0.0, 0.72),
    );
    final transparentEdgeColor = backgroundColor.withValues(alpha: 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        PositionedDirectional(
          start: horizontalInset,
          end: horizontalInset,
          top: 0,
          height: extent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [edgeColor, transparentEdgeColor],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: horizontalInset,
          end: horizontalInset,
          bottom: 0,
          height: extent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [edgeColor, transparentEdgeColor],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
