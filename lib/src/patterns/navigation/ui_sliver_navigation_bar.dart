import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../foundation/effects/ui_component_shadow.dart';
import '../../foundation/effects/ui_legibility_shadow.dart';
import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/layout/ui_navigation_chrome_scope.dart';
import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/overlay/ui_layered_overlay.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../layout/ui_page_scaffold.dart';
import '../layout/ui_scroll_edge_fade.dart';
import '../layout/ui_system_bars.dart';
import 'ui_navigation_back_button.dart';
import 'ui_compact_navigation_metrics.dart';
import 'ui_navigation_spec.dart';
import 'ui_navigator_history.dart';

// Match iOS large-title navigation: scrolling selects a discrete title state,
// then a short time-based crossfade performs the handoff.
const double _titleSnapThreshold = 0.6;
const double _titleHandoffBlurSigma = 2.5;

// Share the expanded anchor so titles and their actions move as one group.
double _navigationLineHeight(BuildContext context, TextStyle style) =>
    (MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16) *
            (style.height ?? 1.2))
        .ceilToDouble();

double _expandedTitleBlockHeight(BuildContext context, UiNavigationSpec spec) {
  final tokens = UiThemeTokens.of(context);
  final titleLine = _navigationLineHeight(context, tokens.typography.displayMd);
  // Reserve the subtitle line even when it is absent. Bottom-aligning only
  // the visible text made title-only pages sit lower than titled pages with
  // a subtitle. A shared two-line budget gives every large title one anchor.
  final textBlock =
      titleLine +
      tokens.spacing.x1 +
      _navigationLineHeight(context, tokens.typography.bodySm);
  final actionBottom =
      spec.actionsFollowTitleCollapse && spec.actions.isNotEmpty
      ? (titleLine + 44) / 2
      : 0.0;
  return math.max(textBlock, actionBottom);
}

double _expandedTitleTop(
  BuildContext context,
  UiNavigationSpec spec,
  double height,
) =>
    height -
    UiThemeTokens.of(context).spacing.x3 -
    _expandedTitleBlockHeight(context, spec);

/// Stable identity for [UiNavigationSpec.actions] used to key the trailing
/// row's [AnimatedSwitcher].
///
/// Callers (e.g. a page's `build()`) commonly construct a fresh `actions`
/// list — and fresh action widget instances — on every rebuild, even when
/// the rendered content hasn't actually changed (a role toggle, a focus
/// change, any unrelated `setState` above the nav bar). Widgets don't get
/// value equality by default, so hashing the widget *instances*
/// (`Object.hashAll(spec.actions)`) produced a different key on every one
/// of those rebuilds, making [AnimatedSwitcher] treat the row as brand new
/// and replay its enter transition — visually, the actions (e.g. a language
/// switcher) kept "animating in" on unrelated changes.
///
/// Keying off each widget's own [Key] (when the caller supplied one) or,
/// failing that, its [Widget.runtimeType] keeps the identity stable across
/// rebuilds that don't change *what* is being shown, while still animating
/// when the action set genuinely changes shape (an action added/removed,
/// or swapped for a differently-typed one).
String _actionsIdentity(List<Widget> actions) =>
    actions.map((w) => w.key?.toString() ?? w.runtimeType.toString()).join('|');

/// Sliver-based navigation bar with large-title collapse behavior.
///
/// Drop into any `CustomScrollView` slivers list. Keep body spacing in the
/// following content sliver (for example, with [SliverPadding] or a
/// [SliverToBoxAdapter]). The navigation bar deliberately owns one sliver so
/// its pinned extent is not bounded by a short [SliverMainAxisGroup].
///
/// Height budgets:
///
/// - Collapsed: at least [collapsedHeight] + ambient `MediaQuery.padding.top`.
/// - Expanded: [expandedHeight] supplies the shared title-position budget.
///   Title-only rows with title-following actions release unused subtitle space.
/// Heights grow when scaled text or controls need more space.
///
/// When [UiNavigationSpec.largeTitle] is `false`, the bar pins at the
/// collapsed height only — useful for pages without overscrolling
/// content (e.g. forms, dialogs).
///
/// Visual treatment (blur/tint/divider) is driven by the spec so one
/// screen declaration controls both chrome and content.
///
/// Prefer [UiNavigationSpec.back] over supplying a custom [UiNavigationSpec.leading]
/// back button. The built-in back affordance handles RTL chevrons, long-press
/// history, compact phones, and wider tablet layouts where the label can use
/// more available width.
///
/// ```dart
/// UiSliverNavigationBar(
///   spec: UiNavigationSpec(
///     title: 'Invoice details',
///     back: UiNavigationBackConfig(
///       label: 'Invoices',
///       onPressed: () => Navigator.of(context).maybePop(),
///     ),
///   ),
/// )
/// ```
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
    this.useOverlay = true,
    this.showTitleLegibilityShadow,
    this.bottom,
    this.bottomHeight = 0,
  });

  final UiNavigationSpec spec;

  /// Expanded title-position budget (excludes the top safe-area inset).
  /// Title-only rows with title-following actions use less layout height while
  /// preserving this title anchor. Ignored when large titles are disabled.
  final double expandedHeight;

  /// Content height when fully collapsed (excludes the top safe-area
  /// inset).
  final double collapsedHeight;

  final bool pinned;
  final bool floating;
  final bool stretch;

  /// Adapts the navigation surface when the page is hosted next to a
  /// persistent rail. Tablet layouts retain the phone-style large-title
  /// collapse; unconstrained desktop layouts use a quiet page header.
  final bool adaptToPersistentRail;

  /// Lift navigation above page content. Disable when an enclosing media
  /// overlay owns visibility, hit testing, semantics and paint order.
  final bool useOverlay;

  /// Whether compact and large titles receive a silhouette shadow.
  ///
  /// Defaults to `true` outside Apple platforms, where progressive blur is not
  /// used, and `false` on iOS and macOS. Set explicitly to override the
  /// platform-adaptive behavior.
  final bool? showTitleLegibilityShadow;

  /// Optional control row attached to the navigation surface. Its height is
  /// included in the sliver geometry so page content starts below it.
  final Widget? bottom;
  final double bottomHeight;

  @override
  Widget build(BuildContext context) {
    // Register metadata before choosing compact or quiet desktop chrome.
    // Every real page belongs in history, regardless of its header layout.
    // Tab pages share one route, so only the active page may publish its
    // title, and a page without a large title falls back to its compact one.
    UiNavigatorHistoryScope.registerPageTitle(
      context,
      spec.title.trim().isNotEmpty ? spec.title : (spec.compactTitle ?? ''),
    );
    final hasPersistentRail =
        adaptToPersistentRail &&
        UiNavigationChromeScope.hasPersistentRailOf(context);
    final formFactor = uiFormFactorOf(context);
    final isDesktop = formFactor == UiFormFactor.desktop;
    final usesNativeTabletNavigation =
        hasPersistentRail &&
        switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.android => true,
          _ => false,
        };
    final useQuietPageHeader =
        spec.largeTitle &&
        spec.back == null &&
        isDesktop &&
        !usesNativeTabletNavigation;
    if (useQuietPageHeader) {
      return SliverToBoxAdapter(child: _RailPageHeader(spec: spec));
    }

    final useQuietDesktopSurface =
        isDesktop && !usesNativeTabletNavigation && spec.back == null;
    final effectiveSpec = useQuietDesktopSurface
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
    final attachedBottomHeight = bottom == null ? 0.0 : bottomHeight;
    final tokens = UiThemeTokens.of(context);
    final compactContentHeight =
        uiCompactNavigationRowHeight(context, minimumHeight: collapsedHeight) +
        tokens.spacing.x2;
    final expandedAnchorHeight = math.max(
      math.max(expandedHeight, compactContentHeight),
      _expandedTitleBlockHeight(context, effectiveSpec) +
          tokens.spacing.x3 +
          tokens.spacing.x2,
    );
    // Keep the title anchor shared with subtitle pages, but let a title-only
    // action row release its unused subtitle space back to the body.
    final titleLine = _navigationLineHeight(
      context,
      tokens.typography.displayMd,
    );
    final unusedSubtitleSpace =
        effectiveSpec.subtitle == null &&
            effectiveSpec.actionsFollowTitleCollapse &&
            effectiveSpec.actions.isNotEmpty
        ? _expandedTitleBlockHeight(context, effectiveSpec) -
              math.max(titleLine, (titleLine + 44) / 2)
        : 0.0;
    // Navigation owns title-to-content spacing. A viewport-relative fade
    // boundary must not add a larger spacer on devices with smaller safe areas.
    final expandedContentHeight = math.max(
      compactContentHeight,
      expandedAnchorHeight - unusedSubtitleSpace,
    );
    final maxH =
        (useLarge ? expandedContentHeight : compactContentHeight) +
        topInset +
        attachedBottomHeight;
    final minH = compactContentHeight + topInset + attachedBottomHeight;
    final effectiveTitleLegibilityShadow =
        showTitleLegibilityShadow ??
        switch (defaultTargetPlatform) {
          TargetPlatform.iOS || TargetPlatform.macOS => false,
          _ => true,
        };

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _UiNavHeaderDelegate(
        spec: effectiveSpec,
        useOverlay: useOverlay,
        topInset: topInset,
        expandedHeight: maxH,
        expandedAnchorHeight: expandedAnchorHeight + topInset,
        collapsedHeight: minH,
        showTitleLegibilityShadow: effectiveTitleLegibilityShadow,
        bottom: bottom,
        bottomHeight: attachedBottomHeight,
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
    final safeTopInset = MediaQuery.paddingOf(context).top;
    final bodyTopInset = UiPageBodyInsets.topOf(context);
    final fadeClearance = bodyTopInset > safeTopInset
        ? bodyTopInset - safeTopInset
        : 0.0;

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactPane = constraints.maxWidth < 520;
          final baseTopPadding = compactPane
              ? tokens.spacing.x4
              : tokens.spacing.x6;
          final animateTypography = !MediaQuery.disableAnimationsOf(context);
          final responsiveDuration = animateTypography
              ? tokens.motion.standard
              : Duration.zero;

          return AnimatedPadding(
            duration: responsiveDuration,
            curve: tokens.motion.standardCurve,
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.x4,
              baseTopPadding + fadeClearance,
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
                      AnimatedDefaultTextStyle(
                        duration: responsiveDuration,
                        curve: tokens.motion.standardCurve,
                        style:
                            (compactPane
                                    ? tokens.typography.heading
                                    : tokens.typography.displayMd)
                                .copyWith(color: tokens.colors.textPrimary),
                        child: Text(
                          spec.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    required this.useOverlay,
    required this.topInset,
    required this.expandedHeight,
    required this.expandedAnchorHeight,
    required this.collapsedHeight,
    required this.showTitleLegibilityShadow,
    required this.bottom,
    required this.bottomHeight,
  });

  final UiNavigationSpec spec;
  final bool useOverlay;
  final double topInset;
  final double expandedHeight;
  final double expandedAnchorHeight;
  final double collapsedHeight;
  final bool showTitleLegibilityShadow;
  final Widget? bottom;
  final double bottomHeight;

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
      pageBackground: c.background,
      surface: resolvedSurface,
      overlapsContent: overlapsContent,
    );
    final showEdgeFade =
        (resolvedSurface == UiNavigationSurface.edgeFade ||
            resolvedSurface == UiNavigationSurface.blurred) &&
        spec.blurSigma > 0;
    final dividerOpacity = spec.showDivider
        ? (overlapsContent ? 1.0 : _dividerOpacity(t))
        : 0.0;
    final useHero = spec.largeTitle && spec.back == null;
    Widget content = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: minExtent - topInset - bottomHeight - tokens.spacing.x2,
          child: _CompactRow(
            spec: spec,
            showTitle: spec.showCompactTitle,
            titleVisible: !useHero || t >= _titleSnapThreshold,
            showTitleLegibilityShadow: showTitleLegibilityShadow,
          ),
        ),
        if (bottom != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomHeight,
            child: bottom!,
          ),
        if (useHero)
          // _LargeTitle uses Positioned internally, which requires
          // a direct Stack parent — so the RepaintBoundary lives
          // *inside* the Positioned, not around it.
          _LargeTitle(
            spec: spec,
            visible: t < _titleSnapThreshold,
            expandedHeight: expandedAnchorHeight,
            scrollOffset: shrinkOffset,
            showTitleLegibilityShadow: showTitleLegibilityShadow,
          ),
        if (useHero &&
            spec.actionsFollowTitleCollapse &&
            spec.actions.isNotEmpty)
          _TitleTrackingActions(
            spec: spec,
            expandedHeight: expandedAnchorHeight,
            collapsedHeight: minExtent - bottomHeight,
            topInset: topInset,
            scrollOffset: shrinkOffset,
          ),
      ],
    );

    // Surface color *and* divider color both depend on `overlapsContent`,
    // which flips in a single frame the moment content scrolls under
    // the pinned bar. Tween the decoration so neither layer pops in —
    // the divider fade reads as a soft reveal instead of a hard edge.
    content = UiComponentShadow(
      key: const Key('ui_sliver_navigation_bar_shadow'),
      color: c.background.withValues(alpha: overlapsContent ? 0.96 : 0),
      child: AnimatedContainer(
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
      ),
    );

    if (showEdgeFade) {
      content = UiScrollEdgeFade(
        backgroundColor: c.background,
        // Cover the full expanded-title region so title legibility comes from
        // the material behind it rather than a silhouette shadow on the text.
        extent: maxExtent,
        maxOpacity: overlapsContent ? 0.92 : 0.78,
        showBottom: false,
        paintOverChild: false,
        child: content,
      );
    }

    // Publish a system-bar annotation scoped to the bar's pinned region
    // so the OS status icons contrast against *this* surface even when
    // the page background differs (dark hero over a light page, etc.).
    final overlaySample = switch (resolvedSurface) {
      UiNavigationSurface.transparent ||
      UiNavigationSurface.edgeFade ||
      UiNavigationSurface.blurred => c.background,
      UiNavigationSurface.adaptive ||
      UiNavigationSurface.solid ||
      UiNavigationSurface.pageBackground => surfaceColor.withValues(alpha: 1),
    };
    final annotated = AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiSystemBarsStyle.inferFromBackground(overlaySample),
      child: content,
    );
    return useOverlay
        ? UiLayeredOverlayPortal(
            layer: UiOverlayLayer.navigationChrome,
            child: annotated,
          )
        : annotated;
  }

  Color _surfaceColor(
    Color base,
    double t, {
    required Color pageBackground,
    required UiNavigationSurface surface,
    required bool overlapsContent,
  }) {
    switch (surface) {
      case UiNavigationSurface.adaptive:
        // `adaptive` is normalized by _resolveSurface before this path.
        return base;
      case UiNavigationSurface.solid:
        return base;
      case UiNavigationSurface.pageBackground:
        return pageBackground;
      case UiNavigationSurface.edgeFade:
      case UiNavigationSurface.blurred:
        return const Color(0x00000000);
      case UiNavigationSurface.transparent:
        return const Color(0x00000000);
    }
  }

  UiNavigationSurface _resolveSurface(BuildContext context) {
    if (spec.surface != UiNavigationSurface.adaptive) return spec.surface;
    return UiNavigationSurface.solid;
  }

  double _dividerOpacity(double t) {
    // Keep divider nearly absent until close to collapse, then ramp fast.
    final normalized = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
    return math.pow(normalized, 3).toDouble() * 0.95;
  }

  @override
  bool shouldRebuild(covariant _UiNavHeaderDelegate old) {
    return old.spec != spec ||
        old.useOverlay != useOverlay ||
        old.topInset != topInset ||
        old.expandedHeight != expandedHeight ||
        old.expandedAnchorHeight != expandedAnchorHeight ||
        old.collapsedHeight != collapsedHeight ||
        old.showTitleLegibilityShadow != showTitleLegibilityShadow ||
        old.bottom != bottom ||
        old.bottomHeight != bottomHeight;
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.spec,
    required this.showTitle,
    required this.titleVisible,
    required this.showTitleLegibilityShadow,
  });

  final UiNavigationSpec spec;
  final bool showTitle;
  final bool titleVisible;
  final bool showTitleLegibilityShadow;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final brightness = tokens.brightness;
    final resolvedLogo = spec.brand?.resolveLogo(brightness);
    final showMiddle = showTitle || resolvedLogo != null;
    final configuredHistory = spec.back?.history ?? const [];
    final resolvedHistory = configuredHistory.isNotEmpty
        ? configuredHistory
        : UiNavigationBackButton.historyOf(context);
    final strings = UiLocalizations.of(context);
    final resolvedBackLabel =
        spec.back?.label ??
        (resolvedHistory.isNotEmpty
            ? resolvedHistory.first.title
            : strings.back);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = tokens.spacing.x3 * 2;
        final contentWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding,
        );
        final showBackLabel = spec.back?.showLabel ?? false;
        final compactBackMaxWidth = math.min(112.0, contentWidth * 0.28);
        final roomyBackMaxWidth = math.min(260.0, contentWidth * 0.32);
        // Chevron-only (the default): a fixed, comfortable tap width — no
        // label means nothing to reserve room for, so the title and
        // actions get that space back instead.
        final backExtent = 44.0;
        final backMaxWidth = showBackLabel
            ? math.max(
                backExtent,
                contentWidth >= 600 ? roomyBackMaxWidth : compactBackMaxWidth,
              )
            : backExtent;
        final leading = spec.back != null
            ? AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: ConstrainedBox(
                  key: ValueKey('back:$resolvedBackLabel'),
                  constraints: BoxConstraints(maxWidth: backMaxWidth),
                  child: UiNavigationBackButton(
                    label: resolvedBackLabel,
                    showLabel: showBackLabel,
                    onPressed: spec.back!.onPressed,
                    history: resolvedHistory,
                    onHistorySelected: spec.back?.onHistorySelected,
                  ),
                ),
              )
            : spec.leading;
        final trailing = spec.actions.isEmpty || spec.actionsFollowTitleCollapse
            ? null
            : AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: Row(
                  key: ValueKey('actions:${_actionsIdentity(spec.actions)}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < spec.actions.length; i++) ...[
                      if (i > 0) SizedBox(width: tokens.spacing.x2),
                      spec.actions[i],
                    ],
                  ],
                ),
              );
        final middle = showMiddle
            ? AnimatedSwitcher(
                duration: tokens.motion.standard,
                reverseDuration: tokens.motion.fast,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                transitionBuilder: _chromeTransition,
                child: Row(
                  key: ValueKey(
                    'titlegroup:${spec.compactTitle ?? spec.title}|${spec.brand?.displayName ?? ''}',
                  ),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (resolvedLogo != null) ...[
                      Flexible(
                        child: UiLegibilityShadow(
                          child: Semantics(
                            container: true,
                            label: '${spec.brand!.displayName} logo',
                            child: ExcludeSemantics(child: resolvedLogo),
                          ),
                        ),
                      ),
                      if (showTitle && titleVisible)
                        SizedBox(width: tokens.spacing.x2),
                    ],
                    if (showTitle)
                      Flexible(
                        child: AnimatedSwitcher(
                          key: const Key('ui_navigation_compact_title_fade'),
                          duration: tokens.motion.fast * 0.8,
                          reverseDuration: tokens.motion.fast * 0.8,
                          switchInCurve: tokens.motion.standardCurve,
                          switchOutCurve: tokens.motion.standardCurve,
                          transitionBuilder: (child, animation) {
                            return _TitleHandoffTransition(
                              animation: animation,
                              blurSigma: _resolvedTitleBlurSigma(tokens),
                              child: child,
                            );
                          },
                          child: titleVisible
                              ? _TitleLegibility(
                                  key: const ValueKey('compact-title-visible'),
                                  enabled: showTitleLegibilityShadow,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UiText(
                                        spec.compactTitle ?? spec.title,
                                        key: const Key(
                                          'ui_navigation_compact_title',
                                        ),
                                        variant: UiTextVariant.subheading,
                                        style: TextStyle(color: c.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('compact-title-hidden'),
                                ),
                        ),
                      ),
                  ],
                ),
              )
            : const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x3),
          child: NavigationToolbar(
            leading: leading == null
                ? null
                : Center(widthFactor: 1, child: leading),
            middle: middle,
            trailing: trailing,
            centerMiddle: true,
            middleSpacing: tokens.spacing.x2,
          ),
        );
      },
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

class _TitleTrackingActions extends StatelessWidget {
  const _TitleTrackingActions({
    required this.spec,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.topInset,
    required this.scrollOffset,
  });

  final UiNavigationSpec spec;
  final double expandedHeight;
  final double collapsedHeight;
  final double topInset;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final largeLine = _navigationLineHeight(
      context,
      tokens.typography.displayMd,
    );
    final expandedTitleTop = _expandedTitleTop(context, spec, expandedHeight);
    final actionExtent = 44.0;
    final expandedActionTop = expandedTitleTop + (largeLine - actionExtent) / 2;
    final compactActionTop =
        topInset +
        (collapsedHeight - topInset - tokens.spacing.x2 - actionExtent) / 2;
    final top = math.max(compactActionTop, expandedActionTop - scrollOffset);

    return PositionedDirectional(
      key: const Key('ui_navigation_tracking_actions'),
      end: tokens.spacing.x3,
      top: top,
      height: actionExtent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < spec.actions.length; i++) ...[
            if (i > 0) SizedBox(width: tokens.spacing.x2),
            spec.actions[i],
          ],
        ],
      ),
    );
  }
}

/// Large page title that yields to the centered compact navigation title.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle({
    required this.spec,
    required this.visible,
    required this.expandedHeight,
    required this.scrollOffset,
    required this.showTitleLegibilityShadow,
  });

  final UiNavigationSpec spec;
  final bool visible;
  final double expandedHeight;
  final double scrollOffset;
  final bool showTitleLegibilityShadow;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final titleStyle = tokens.typography.displayMd;

    final expandedY = _expandedTitleTop(context, spec, expandedHeight);

    final trailingReserved = spec.actions.isEmpty
        ? tokens.spacing.x4
        : tokens.spacing.x4 +
              44.0 * spec.actions.length +
              tokens.spacing.x2 * (spec.actions.length - 1);
    return PositionedDirectional(
      start: tokens.spacing.x4,
      end: trailingReserved,
      top: expandedY - scrollOffset,
      child: RepaintBoundary(
        child: IgnorePointer(
          ignoring: !visible,
          child: TweenAnimationBuilder<double>(
            key: const Key('ui_navigation_large_title_fade'),
            tween: Tween<double>(end: visible ? 1 : 0),
            duration: tokens.motion.fast * 0.8,
            curve: tokens.motion.standardCurve,
            builder: (context, opacity, child) => _buildTitleHandoffFrame(
              opacity: opacity,
              blurSigma: _resolvedTitleBlurSigma(tokens),
              child: child!,
            ),
            child: _TitleLegibility(
              enabled: showTitleLegibilityShadow,
              shadowKey: const Key('ui_navigation_large_title_shadow'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    key: const Key('ui_navigation_large_title'),
                    style: titleStyle.copyWith(color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (spec.subtitle != null) ...[
                    SizedBox(height: tokens.spacing.x1),
                    UiText(
                      spec.subtitle!,
                      variant: UiTextVariant.bodySm,
                      tone: UiTextTone.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleLegibility extends StatelessWidget {
  const _TitleLegibility({
    super.key,
    required this.enabled,
    required this.child,
    this.shadowKey,
  });

  final bool enabled;
  final Widget child;
  final Key? shadowKey;

  @override
  Widget build(BuildContext context) {
    return enabled ? UiLegibilityShadow(key: shadowKey, child: child) : child;
  }
}

double _resolvedTitleBlurSigma(UiThemeTokens tokens) {
  if (!tokens.effects.animateBlur) return 0;
  return tokens.effects.scaleBlur(_titleHandoffBlurSigma);
}

Widget _buildTitleHandoffFrame({
  required double opacity,
  required double blurSigma,
  required Widget child,
}) {
  final sigma = blurSigma * (1 - opacity);
  Widget result = child;
  if (sigma > 0.01) {
    result = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: result,
    );
  }
  return Opacity(opacity: opacity, child: result);
}

class _TitleHandoffTransition extends AnimatedWidget {
  const _TitleHandoffTransition({
    required Animation<double> animation,
    required this.blurSigma,
    required this.child,
  }) : super(listenable: animation);

  final double blurSigma;
  final Widget child;

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return _buildTitleHandoffFrame(
      opacity: animation.value,
      blurSigma: blurSigma,
      child: child,
    );
  }
}
