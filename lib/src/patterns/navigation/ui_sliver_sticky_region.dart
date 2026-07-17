import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../foundation/layout/ui_navigation_chrome_scope.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Surface treatment for [UiSliverStickyRegion].
enum UiStickyRegionSurface {
  /// Glass without a rail and a quiet solid page surface beside a rail.
  adaptive,

  /// Translucent tint with backdrop blur.
  glass,

  /// Opaque page-background surface.
  solid,

  /// No painted surface. Best for non-overlapping or floating content.
  transparent,
}

/// A fixed-height page utility that pins as its content scrolls underneath.
///
/// Use this for search, filters, segmented controls, and other controls that
/// must remain reachable after the page title scrolls. The optional trailing
/// fade replaces the need for a permanent separator in most layouts.
///
/// Place it directly after `UiSliverNavigationBar`. On pages wrapped by
/// `UiPageScaffold`, set `scrollFadeTop: false` so this region owns the single
/// top-to-content transition. Keep [showSeparator] false unless the control
/// needs a hard visual boundary; the default fade is the preferred treatment.
class UiSliverStickyRegion extends StatelessWidget {
  const UiSliverStickyRegion({
    super.key,
    required this.extent,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.surface = UiStickyRegionSurface.adaptive,
    this.blurSigma = 12,
    this.showSeparator = false,
    this.fadeExtent = 16,
    this.fadeMaxOpacity = 0.72,
    this.pinned = true,
    this.floating = false,
    this.useSafeArea = true,
  })  : assert(extent > 0),
        assert(blurSigma >= 0),
        assert(fadeExtent >= 0),
        assert(fadeMaxOpacity >= 0 && fadeMaxOpacity <= 1);

  /// Height of the control surface, excluding [fadeExtent].
  final double extent;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final UiStickyRegionSurface surface;
  final double blurSigma;
  final bool showSeparator;

  /// Height of the soft transition painted beneath the control surface.
  /// Set to zero to disable it.
  final double fadeExtent;
  final double fadeMaxOpacity;
  final bool pinned;
  final bool floating;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _UiStickyRegionDelegate(
        extent: extent,
        child: child,
        padding: padding,
        surface: surface,
        blurSigma: blurSigma,
        showSeparator: showSeparator,
        fadeExtent: fadeExtent,
        fadeMaxOpacity: fadeMaxOpacity,
        useSafeArea: useSafeArea,
      ),
    );
  }
}

class _UiStickyRegionDelegate extends SliverPersistentHeaderDelegate {
  const _UiStickyRegionDelegate({
    required this.extent,
    required this.child,
    required this.padding,
    required this.surface,
    required this.blurSigma,
    required this.showSeparator,
    required this.fadeExtent,
    required this.fadeMaxOpacity,
    required this.useSafeArea,
  });

  final double extent;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final UiStickyRegionSurface surface;
  final double blurSigma;
  final bool showSeparator;
  final double fadeExtent;
  final double fadeMaxOpacity;
  final bool useSafeArea;

  @override
  double get minExtent => extent + fadeExtent;

  @override
  double get maxExtent => extent + fadeExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final hasRail = UiNavigationChromeScope.hasPersistentRailOf(context);
    final resolvedSurface = surface == UiStickyRegionSurface.adaptive
        ? hasRail
            ? UiStickyRegionSurface.solid
            : UiStickyRegionSurface.glass
        : surface;
    final activated = overlapsContent || shrinkOffset > 0;
    final surfaceColor = switch (resolvedSurface) {
      UiStickyRegionSurface.adaptive => colors.background,
      UiStickyRegionSurface.glass => colors.surface.withValues(
          alpha: activated
              ? tokens.brightness == Brightness.dark
                  ? 0.78
                  : 0.72
              : 0.14,
        ),
      UiStickyRegionSurface.solid => colors.background,
      UiStickyRegionSurface.transparent => const Color(0x00000000),
    };
    final transitionColor = switch (resolvedSurface) {
      UiStickyRegionSurface.glass => colors.surface,
      UiStickyRegionSurface.adaptive ||
      UiStickyRegionSurface.solid ||
      UiStickyRegionSurface.transparent =>
        colors.background,
    };
    final separatorColor = showSeparator && activated
        ? colors.border
        : colors.border.withValues(alpha: 0);

    Widget control = AnimatedContainer(
      key: const Key('ui_sliver_sticky_region_surface'),
      duration: tokens.motion.standard,
      curve: tokens.motion.standardCurve,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: separatorColor)),
      ),
      padding: padding,
      child: child,
    );

    if (resolvedSurface == UiStickyRegionSurface.glass && blurSigma > 0) {
      control = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: control,
        ),
      );
    }

    if (useSafeArea) {
      control = SafeArea(top: false, bottom: false, child: control);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: 0, left: 0, right: 0, height: extent, child: control),
        if (fadeExtent > 0)
          Positioned(
            key: const Key('ui_sliver_sticky_region_fade'),
            top: extent,
            left: 0,
            right: 0,
            height: fadeExtent,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: activated ? 1 : 0,
                duration: tokens.motion.standard,
                curve: tokens.motion.standardCurve,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        transitionColor.withValues(alpha: fadeMaxOpacity),
                        transitionColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _UiStickyRegionDelegate oldDelegate) {
    return oldDelegate.extent != extent ||
        oldDelegate.child != child ||
        oldDelegate.padding != padding ||
        oldDelegate.surface != surface ||
        oldDelegate.blurSigma != blurSigma ||
        oldDelegate.showSeparator != showSeparator ||
        oldDelegate.fadeExtent != fadeExtent ||
        oldDelegate.fadeMaxOpacity != fadeMaxOpacity ||
        oldDelegate.useSafeArea != useSafeArea;
  }
}
