import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/overlay/ui_layered_overlay.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/layout/ui_keyboard_geometry.dart';
import 'ui_safe_viewport.dart';
import 'ui_scroll_edge_fade.dart';
import 'ui_system_bars.dart';

/// Preferred page shell: coordinates background, top/bottom bars, safe
/// viewport policy, and system bar syncing in a single widget.
///
/// Defaults are tuned for production use:
/// - Background comes from `UiThemeTokens.colors.background`.
/// - Scroll fade is enabled by default.
/// - Top and bottom system insets are moved into the faded body layer so the
///   page remains vertically edge-to-edge.
/// - Left and right system insets remain physical safe-area padding for
///   landscape notches and rounded display corners.
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
    this.safeViewportMode = UiSafeViewportMode.all,
    this.safeAreaMinimum = EdgeInsets.zero,
    this.systemOverlayStyle,
    this.syncSystemBars = true,
    this.leftSafeInset = true,
    this.rightSafeInset = true,
    this.showTopDivider = false,
    this.showBottomDivider = false,
    this.paintTopInsetWithTopBar = false,
    this.topInsetColor,
    this.scrollFade = true,
    this.scrollFadeBackgroundColor,
    this.scrollFadeTop = true,
    this.scrollFadeBottom = true,
    this.scrollFadeExtent = 128,
    this.scrollFadeWideExtent = 72,
    this.scrollFadeBottomExtent = 48,
    this.scrollFadeHorizontalInset = 0,
    this.scrollFadeMaxOpacity = 0.74,
    this.scrollFadeUsesSafeArea = true,
    this.resizeBodyForKeyboard = false,
  });

  final Widget body;
  final Widget? topBar;
  final Widget? bottomBar;

  /// Page background. Defaults to `UiThemeTokens.colors.background`.
  final Color? backgroundColor;

  /// How insets are applied around [body]. Defaults to
  /// [UiSafeViewportMode.all]. See [UiSafeViewportMode].
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
  /// Defaults to the ambient [UiThemeTokens] `colors.surface` value.
  final Color? topInsetColor;

  /// Applies a soft top/bottom edge mask to the page body.
  ///
  /// This is intended for pages whose scrollable content moves below floating
  /// chrome. Top/bottom bars are not masked.
  final bool scrollFade;

  /// Surface color sampled by the edge fade.
  ///
  /// Defaults to [backgroundColor]. Set this when the page layer itself is
  /// transparent but the fade should match an opaque surface behind it.
  final Color? scrollFadeBackgroundColor;

  /// Paint the fade at the top edge of [body]. Disable this when an in-scroll
  /// sticky region owns the transition into scrolling content.
  final bool scrollFadeTop;

  /// Paint the fade at the bottom edge of [body].
  final bool scrollFadeBottom;

  /// Physical fade distance in logical pixels.
  final double scrollFadeExtent;

  /// Top fade distance used on tablet and desktop viewports.
  ///
  /// A shorter wide-screen fade prevents large navigation titles from veiling
  /// the first content row after a persistent rail reduces the content pane.
  final double scrollFadeWideExtent;

  /// Physical fade distance at the bottom edge. Kept shorter than the top by
  /// default so resting content is not unnecessarily veiled.
  final double scrollFadeBottomExtent;

  /// Optional horizontal inset for the fade overlay.
  ///
  /// Defaults to zero so the edge treatment spans the full page width,
  /// including horizontal safe-area padding.
  final double scrollFadeHorizontalInset;

  /// Maximum opacity used at the outer fade edge.
  final double scrollFadeMaxOpacity;

  /// Moves top/bottom safe-area padding into the faded body layer.
  ///
  /// Enabled by default so the page surface and fade remain vertically
  /// edge-to-edge. Scrollables with explicit content padding should add
  /// [UiPageBodyInsets] to keep resting content clear of system hardware.
  /// Set this to false when an arbitrary body needs a physical top/bottom
  /// [UiSafeViewport] instead.
  final bool scrollFadeUsesSafeArea;

  /// Reduces the body's layout height by the live keyboard inset.
  ///
  /// This is useful for search and selection pages whose centered empty state
  /// should remain centered in the visible area above the keyboard. Leave it
  /// disabled for pages that already use [UiKeyboardDock] or otherwise own
  /// their keyboard geometry.
  final bool resizeBodyForKeyboard;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final bg = backgroundColor ?? tokens.colors.background;
    final effectiveTopFadeExtent =
        MediaQuery.sizeOf(context).shortestSide >= 600
            ? scrollFadeWideExtent
            : scrollFadeExtent;

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
        !paintTopInsetWithTopBar &&
        _usesTopInset(effectiveSafeMode);
    final consumeFadeBottomInset = scrollFade &&
        scrollFadeUsesSafeArea &&
        bottomBar == null &&
        _usesBottomInset(effectiveSafeMode);
    if (consumeFadeTopInset) {
      effectiveSafeMode = _withoutTopInset(effectiveSafeMode);
    }
    if (consumeFadeBottomInset) {
      effectiveSafeMode = _withoutBottomInset(effectiveSafeMode);
    }
    final scrollFadeSafePadding = EdgeInsets.only(
      top: consumeFadeTopInset ? _effectiveTopSafeInset(media) : 0,
      bottom: consumeFadeBottomInset
          ? _effectiveBottomSafeInset(context, media, safeViewportMode)
          : 0,
    );

    Widget pageBody = UiPageBodyInsets(
      insets: scrollFadeSafePadding,
      child: scrollFade
          ? UiScrollEdgeFade(
              extent: effectiveTopFadeExtent,
              bottomExtent: scrollFadeBottomExtent,
              horizontalInset: scrollFadeHorizontalInset,
              maxOpacity: scrollFadeMaxOpacity,
              backgroundColor: scrollFadeBackgroundColor ?? bg,
              showTop: scrollFadeTop,
              showBottom: scrollFadeBottom,
              child: body,
            )
          : body,
    );
    if (resizeBodyForKeyboard) {
      pageBody = Padding(
        padding: EdgeInsets.only(
          bottom: UiKeyboardGeometry.currentInsetOf(context),
        ),
        child: pageBody,
      );
    }

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
        Expanded(child: pageBody),
        if (bottomBar != null && showBottomDivider) const UiDivider(),
        if (bottomBar != null) bottomBar!,
      ],
    );

    // Moving both vertical insets into UiPageBodyInsets can reduce the
    // effective vertical mode to `none`. Preserve the original mode's
    // horizontal contract so landscape notches remain protected.
    final needsHorizontalSafeViewport =
        effectiveSafeMode == UiSafeViewportMode.none &&
            safeViewportMode != UiSafeViewportMode.none &&
            (leftSafeInset || rightSafeInset);
    if (needsHorizontalSafeViewport) {
      content = SafeArea(
        top: false,
        bottom: false,
        left: leftSafeInset,
        right: rightSafeInset,
        minimum: EdgeInsets.only(
          left: safeAreaMinimum.left,
          right: safeAreaMinimum.right,
        ),
        child: content,
      );
    } else {
      content = UiSafeViewport(
        mode: effectiveSafeMode,
        left: leftSafeInset,
        right: rightSafeInset,
        minimum: safeAreaMinimum,
        child: content,
      );
    }

    content = UiBox(
      background: bg,
      width: double.infinity,
      height: double.infinity,
      child: UiLayeredOverlayHost(child: content),
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
    BuildContext context,
    MediaQueryData media,
    UiSafeViewportMode mode,
  ) {
    final keyboardAware = mode == UiSafeViewportMode.keyboardAware ||
        mode == UiSafeViewportMode.keyboardAwareNoTop;
    final keyboardInset = UiKeyboardGeometry.currentInsetOf(context);
    final systemInset = keyboardAware && keyboardInset > 0
        ? keyboardInset
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
enum UiPageBodyInsetsAspect { top, right, bottom, left }

class UiPageBodyInsets extends InheritedModel<UiPageBodyInsetsAspect> {
  const UiPageBodyInsets({
    super.key,
    required this.insets,
    required super.child,
  });

  final EdgeInsets insets;

  static EdgeInsets of(BuildContext context) {
    return InheritedModel.inheritFrom<UiPageBodyInsets>(context)?.insets ??
        EdgeInsets.zero;
  }

  static double topOf(BuildContext context) =>
      _of(context, UiPageBodyInsetsAspect.top).top;

  static double rightOf(BuildContext context) =>
      _of(context, UiPageBodyInsetsAspect.right).right;

  static double bottomOf(BuildContext context) =>
      _of(context, UiPageBodyInsetsAspect.bottom).bottom;

  static double leftOf(BuildContext context) =>
      _of(context, UiPageBodyInsetsAspect.left).left;

  static EdgeInsets _of(
    BuildContext context,
    UiPageBodyInsetsAspect aspect,
  ) {
    return InheritedModel.inheritFrom<UiPageBodyInsets>(
          context,
          aspect: aspect,
        )?.insets ??
        EdgeInsets.zero;
  }

  @override
  bool updateShouldNotify(UiPageBodyInsets oldWidget) {
    return insets != oldWidget.insets;
  }

  @override
  bool updateShouldNotifyDependent(
    UiPageBodyInsets oldWidget,
    Set<UiPageBodyInsetsAspect> dependencies,
  ) {
    final old = oldWidget.insets;
    return dependencies.any(
      (aspect) => switch (aspect) {
        UiPageBodyInsetsAspect.top => insets.top != old.top,
        UiPageBodyInsetsAspect.right => insets.right != old.right,
        UiPageBodyInsetsAspect.bottom => insets.bottom != old.bottom,
        UiPageBodyInsetsAspect.left => insets.left != old.left,
      },
    );
  }
}
