import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/layout/ui_navigation_chrome_scope.dart';
import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../layout/ui_system_bars.dart';
import 'ui_navigation_back_button.dart';
import 'ui_navigation_scope.dart';
import 'ui_navigation_spec.dart';
import 'ui_route_entry.dart';

/// Sliver-based navigation bar with large-title collapse behavior.
///
/// Drop into any `CustomScrollView` slivers list. Keep body spacing in the
/// following content sliver (for example, with [SliverPadding] or a
/// [SliverToBoxAdapter]). The navigation bar deliberately owns one sliver so
/// its pinned extent is not bounded by a short [SliverMainAxisGroup].
///
/// Height budgets:
///
/// - Collapsed: [collapsedHeight] + ambient `MediaQuery.padding.top`.
/// - Expanded: [expandedHeight] + ambient `MediaQuery.padding.top`.
///
/// When [UiNavigationSpec.largeTitle] is `false`, the bar pins at the
/// collapsed height only — useful for pages without overscrolling
/// content (e.g. forms, dialogs).
///
/// Visual treatment (blur/tint/divider) is driven by the spec so one
/// screen declaration controls both chrome and content.
class UiSliverNavigationBar extends StatelessWidget {
  const UiSliverNavigationBar({
    super.key,
    required this.spec,
    this.expandedHeight = 88,
    this.collapsedHeight = 52,
    this.pinned = true,
    this.floating = false,
    this.stretch = false,
    this.adaptToPersistentRail = true,
  });

  final UiNavigationSpec spec;

  /// Content height when fully expanded (excludes the top safe-area
  /// inset). Ignored when [UiNavigationSpec.largeTitle] is false.
  final double expandedHeight;

  /// Content height when fully collapsed (excludes the top safe-area
  /// inset).
  final double collapsedHeight;

  final bool pinned;
  final bool floating;
  final bool stretch;

  /// Replaces the mobile glass treatment with a non-pinned content header
  /// when the page is hosted next to a persistent navigation rail.
  final bool adaptToPersistentRail;

  @override
  Widget build(BuildContext context) {
    final hasPersistentRail = adaptToPersistentRail &&
        UiNavigationChromeScope.hasPersistentRailOf(context);
    final formFactor = uiFormFactorOf(context);
    final isDesktop = formFactor == UiFormFactor.desktop;
    final useQuietPageHeader = spec.largeTitle &&
        spec.back == null &&
        (hasPersistentRail || isDesktop);
    if (useQuietPageHeader) {
      return SliverToBoxAdapter(child: _RailPageHeader(spec: spec));
    }

    final effectiveSpec = (hasPersistentRail || isDesktop)
        ? spec.copyWith(
            surface: UiNavigationSurface.solid,
            blurSigma: 0,
            showDivider: false,
          )
        : spec;
    final topInset = MediaQuery.paddingOf(context).top;
    // Back-button pages skip the expanded form entirely: the bar pins at
    // collapsed height so back + title + actions sit together on a
    // single row, with no large-title reveal on overscroll.
    final useLarge = effectiveSpec.largeTitle && effectiveSpec.back == null;
    final maxH = (useLarge ? expandedHeight : collapsedHeight) + topInset;
    final minH = collapsedHeight + topInset;

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _UiNavHeaderDelegate(
        spec: effectiveSpec,
        topInset: topInset,
        expandedHeight: maxH,
        collapsedHeight: minH,
      ),
    );
  }
}

class _RailPageHeader extends StatelessWidget {
  const _RailPageHeader({required this.spec});

  final UiNavigationSpec spec;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactPane = constraints.maxWidth < 520;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.x4,
              compactPane ? tokens.spacing.x4 : tokens.spacing.x6,
              tokens.spacing.x4,
              tokens.spacing.x4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spec.leading != null) ...[
                  spec.leading!,
                  SizedBox(width: tokens.spacing.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UiText(
                        spec.title,
                        variant: compactPane
                            ? UiTextVariant.heading
                            : UiTextVariant.displayMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spec.subtitle != null &&
                          spec.subtitle!.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.x1),
                        UiText(
                          spec.subtitle!,
                          variant: UiTextVariant.bodySm,
                          tone: UiTextTone.muted,
                          maxLines: compactPane ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (spec.actions.isNotEmpty) ...[
                  SizedBox(width: tokens.spacing.x3),
                  Wrap(
                    spacing: tokens.spacing.x2,
                    runSpacing: tokens.spacing.x2,
                    alignment: WrapAlignment.end,
                    children: spec.actions,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UiNavHeaderDelegate extends SliverPersistentHeaderDelegate {
  _UiNavHeaderDelegate({
    required this.spec,
    required this.topInset,
    required this.expandedHeight,
    required this.collapsedHeight,
  });

  final UiNavigationSpec spec;
  final double topInset;
  final double expandedHeight;
  final double collapsedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final delta = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = (shrinkOffset / delta).clamp(0.0, 1.0);
    final resolvedSurface = _resolveSurface(context);

    final surfaceColor = _surfaceColor(
      c.surface,
      t,
      surface: resolvedSurface,
      overlapsContent: overlapsContent,
    );
    final showBlur =
        resolvedSurface == UiNavigationSurface.blurred && spec.blurSigma > 0;
    final dividerOpacity =
        spec.showDivider ? (overlapsContent ? 1.0 : _dividerOpacity(t)) : 0.0;
    final useHero = spec.largeTitle && spec.back == null;
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: minExtent - topInset,
          child: _CompactRow(
            spec: spec,
            collapseT: t,
            showTitle: !useHero,
          ),
        ),
        if (useHero)
          // _ShrinkingTitle uses Positioned internally, which requires
          // a direct Stack parent — so the RepaintBoundary lives
          // *inside* the Positioned, not around it.
          _ShrinkingTitle(
            spec: spec,
            collapseT: t,
            topInset: topInset,
            collapsedBarHeight: minExtent - topInset,
            expandedHeight: maxExtent,
          ),
      ],
    );

    // Surface color *and* divider color both depend on `overlapsContent`,
    // which flips in a single frame the moment content scrolls under
    // the pinned bar. Tween the decoration so neither layer pops in —
    // the divider fade reads as a soft reveal instead of a hard edge.
    content = AnimatedContainer(
      duration: tokens.motion.standard,
      curve: tokens.motion.standardCurve,
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: c.border.withValues(alpha: dividerOpacity),
            width: 1,
          ),
        ),
      ),
      child: content,
    );

    if (showBlur) {
      // Frosted-glass treatment: keep blur present across scroll states,
      // then slightly intensify as the bar collapses.
      final sigma = 8 + (spec.blurSigma - 8).clamp(0.0, double.infinity) * t;
      content = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              IgnorePointer(
                child: AnimatedContainer(
                  duration: tokens.motion.standard,
                  curve: tokens.motion.standardCurve,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.textPrimary.withValues(
                          alpha: overlapsContent ? 0.045 : 0.018,
                        ),
                        c.textPrimary.withValues(
                          alpha: overlapsContent ? 0.012 : 0.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Publish a system-bar annotation scoped to the bar's pinned region
    // so the OS status icons contrast against *this* surface even when
    // the page background differs (dark hero over a light page, etc.).
    final overlaySample = surfaceColor.withValues(alpha: 1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiSystemBarsStyle.inferFromBackground(overlaySample),
      child: content,
    );
  }

  Color _surfaceColor(
    Color base,
    double t, {
    required UiNavigationSurface surface,
    required bool overlapsContent,
  }) {
    switch (surface) {
      case UiNavigationSurface.adaptive:
        // `adaptive` is normalized by _resolveSurface before this path.
        return base;
      case UiNavigationSurface.solid:
        return base;
      case UiNavigationSurface.blurred:
        final alpha = overlapsContent
            ? (0.1 + math.pow(t, 0.7) * 0.28).clamp(0.0, 1.0)
            : (math.pow(t, 2.3) * 0.1).clamp(0.0, 1.0);
        return base.withValues(alpha: alpha.clamp(0.0, 1.0));
      case UiNavigationSurface.transparent:
        return const Color(0x00000000);
    }
  }

  UiNavigationSurface _resolveSurface(BuildContext context) {
    if (spec.surface != UiNavigationSurface.adaptive) return spec.surface;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? UiNavigationSurface.blurred
        : UiNavigationSurface.solid;
  }

  double _dividerOpacity(double t) {
    // Keep divider nearly absent until close to collapse, then ramp fast.
    final normalized = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
    return math.pow(normalized, 3).toDouble() * 0.95;
  }

  @override
  bool shouldRebuild(covariant _UiNavHeaderDelegate old) {
    return old.spec != spec ||
        old.topInset != topInset ||
        old.expandedHeight != expandedHeight ||
        old.collapsedHeight != collapsedHeight;
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.spec,
    required this.collapseT,
    required this.showTitle,
  });

  final UiNavigationSpec spec;
  final double collapseT;

  /// When false, the middle slot is rendered empty so a sibling
  /// shrinking-title overlay can occupy the title position without
  /// clashing with a second title widget.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final brightness = Theme.of(context).brightness;
    final resolvedLogo = spec.brand?.resolveLogo(brightness);
    final showMiddle = showTitle || resolvedLogo != null;
    final runtime = UiNavigationControllerScope.maybeOf(context);
    final runtimeHistory = runtime?.controller.historyItems() ?? const [];
    final configuredHistory = spec.back?.history ?? const [];
    final resolvedHistory =
        configuredHistory.isNotEmpty ? configuredHistory : runtimeHistory;
    final strings = UiLocalizations.of(context);
    final resolvedBackLabel = spec.back?.label ??
        (resolvedHistory.isNotEmpty
            ? resolvedHistory.first.title
            : strings.back);
    final seededHistory = (spec.back?.label != null &&
            resolvedHistory.every((item) => item.title != spec.back!.label))
        ? <UiNavigationBackHistoryItem>[
            UiNavigationBackHistoryItem(title: spec.back!.label!),
            ...resolvedHistory,
          ]
        : resolvedHistory;

    void onHistorySelected(UiNavigationBackHistoryItem item) {
      final custom = spec.back?.onHistorySelected;
      if (custom != null) {
        custom(item);
        return;
      }
      final controller = runtime?.controller;
      if (controller != null && item.value is UiRouteEntry) {
        controller.popTo(item.value as UiRouteEntry);
        return;
      }
      spec.back?.onPressed();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x3),
      child: NavigationToolbar(
        centerMiddle: true,
        middleSpacing: tokens.spacing.x2,
        leading: spec.back != null
            ? AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: UiNavigationBackButton(
                  key: ValueKey('back:$resolvedBackLabel'),
                  label: resolvedBackLabel,
                  onPressed: spec.back!.onPressed,
                  history: seededHistory,
                  onHistorySelected: onHistorySelected,
                ),
              )
            : spec.leading,
        trailing: spec.actions.isEmpty
            ? null
            : AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: Row(
                  key: ValueKey('actions:${Object.hashAll(spec.actions)}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < spec.actions.length; i++) ...[
                      if (i > 0) SizedBox(width: tokens.spacing.x2),
                      spec.actions[i],
                    ],
                  ],
                ),
              ),
        middle: showMiddle
            ? AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: Row(
                  key: ValueKey(
                    'titlegroup:${spec.title}|${spec.subtitle ?? ''}|${spec.brand?.displayName ?? ''}',
                  ),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (resolvedLogo != null) ...[
                      Flexible(
                        child: Semantics(
                          container: true,
                          label: '${spec.brand!.displayName} logo',
                          child: ExcludeSemantics(child: resolvedLogo),
                        ),
                      ),
                      if (showTitle) SizedBox(width: tokens.spacing.x2),
                    ],
                    if (showTitle)
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UiText(
                              spec.title,
                              variant: UiTextVariant.heading,
                              style: TextStyle(color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            if (spec.subtitle != null && spec.back == null)
                              UiText(
                                spec.subtitle!,
                                variant: UiTextVariant.caption,
                                tone: UiTextTone.muted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  static Widget _chromeTransition(Widget child, Animation<double> animation) {
    return UiSlideFadeTransition(
      animation: animation,
      beginOffset: const Offset(0.08, 0),
      child: child,
    );
  }
}

/// Single title that smoothly shrinks and re-positions as the user
/// scrolls.
///
/// At rest (t=0) the title is rendered at `displayMd` size, anchored to
/// the bottom-left of the expanded bar region. As t grows the title's
/// font size interpolates to `subheading` and its position lerps to the
/// vertical center of the collapsed nav row. At t=1 it sits exactly
/// where the compact-row title would have been, so the whole collapse
/// reads as one continuous resize rather than a cross-fade.
class _ShrinkingTitle extends StatelessWidget {
  const _ShrinkingTitle({
    required this.spec,
    required this.collapseT,
    required this.topInset,
    required this.collapsedBarHeight,
    required this.expandedHeight,
  });

  final UiNavigationSpec spec;
  final double collapseT;
  final double topInset;
  final double collapsedBarHeight;
  final double expandedHeight;

  double _lineHeightFor(TextStyle s) => (s.fontSize ?? 16) * (s.height ?? 1.2);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    // Collapsed endpoint is `heading` (20pt) rather than `subheading`
    // (16pt) so the compact title reads as a proper page title at rest
    // and lines up with `_CompactRow`, which now also renders the
    // compact title at `heading` size.
    final titleStyle = TextStyle.lerp(
      tokens.typography.displayMd,
      tokens.typography.heading,
      collapseT,
    )!;

    final largeLine = _lineHeightFor(tokens.typography.displayMd);
    final compactLine = _lineHeightFor(tokens.typography.heading);
    final subtitleLine = _lineHeightFor(tokens.typography.bodySm);
    final hasTopWidgets =
        spec.back != null || spec.leading != null || spec.actions.isNotEmpty;
    final hasSubtitle = spec.subtitle != null;
    final expandedBlockHeight =
        largeLine + (hasSubtitle ? tokens.spacing.x1 + subtitleLine : 0);

    // Expanded anchor: fit the whole title block (title + subtitle)
    // inside the header and avoid clipping. When there's no top-row
    // widgets we lift it further to reduce dead space.
    final baseExpandedY =
        expandedHeight - tokens.spacing.x1 - expandedBlockHeight;
    final expandedY = baseExpandedY - (hasTopWidgets ? 0 : tokens.spacing.x1);

    // Collapsed anchor: vertical center of the compact nav row.
    final compactY = topInset + (collapsedBarHeight - compactLine) / 2;

    final y = lerpDouble(expandedY, compactY, collapseT)!.clamp(
      topInset + tokens.spacing.x1,
      compactY,
    );

    // Horizontal: start-aligned with page padding (reading-direction
    // "start" — the left edge in LTR, the right edge in RTL), sliding
    // toward centre as we collapse. The compact row handles its own
    // leading (if any); we only need to stay clear of the trailing
    // actions. Switched from `Positioned(left:, right:)` to
    // `PositionedDirectional(start:, end:)` so the title block mirrors
    // correctly in RTL.
    final trailingReserved = spec.actions.isEmpty
        ? tokens.spacing.x4
        : tokens.spacing.x4 + 44.0 * spec.actions.length;
    final startAtRest = tokens.spacing.x4;
    final hasLeading = spec.back != null || spec.leading != null;
    final startCollapsed =
        hasLeading ? tokens.spacing.x4 + 32 : tokens.spacing.x4;
    final startOffset = lerpDouble(startAtRest, startCollapsed, collapseT)!;
    final endOffset =
        lerpDouble(tokens.spacing.x4, trailingReserved, collapseT)!;

    // Subtitle fades first so the user feels the bar compacting before
    // the title finishes its shrink.
    final subtitleOpacity = ((0.55 - collapseT) / 0.5).clamp(0.0, 1.0);

    return PositionedDirectional(
      start: startOffset,
      end: endOffset,
      top: y,
      // Own raster layer — the title rebuilds every scroll frame as
      // the size/position interpolation advances; isolating it keeps
      // the surrounding bar background off the repaint list.
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.title,
                style: titleStyle.copyWith(color: c.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (spec.subtitle != null && subtitleOpacity > 0.02) ...[
                SizedBox(height: tokens.spacing.x1),
                Opacity(
                  opacity: subtitleOpacity,
                  child: UiText(
                    spec.subtitle!,
                    variant: UiTextVariant.bodySm,
                    tone: UiTextTone.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
