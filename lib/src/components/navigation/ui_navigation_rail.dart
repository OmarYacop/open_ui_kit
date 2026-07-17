import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/intl/intl.dart';
import '../../foundation/platform/platform.dart';
import '../../foundation/primitives/primitives.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/ui_app.dart';
import '../data_display/avatar.dart';
import '../feedback/tooltip.dart';
import '../surfaces/ui_drawer.dart';
import 'ui_navigation_badge.dart';

typedef UiNavigationRailLeadingBuilder = Widget Function(
    BuildContext context, Color foreground);

class UiNavigationRailDestination {
  const UiNavigationRailDestination({
    required this.label,
    required this.onPressed,
    this.icon,
    this.activeIcon,
    this.selected = false,
    this.badge,
    this.leadingBuilder,
    this.leadingSize = 20,
    this.leadingInset,
  }) : assert(icon != null || leadingBuilder != null);

  final String label;
  final IconData? icon;
  final IconData? activeIcon;
  final bool selected;
  final int? badge;
  final VoidCallback onPressed;
  final UiNavigationRailLeadingBuilder? leadingBuilder;
  final double leadingSize;
  final double? leadingInset;
}

class UiNavigationRailAction {
  const UiNavigationRailAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// Size and spacing configuration for [UiNavigationRail].
///
/// The defaults are tuned for a floating rail whose collapsed width leaves
/// enough room for floating-window chrome while keeping the destination
/// affordances optically centered.
class UiNavigationRailGeometry {
  const UiNavigationRailGeometry({
    this.expandedOuterWidth = 260,
    this.collapsedOuterWidth = 84,
    this.outerMargin = 12,
    this.itemPadding = 8,
    this.headerHeight = 40,
    this.destinationHeight = 34,
    this.maxPanelHeight = double.infinity,
    this.minVisibleDestinations = 3,
    this.expandedHeaderTopPadding = 4,
    this.collapsedHeaderTopPadding = 4,
    this.headerEndPadding = 8,
    this.headerToggleExtent = 34,
    this.headerToggleIconSize = 18,
    this.collapsedChromeTopPadding = 34,
    this.collapsedChromeMaxHeightExtra = 12,
  });

  static const defaults = UiNavigationRailGeometry();

  final double expandedOuterWidth;
  final double collapsedOuterWidth;
  final double outerMargin;
  final double itemPadding;
  final double headerHeight;
  final double destinationHeight;
  final double maxPanelHeight;
  final int minVisibleDestinations;
  final double expandedHeaderTopPadding;
  final double collapsedHeaderTopPadding;
  final double headerEndPadding;
  final double headerToggleExtent;
  final double headerToggleIconSize;
  final double collapsedChromeTopPadding;
  final double collapsedChromeMaxHeightExtra;

  /// Layout extent of a destination including its accessible tap target.
  double get destinationExtent =>
      destinationHeight < 44 ? 44 : destinationHeight;

  double panelWidthFor(double outerWidth) {
    return (outerWidth - outerMargin * 2)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  double get expandedPanelWidth => panelWidthFor(expandedOuterWidth);

  double get collapsedPanelWidth => panelWidthFor(collapsedOuterWidth);

  double get collapsedItemLeadingInset {
    final collapsedContentWidth =
        (collapsedPanelWidth - itemPadding * 2).clamp(0.0, double.infinity);
    return ((collapsedContentWidth - destinationHeight) / 2)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  double headerTopPadding({
    required bool collapsed,
    required bool hasFloatingWindowChrome,
  }) {
    if (!collapsed) return expandedHeaderTopPadding;
    if (hasFloatingWindowChrome) return collapsedChromeTopPadding;
    return collapsedHeaderTopPadding;
  }

  double railProgressForPanelWidth(double panelWidth) {
    final range = expandedPanelWidth - collapsedPanelWidth;
    if (range <= 0) return 1;
    return ((panelWidth - collapsedPanelWidth) / range)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double labelProgressForRailProgress(
    double railProgress, {
    required bool collapsed,
  }) {
    const labelWindow = 0.28;
    final progress = collapsed
        ? (railProgress / labelWindow).clamp(0.0, 1.0)
        : ((railProgress - (1 - labelWindow)) / labelWindow).clamp(0.0, 1.0);

    return Curves.easeOutCubic.transform(
      progress.toDouble(),
    );
  }
}

/// Floating navigation rail for tablet/desktop shells.
///
/// This is the higher-fidelity rail variant used by app shells that want a
/// floating panel rather than the edge-to-edge [UiSidebar]. It still uses the
/// same Open UI Kit primitives for text, press states, focus, icon buttons, tooltips,
/// avatars, and drawer-adaptive radii.
class UiNavigationRail extends StatefulWidget {
  const UiNavigationRail({
    super.key,
    required this.destinations,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.title,
    this.footerActions = const <UiNavigationRailAction>[],
    this.footerDestinations = const <UiNavigationRailDestination>[],
    this.platformCapabilities,
    this.geometry = UiNavigationRailGeometry.defaults,
  });

  final String? title;
  final List<UiNavigationRailDestination> destinations;
  final List<UiNavigationRailAction> footerActions;
  final List<UiNavigationRailDestination> footerDestinations;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final UiPlatformCapabilities? platformCapabilities;
  final UiNavigationRailGeometry geometry;

  static const expandedOuterWidth = 260.0;
  static const collapsedOuterWidth = 84.0;
  static const expandedPanelWidth = 236.0;
  static const collapsedPanelWidth = 60.0;
  static const maxPanelHeight = double.infinity;

  @override
  State<UiNavigationRail> createState() => _UiNavigationRailState();
}

class _UiNavigationRailState extends State<UiNavigationRail>
    with WidgetsBindingObserver {
  static const _windowModeDebounce = Duration(milliseconds: 140);

  Timer? _windowModeRefreshTimer;
  StreamSubscription<UiWindowMode>? _windowModeSubscription;
  int _windowModeRefreshToken = 0;
  UiWindowMode? _windowMode;
  late final bool _tracksWindowMode;

  UiPlatformCapabilities get _platformCapabilities =>
      widget.platformCapabilities ?? UiPlatformCapabilities.shared;

  @override
  void initState() {
    super.initState();
    _tracksWindowMode = supportsUiFloatingWindowChrome();
    if (_tracksWindowMode) {
      WidgetsBinding.instance.addObserver(this);
      _windowModeSubscription = _platformCapabilities.windowModeChanges
          .listen(_handleWindowModeChanged);
      _scheduleWindowModeRefresh(immediate: true);
    }
  }

  @override
  void dispose() {
    _windowModeRefreshTimer?.cancel();
    unawaited(_windowModeSubscription?.cancel());
    if (_tracksWindowMode) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  void _handleWindowModeChanged(UiWindowMode mode) {
    _windowModeRefreshToken += 1;
    if (!mounted || mode == _windowMode) return;
    setState(() {
      _windowMode = mode;
    });
  }

  @override
  void didChangeMetrics() {
    if (!_tracksWindowMode) return;
    _scheduleWindowModeRefresh(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_tracksWindowMode && state == AppLifecycleState.resumed) {
      _scheduleWindowModeRefresh(forceRefresh: true);
    }
  }

  void _scheduleWindowModeRefresh({
    bool immediate = false,
    bool forceRefresh = false,
  }) {
    _windowModeRefreshTimer?.cancel();

    if (immediate) {
      unawaited(_refreshWindowMode(forceRefresh: forceRefresh));
      return;
    }

    _windowModeRefreshTimer = Timer(_windowModeDebounce, () {
      unawaited(_refreshWindowMode(forceRefresh: forceRefresh));
    });
  }

  Future<void> _refreshWindowMode({bool forceRefresh = false}) async {
    final token = ++_windowModeRefreshToken;
    try {
      final mode = await _platformCapabilities.currentWindowMode(
        forceRefresh: forceRefresh,
      );
      if (!mounted || token != _windowModeRefreshToken || mode == _windowMode) {
        return;
      }
      setState(() {
        _windowMode = mode;
      });
    } catch (_) {
      // Tests and unsupported embedders may not register the native channel.
      // Keep the MediaQuery/platform heuristic as the non-fatal fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final geometry = widget.geometry;
    final outerWidth = widget.collapsed
        ? geometry.collapsedOuterWidth
        : geometry.expandedOuterWidth;
    final margin = geometry.outerMargin;
    final panelColor = tokens.brightness == Brightness.dark
        ? Color.lerp(tokens.colors.surface, tokens.colors.surfaceMuted, 0.28)!
        : tokens.colors.surface;
    final shadowColor = tokens.brightness == Brightness.dark
        ? const Color(0x66000000)
        : const Color(0x0D000000);
    final itemLeadingInset = geometry.collapsedItemLeadingInset;
    final headerTitleInset = geometry.itemPadding + itemLeadingInset;
    // Resolve before SafeArea rewrites the descendant MediaQuery. The original
    // top inset is what distinguishes real fullscreen iOS from provisional
    // first-frame window geometry.
    final chromeLeadingInset = resolveUiFloatingWindowChromeLeadingInset(
      context,
      _windowMode,
    );

    return TweenAnimationBuilder<double>(
      duration: tokens.motion.slow,
      curve: tokens.motion.standardCurve,
      tween: Tween<double>(end: outerWidth),
      builder: (context, animatedOuterWidth, child) {
        final animatedPanelWidth = geometry.panelWidthFor(animatedOuterWidth);

        return SizedBox(
          width: animatedOuterWidth,
          child: ColoredBox(
            color: tokens.colors.background,
            child: SafeArea(
              right: false,
              bottom: false,
              child: AnimatedPadding(
                duration: tokens.motion.slow,
                curve: tokens.motion.standardCurve,
                padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
                child: LayoutBuilder(
                  builder: (context, viewportConstraints) {
                    return Align(
                      alignment: AlignmentDirectional.topStart,
                      child: SizedBox(
                        width: animatedPanelWidth,
                        height: viewportConstraints.maxHeight.isFinite
                            ? viewportConstraints.maxHeight
                            : null,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final railProgress =
                                geometry.railProgressForPanelWidth(
                              constraints.maxWidth,
                            );
                            final labelProgress =
                                geometry.labelProgressForRailProgress(
                              railProgress,
                              collapsed: widget.collapsed,
                            );
                            final radius = _resolveRailRadius(context);
                            final hasFloatingWindowChrome =
                                chromeLeadingInset > 0;
                            final footerItemCount =
                                widget.footerActions.length +
                                    widget.footerDestinations.length;
                            final footerHeight = footerItemCount == 0
                                ? 0.0
                                : geometry.itemPadding * 2 +
                                    footerItemCount *
                                        geometry.destinationExtent;
                            final availableMainHeight =
                                constraints.maxHeight.isFinite
                                    ? (constraints.maxHeight - footerHeight)
                                        .clamp(0.0, double.infinity)
                                        .toDouble()
                                    : null;
                            final targetHeaderTopPadding =
                                geometry.headerTopPadding(
                              collapsed: widget.collapsed,
                              hasFloatingWindowChrome: hasFloatingWindowChrome,
                            );

                            return TweenAnimationBuilder<double>(
                              duration: tokens.motion.slow,
                              curve: tokens.motion.standardCurve,
                              tween: Tween<double>(
                                end: targetHeaderTopPadding,
                              ),
                              builder: (context, headerTopPadding, child) {
                                final metrics = _RailLayoutMetrics.resolve(
                                  geometry: geometry,
                                  collapsed: widget.collapsed,
                                  hasFloatingWindowChrome:
                                      hasFloatingWindowChrome,
                                  headerTopPadding: headerTopPadding,
                                  destinationCount: widget.destinations.length,
                                  availableHeight: availableMainHeight,
                                );

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      height: metrics.mainPanelHeight,
                                      child: _RailSurface(
                                        key: const Key(
                                            'ui_navigation_rail_main_surface'),
                                        background: panelColor,
                                        borderRadius: radius,
                                        shadowColor: shadowColor,
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: metrics.headerTopPadding,
                                              ),
                                              child: _RailHeader(
                                                collapsed: widget.collapsed,
                                                geometry: geometry,
                                                railProgress: railProgress,
                                                labelProgress: labelProgress,
                                                chromeLeadingInset:
                                                    chromeLeadingInset,
                                                itemLeadingInset:
                                                    headerTitleInset,
                                                title: widget.title ??
                                                    UiAppContext.titleOf(
                                                        context),
                                                onToggleCollapsed:
                                                    widget.onToggleCollapsed,
                                              ),
                                            ),
                                            SizedBox(
                                              height:
                                                  metrics.destinationsHeight,
                                              child: SingleChildScrollView(
                                                padding: EdgeInsets.only(
                                                  right: geometry.itemPadding,
                                                  left: geometry.itemPadding,
                                                  bottom: geometry.itemPadding,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    for (final destination
                                                        in widget.destinations)
                                                      _RailDestinationButton(
                                                        destination:
                                                            destination,
                                                        geometry: geometry,
                                                        labelProgress:
                                                            labelProgress,
                                                        itemLeadingInset:
                                                            itemLeadingInset,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.footerActions.isNotEmpty ||
                                        widget.footerDestinations.isNotEmpty)
                                      _RailSurface(
                                        key: const Key(
                                            'ui_navigation_rail_footer_surface'),
                                        background: panelColor,
                                        borderRadius: radius,
                                        shadowColor: shadowColor,
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                              geometry.itemPadding),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final button
                                                  in widget.footerActions)
                                                _RailDestinationButton(
                                                  destination:
                                                      UiNavigationRailDestination(
                                                    label: button.label,
                                                    icon: button.icon,
                                                    onPressed: button.onPressed,
                                                  ),
                                                  geometry: geometry,
                                                  labelProgress: labelProgress,
                                                  itemLeadingInset:
                                                      itemLeadingInset,
                                                ),
                                              for (final destination
                                                  in widget.footerDestinations)
                                                _RailDestinationButton(
                                                  destination: destination,
                                                  geometry: geometry,
                                                  labelProgress: labelProgress,
                                                  itemLeadingInset:
                                                      itemLeadingInset,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RailLayoutMetrics {
  const _RailLayoutMetrics({
    required this.headerTopPadding,
    required this.mainPanelHeight,
    required this.destinationsHeight,
  });

  final double headerTopPadding;
  final double mainPanelHeight;
  final double destinationsHeight;

  static _RailLayoutMetrics resolve({
    required UiNavigationRailGeometry geometry,
    required bool collapsed,
    required bool hasFloatingWindowChrome,
    required double headerTopPadding,
    required int destinationCount,
    double? availableHeight,
  }) {
    final visibleDestinationCount =
        destinationCount < geometry.minVisibleDestinations
            ? destinationCount
            : geometry.minVisibleDestinations;
    final headerBlockHeight = headerTopPadding + geometry.headerHeight;
    final mainPanelMinHeight = headerBlockHeight +
        visibleDestinationCount * geometry.destinationExtent +
        geometry.itemPadding;
    final mainPanelNaturalHeight = headerBlockHeight +
        destinationCount * geometry.destinationExtent +
        geometry.itemPadding;
    final configuredMaxHeight = geometry.maxPanelHeight +
        (collapsed && hasFloatingWindowChrome
            ? geometry.collapsedChromeMaxHeightExtra
            : 0);
    final mainPanelMaxHeight =
        availableHeight == null || availableHeight > configuredMaxHeight
            ? configuredMaxHeight
            : availableHeight;
    final resolvedMinHeight = mainPanelMinHeight > mainPanelMaxHeight
        ? mainPanelMaxHeight
        : mainPanelMinHeight;
    final mainPanelHeight = mainPanelNaturalHeight
        .clamp(resolvedMinHeight, mainPanelMaxHeight)
        .toDouble();
    final destinationsHeight = (mainPanelHeight - headerBlockHeight)
        .clamp(0.0, double.infinity)
        .toDouble();

    return _RailLayoutMetrics(
      headerTopPadding: headerTopPadding,
      mainPanelHeight: mainPanelHeight,
      destinationsHeight: destinationsHeight,
    );
  }
}

class UiNavigationRailAvatar extends StatelessWidget {
  const UiNavigationRailAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.semanticLabel,
  });

  final String? name;
  final String? imageUrl;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return UiAvatar(
      name: name,
      imageUrl: imageUrl,
      size: 26,
      showBorder: false,
      semanticLabel: semanticLabel,
    );
  }
}

class _RailSurface extends StatelessWidget {
  const _RailSurface({
    super.key,
    required this.background,
    required this.borderRadius,
    required this.shadowColor,
    required this.child,
  });

  final Color background;
  final BorderRadius borderRadius;
  final Color shadowColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final border = Border.all(
      color: tokens.colors.border.withValues(
        alpha: tokens.brightness == Brightness.dark ? 0.82 : 1,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: background)),
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: border,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BorderRadius _resolveRailRadius(BuildContext context) {
  final tokens = UiThemeTokens.of(context);
  final drawerRadius = UiDrawer.adaptiveBorderRadiusOf(
    context,
    side: UiDrawerSide.start,
    variant: UiDrawerVariant.floating,
  ).resolve(Directionality.of(context));
  final desired = tokens.radius.lg.x + tokens.spacing.x1;
  final adaptive = [
    drawerRadius.topLeft.x,
    drawerRadius.topRight.x,
    drawerRadius.bottomLeft.x,
    drawerRadius.bottomRight.x,
  ].reduce((a, b) => a > b ? a : b);
  final value = (adaptive < desired ? adaptive : desired).clamp(20.0, 32.0);
  return BorderRadius.circular(value);
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.collapsed,
    required this.geometry,
    required this.railProgress,
    required this.labelProgress,
    required this.chromeLeadingInset,
    required this.itemLeadingInset,
    required this.title,
    required this.onToggleCollapsed,
  });

  final bool collapsed;
  final UiNavigationRailGeometry geometry;
  final double railProgress;
  final double labelProgress;
  final double chromeLeadingInset;
  final double itemLeadingInset;
  final String title;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final strings = UiLocalizations.of(context);

    return SizedBox(
      key: const Key('ui_navigation_rail_header'),
      height: geometry.headerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonExtent = geometry.headerToggleExtent;
          final width = constraints.maxWidth;
          final centeredStart = ((width - buttonExtent) / 2).clamp(
            0.0,
            double.infinity,
          );
          final expandedStart =
              (width - geometry.headerEndPadding - buttonExtent).clamp(
            0.0,
            double.infinity,
          );
          final toggleStart =
              centeredStart + (expandedStart - centeredStart) * railProgress;
          final titleProgress = labelProgress;
          final expandedTitleStart =
              chromeLeadingInset > 0 ? chromeLeadingInset : itemLeadingInset;
          final titleStart = expandedTitleStart * railProgress;
          final availableTitleWidth =
              (toggleStart - itemLeadingInset - titleStart).clamp(
            0.0,
            double.infinity,
          );
          final titleWidth = availableTitleWidth * titleProgress;
          final toggleSpacer = (toggleStart - titleStart - titleWidth).clamp(
            0.0,
            double.infinity,
          );

          return Row(
            children: [
              SizedBox(width: titleStart),
              SizedBox(
                width: titleWidth,
                child: ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Opacity(
                      opacity: titleProgress,
                      child: UiText(
                        title,
                        variant: UiTextVariant.subheading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: toggleSpacer),
              SizedBox(
                width: buttonExtent,
                child: _RailToggleButton(
                  icon: Icon(
                    collapsed
                        ? LucideIcons.panelLeftOpen
                        : LucideIcons.panelLeftClose,
                  ),
                  semanticsLabel: collapsed
                      ? strings.expandNavigationRail
                      : strings.collapseNavigationRail,
                  extent: buttonExtent,
                  iconSize: geometry.headerToggleIconSize,
                  onPressed: onToggleCollapsed,
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          );
        },
      ),
    );
  }
}

class _RailToggleButton extends StatelessWidget {
  const _RailToggleButton({
    required this.icon,
    required this.semanticsLabel,
    required this.extent,
    required this.iconSize,
    required this.onPressed,
  });

  final Widget icon;
  final String semanticsLabel;
  final double extent;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final radius = BorderRadius.circular(extent / 2);

    return UiPressable(
      onPressed: onPressed,
      semanticsLabel: semanticsLabel,
      semanticsButton: true,
      minTapSize: extent,
      builder: (context, state, child) {
        final background = state.pressed
            ? tokens.colors.accent.withValues(alpha: 0.60)
            : state.hovered
                ? tokens.colors.accent.withValues(alpha: 0.35)
                : const Color(0x00000000);

        return UiFocusRing(
          visible: state.focused,
          borderRadius: radius,
          child: AnimatedScale(
            scale: state.pressed ? 0.96 : 1,
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            child: UiBox(
              key: const Key('ui_navigation_rail_toggle_button'),
              width: extent,
              height: extent,
              background: background,
              borderRadius: radius,
              alignment: Alignment.center,
              child: IconTheme.merge(
                data: IconThemeData(
                  color: tokens.colors.textMuted,
                  size: iconSize,
                ),
                child: icon,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RailDestinationButton extends StatelessWidget {
  const _RailDestinationButton({
    required this.destination,
    required this.geometry,
    required this.labelProgress,
    required this.itemLeadingInset,
  });

  final UiNavigationRailDestination destination;
  final UiNavigationRailGeometry geometry;
  final double labelProgress;
  final double itemLeadingInset;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiTooltip(
      message: destination.label,
      side: UiTooltipSide.right,
      child: UiPressable(
        onPressed: destination.onPressed,
        semanticsLabel: destination.label,
        semanticsButton: true,
        minTapSize: 44,
        builder: (context, state, child) {
          final highlighted =
              destination.selected || state.hovered || state.pressed;
          final foreground = destination.selected ? c.textPrimary : c.textMuted;
          final selectedBackground = c.surfaceMuted.withValues(
            alpha: tokens.brightness == Brightness.dark ? 0.96 : 0.88,
          );
          final hoverBackground = c.surfaceMuted.withValues(
            alpha: tokens.brightness == Brightness.dark ? 0.62 : 0.62,
          );
          final background = destination.selected
              ? selectedBackground
              : highlighted
                  ? hoverBackground
                  : const Color(0x00000000);
          final segmentExtent = geometry.destinationHeight;
          final pillRadius = Radius.circular(segmentExtent / 2);
          final iconEndRadius = Radius.circular(
            (segmentExtent / 2) * (1 - labelProgress),
          );
          final direction = Directionality.of(context);
          final iconRadius = BorderRadiusDirectional.only(
            topStart: pillRadius,
            bottomStart: pillRadius,
            topEnd: iconEndRadius,
            bottomEnd: iconEndRadius,
          ).resolve(direction);
          final labelRadius = BorderRadiusDirectional.only(
            topEnd: pillRadius,
            bottomEnd: pillRadius,
          ).resolve(direction);

          return SizedBox(
            height: geometry.destinationHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final leadingSize = destination.leadingSize;
                final leadingStart = destination.leadingInset ??
                    itemLeadingInset.clamp(
                      0.0,
                      (width - segmentExtent).clamp(0.0, double.infinity),
                    );
                final labelAvailableWidth =
                    (width - leadingStart - segmentExtent).clamp(
                  0.0,
                  double.infinity,
                );
                final labelWidth = labelAvailableWidth * labelProgress;
                final resolvedIcon =
                    destination.selected && destination.activeIcon != null
                        ? destination.activeIcon
                        : destination.icon;

                return Padding(
                  padding: EdgeInsetsDirectional.only(start: leadingStart),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: segmentExtent,
                        height: segmentExtent,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UiBox(
                              width: segmentExtent,
                              height: segmentExtent,
                              background: background,
                              borderRadius: iconRadius,
                              clipBehavior: Clip.antiAlias,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: leadingSize,
                                height: leadingSize,
                                child: Center(
                                  child: destination.leadingBuilder?.call(
                                        context,
                                        foreground,
                                      ) ??
                                      Icon(
                                        resolvedIcon,
                                        size: 20,
                                        color: foreground,
                                      ),
                                ),
                              ),
                            ),
                            if ((destination.badge ?? 0) > 0 &&
                                labelProgress < 0.5)
                              PositionedDirectional(
                                top: -3,
                                end: -3,
                                child: UiNavigationCountBadge(
                                  count: destination.badge!,
                                  compact: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (labelWidth > 0)
                        SizedBox(
                          width: labelWidth,
                          height: segmentExtent,
                          child: UiBox(
                            background: background,
                            borderRadius: labelRadius,
                            clipBehavior: Clip.antiAlias,
                            alignment: AlignmentDirectional.centerStart,
                            padding: EdgeInsetsDirectional.only(
                              start: tokens.spacing.x2,
                              end: tokens.spacing.x2,
                            ),
                            child: ClipRect(
                              child: Opacity(
                                opacity: labelProgress,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: UiText(
                                        destination.label,
                                        variant: UiTextVariant.body,
                                        style: TextStyle(
                                          color: foreground,
                                          fontWeight: destination.selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                      ),
                                    ),
                                    if ((destination.badge ?? 0) > 0 &&
                                        labelWidth >= 54) ...[
                                      SizedBox(width: tokens.spacing.x1),
                                      UiNavigationCountBadge(
                                        count: destination.badge!,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
