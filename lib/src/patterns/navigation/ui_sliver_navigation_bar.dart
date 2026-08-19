import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
import '../layout/ui_scroll_edge_fade.dart';
import '../layout/ui_system_bars.dart';
import 'ui_navigation_back_button.dart';
import 'ui_navigation_scope.dart';
import 'ui_navigation_spec.dart';
import 'ui_navigator_history.dart';
import 'ui_route_entry.dart';

// Match iOS large-title navigation: scrolling selects a discrete title state,
// then a short time-based crossfade performs the handoff.
const double _titleSnapThreshold = 0.6;
const double _titleHandoffBlurSigma = 2.5;

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
    this.bottom,
    this.bottomHeight = 0,
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

  /// Optional control row attached to the navigation surface. Its height is
  /// included in the sliver geometry so page content starts below it.
  final Widget? bottom;
  final double bottomHeight;

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

    final effectiveSpec = (hasPersistentRail || isDesktop) && spec.back == null
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
    final maxH = (useLarge ? expandedHeight : collapsedHeight) +
        topInset +
        attachedBottomHeight;
    final minH = collapsedHeight + topInset + attachedBottomHeight;

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _UiNavHeaderDelegate(
        spec: effectiveSpec,
        topInset: topInset,
        expandedHeight: maxH,
        collapsedHeight: minH,
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

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactPane = constraints.maxWidth < 520;
          final animateTypography = !MediaQuery.disableAnimationsOf(context);
          final responsiveDuration =
              animateTypography ? tokens.motion.standard : Duration.zero;

          return AnimatedPadding(
            duration: responsiveDuration,
            curve: tokens.motion.standardCurve,
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
                      AnimatedDefaultTextStyle(
                        duration: responsiveDuration,
                        curve: tokens.motion.standardCurve,
                        style: (compactPane
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
    required this.topInset,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.bottom,
    required this.bottomHeight,
  });

  final UiNavigationSpec spec;
  final double topInset;
  final double expandedHeight;
  final double collapsedHeight;
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
    final showEdgeFade = (resolvedSurface == UiNavigationSurface.edgeFade ||
            resolvedSurface == UiNavigationSurface.blurred) &&
        spec.blurSigma > 0;
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
          height: minExtent - topInset - bottomHeight,
          child: _CompactRow(
            spec: spec,
            showTitle: spec.showCompactTitle,
            titleVisible: !useHero || t >= _titleSnapThreshold,
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
            expandedHeight: maxExtent - bottomHeight,
            scrollOffset: shrinkOffset,
          ),
        if (useHero &&
            spec.actionsFollowTitleCollapse &&
            spec.actions.isNotEmpty)
          _TitleTrackingActions(
            spec: spec,
            expandedHeight: maxExtent - bottomHeight,
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
        extent: minExtent,
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
      UiNavigationSurface.blurred =>
        c.background,
      UiNavigationSurface.adaptive ||
      UiNavigationSurface.solid ||
      UiNavigationSurface.pageBackground =>
        surfaceColor.withValues(alpha: 1),
    };
    return UiLayeredOverlayPortal(
      layer: UiOverlayLayer.navigationChrome,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: UiSystemBarsStyle.inferFromBackground(overlaySample),
        child: content,
      ),
    );
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
        old.topInset != topInset ||
        old.expandedHeight != expandedHeight ||
        old.collapsedHeight != collapsedHeight ||
        old.bottom != bottom ||
        old.bottomHeight != bottomHeight;
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.spec,
    required this.showTitle,
    required this.titleVisible,
  });

  final UiNavigationSpec spec;
  final bool showTitle;
  final bool titleVisible;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final brightness = tokens.brightness;
    final resolvedLogo = spec.brand?.resolveLogo(brightness);
    final showMiddle = showTitle || resolvedLogo != null;
    final runtime = UiNavigationControllerScope.maybeOf(context);
    final navHistory = UiNavigatorHistoryScope.maybeOf(context);
    final modalRoute = ModalRoute.of(context);
    if (navHistory != null && modalRoute != null) {
      navHistory.registerTitle(modalRoute, spec.title);
    }
    final runtimeHistory = runtime?.controller.historyItems() ??
        navHistory?.historyItems() ??
        const <UiNavigationBackHistoryItem>[];
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
      if (item.value is UiNavigationBackPopTarget) {
        final popCount = (item.value as UiNavigationBackPopTarget).count;
        final navigator = Navigator.maybeOf(context);
        if (navigator == null) return;
        unawaited(_popNavigatorTimes(navigator, popCount));
        return;
      }
      spec.back?.onPressed();
    }

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
        final backMaxWidth = showBackLabel
            ? math.max(
                44.0,
                contentWidth >= 600 ? roomyBackMaxWidth : compactBackMaxWidth,
              )
            : 44.0;
        final trailingWidth =
            spec.actions.isEmpty || spec.actionsFollowTitleCollapse
                ? 0.0
                : 44.0 * spec.actions.length +
                    tokens.spacing.x2 * (spec.actions.length - 1);
        final middleSideReserve =
            math.max(backMaxWidth, trailingWidth) + tokens.spacing.x2;
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
                    onPressed: spec.back!.onPressed,
                    history: seededHistory,
                    onHistorySelected: onHistorySelected,
                    showLabel: showBackLabel,
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
                child: UiLegibilityShadow(
                  key: ValueKey('actions:${Object.hashAll(spec.actions)}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < spec.actions.length; i++) ...[
                        if (i > 0) SizedBox(width: tokens.spacing.x2),
                        spec.actions[i],
                      ],
                    ],
                  ),
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
                          key: const Key(
                            'ui_navigation_compact_title_fade',
                          ),
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
                              ? UiLegibilityShadow(
                                  key: const ValueKey('compact-title-visible'),
                                  blurSigma: 4,
                                  spreadRadius: 2.5,
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
                                        variant: UiTextVariant.heading,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    if (leading != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: leading,
                      ),
                    const Spacer(),
                    if (trailing != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: trailing,
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                left: middleSideReserve,
                right: middleSideReserve,
                child: Center(child: middle),
              ),
            ],
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

Future<void> _popNavigatorTimes(NavigatorState navigator, int count) async {
  for (var i = 0; i < count; i++) {
    final didPop = await navigator.maybePop();
    if (!didPop) return;
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

  double _lineHeightFor(TextStyle style) =>
      (style.fontSize ?? 16) * (style.height ?? 1.2);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final largeLine = _lineHeightFor(tokens.typography.displayMd);
    final subtitleLine = _lineHeightFor(tokens.typography.bodySm);
    final expandedBlockHeight = largeLine +
        (spec.subtitle == null ? 0 : tokens.spacing.x1 + subtitleLine);
    final expandedTitleTop =
        expandedHeight - tokens.spacing.x1 - expandedBlockHeight;
    const actionExtent = 44.0;
    final expandedActionTop = expandedTitleTop + (largeLine - actionExtent) / 2;
    final compactActionTop =
        topInset + (collapsedHeight - topInset - actionExtent) / 2;
    final top = math.max(
      compactActionTop,
      expandedActionTop - scrollOffset,
    );

    return PositionedDirectional(
      key: const Key('ui_navigation_tracking_actions'),
      end: tokens.spacing.x3,
      top: top,
      height: actionExtent,
      child: UiLegibilityShadow(
        key: const Key('ui_navigation_tracking_actions_shadow'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < spec.actions.length; i++) ...[
              if (i > 0) SizedBox(width: tokens.spacing.x2),
              spec.actions[i],
            ],
          ],
        ),
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
  });

  final UiNavigationSpec spec;
  final bool visible;
  final double expandedHeight;
  final double scrollOffset;

  double _lineHeightFor(TextStyle s) => (s.fontSize ?? 16) * (s.height ?? 1.2);

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final titleStyle = tokens.typography.displayMd;

    final largeLine = _lineHeightFor(tokens.typography.displayMd);
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
            child: UiLegibilityShadow(
              key: const Key('ui_navigation_large_title_shadow'),
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
