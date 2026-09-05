import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/layout/layout.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'bottom_tab_metrics.dart';
import 'tab_layout.dart';

/// One slot in a [UiBottomTabBar].
@immutable
class UiBottomTabItem {
  const UiBottomTabItem({
    required this.label,
    this.icon,
    this.activeIcon,
    this.badge,
  });

  final String label;

  /// Idle-state icon.
  final Widget? icon;

  /// Optional variant shown when the tab is selected.
  final Widget? activeIcon;

  /// Numeric badge drawn in the top-right corner. Non-positive values
  /// are treated as "no badge".
  final int? badge;
}

/// A contextual control that sits beside a floating bottom tab dock.
///
/// In its resting state [child] is presented in a compact, separate island.
/// When [expanded] is true, the selected destination moves into its own island
/// and [child] receives the remaining width. This lets applications introduce
/// focused tools such as search without stacking controls over page content.
@immutable
class UiBottomTabAccessory {
  const UiBottomTabAccessory({
    required this.child,
    this.expanded = false,
    this.leadingItem,
    this.onLeadingPressed,
    this.collapsedWidth = 56,
    this.collapsedHeight,
    this.height = 56,
  }) : assert(
         !expanded || leadingItem != null,
         'An expanded accessory needs a leadingItem.',
       );

  final Widget child;
  final bool expanded;
  final UiBottomTabItem? leadingItem;
  final VoidCallback? onLeadingPressed;
  final double collapsedWidth;

  /// Resting island height. Defaults to [height].
  ///
  /// Set this to the bottom dock's outer height when the compact accessory
  /// should match the dock at rest and shrink into a denser search field while
  /// expanding.
  final double? collapsedHeight;

  /// Height used in expanded accessory mode.
  final double height;

  UiBottomTabAccessory copyWith({
    Widget? child,
    bool? expanded,
    UiBottomTabItem? leadingItem,
    VoidCallback? onLeadingPressed,
    double? collapsedWidth,
    double? collapsedHeight,
    double? height,
  }) {
    return UiBottomTabAccessory(
      child: child ?? this.child,
      expanded: expanded ?? this.expanded,
      leadingItem: leadingItem ?? this.leadingItem,
      onLeadingPressed: onLeadingPressed ?? this.onLeadingPressed,
      collapsedWidth: collapsedWidth ?? this.collapsedWidth,
      collapsedHeight: collapsedHeight ?? this.collapsedHeight,
      height: height ?? this.height,
    );
  }
}

/// Bottom tab bar.
///
/// Renders token-driven surface, icon + label stack per item, active
/// highlight, optional badge, and a pinned safe-area inset so it can
/// sit at the bottom of a `UiPageScaffold` without extra padding.
enum UiBottomTabBarLayout { edgeToEdge, floatingDock, adaptive }

const _kLiquidTabWidth = 72.0;
const _kLiquidTabHeight = 54.0;
const _kLiquidDockPadding = 6.0;
const _kLiquidTabIconSize = 24.0;
const _kLiquidTabIconGap = 2.0;
const _kLiquidTabHorizontalPadding = 6.0;
const _kDetachedTabGap = 12.0;

const _kBottomTabPolicy = TabLayoutPolicy(
  inactiveMin: 64.0,
  inactiveExpandCap: 140.0,
  selectedExtraRoom: 0.0,
  selectedAbsMin: 72.0,
  selectedMax: 180.0,
);

class UiBottomTabBar extends StatelessWidget {
  const UiBottomTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor,
    this.height = _kLiquidTabHeight,
    this.layout = UiBottomTabBarLayout.floatingDock,
    this.adaptiveBreakpoint = 700,
    this.floatingMaxWidth = 640,
    this.floatingHorizontalMargin = 16,
    this.floatingBottomMargin = 12,
    this.blurred = true,
    this.blurSigma = 8,
    this.detachLastItem = false,
    this.equalWidthsWhenLastSelected = false,
    this.accessory,
    this.accessoryPresence = 1,
  });

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color? backgroundColor;

  /// Bar height *excluding* the bottom safe inset.
  final double height;
  final UiBottomTabBarLayout layout;
  final double adaptiveBreakpoint;
  final double floatingMaxWidth;
  final double floatingHorizontalMargin;
  final double floatingBottomMargin;

  /// Applies a bounded backdrop blur to the floating dock.
  final bool blurred;

  /// Backdrop blur radius for the floating dock.
  final double blurSigma;
  final bool detachLastItem;

  /// Uses an equal-width row when the final item is selected.
  ///
  /// Overflow scaffolds use this for the in-group "More" destination so no
  /// previously selected tab remains visually dominant while its drawer is
  /// open.
  final bool equalWidthsWhenLastSelected;
  final UiBottomTabAccessory? accessory;
  final double accessoryPresence;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0;
    final resolvedHeight = resolveBottomTabBarHeight(
      context,
      items.map((item) => item.label),
      minimum: height,
      iconSize: _kLiquidTabIconSize,
      iconGap: _kLiquidTabIconGap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth >= adaptiveBreakpoint;
        final resolvedLayout = switch (layout) {
          UiBottomTabBarLayout.edgeToEdge => UiBottomTabBarLayout.edgeToEdge,
          UiBottomTabBarLayout.floatingDock =>
            UiBottomTabBarLayout.floatingDock,
          UiBottomTabBarLayout.adaptive =>
            isWide
                ? UiBottomTabBarLayout.floatingDock
                : UiBottomTabBarLayout.edgeToEdge,
        };

        final resolvedAccessory =
            resolvedLayout == UiBottomTabBarLayout.floatingDock
            ? accessory
            : null;
        final presence = resolvedAccessory == null
            ? 0.0
            : accessoryPresence.clamp(0.0, 1.0);
        final accessoryExpanded = resolvedAccessory?.expanded ?? false;
        final shouldDetachLastItem =
            !accessoryExpanded &&
            detachLastItem &&
            resolvedLayout != UiBottomTabBarLayout.edgeToEdge &&
            items.length > 1;
        final mainItems = shouldDetachLastItem
            ? items.sublist(0, items.length - 1)
            : items;
        final detachedItem = shouldDetachLastItem ? items.last : null;
        final mainCurrentIndex = currentIndex < mainItems.length
            ? currentIndex
            : -1;
        final detachedSelected =
            shouldDetachLastItem && currentIndex == items.length - 1;
        final tabSetEndAlignment =
            Directionality.of(context) == TextDirection.rtl
            ? Alignment.centerLeft
            : Alignment.centerRight;

        final tabsRow = AnimatedSwitcher(
          duration: tokens.motion.fast,
          reverseDuration: tokens.motion.fast,
          switchInCurve: tokens.motion.standardCurve,
          switchOutCurve: tokens.motion.standardCurve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              alignment: tabSetEndAlignment,
              scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _TabRow(
            key: ValueKey<int>(
              Object.hashAll(mainItems.map((item) => item.label)),
            ),
            items: mainItems,
            currentIndex: mainCurrentIndex,
            onChanged: onChanged,
            height: resolvedHeight,
            animateLayout: resolvedAccessory == null,
            equalWidths:
                equalWidthsWhenLastSelected &&
                !shouldDetachLastItem &&
                currentIndex == items.length - 1,
          ),
        );

        if (resolvedLayout == UiBottomTabBarLayout.edgeToEdge) {
          return UiBox(
            key: const Key('ui_bottom_tab_edge'),
            background: backgroundColor ?? c.surface,
            border: Border(top: BorderSide(color: c.border)),
            padding: EdgeInsets.only(bottom: bottomInset),
            child: tabsRow,
          );
        }

        final horizontalInset = floatingHorizontalMargin;
        final widthCap = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - horizontalInset * 2).clamp(
                0.0,
                floatingMaxWidth,
              )
            : floatingMaxWidth;
        final preferredDockWidth =
            mainItems.length * _kLiquidTabWidth + _kLiquidDockPadding * 2;
        final detachedDockWidth = shouldDetachLastItem
            ? _kLiquidTabWidth + _kLiquidDockPadding * 2
            : 0.0;
        final accessoryDockWidth = resolvedAccessory == null
            ? 0.0
            : accessoryExpanded
            ? 0.0
            : resolvedAccessory.collapsedWidth * presence;
        final accessoryCollapsedHeight =
            resolvedAccessory?.collapsedHeight ?? resolvedAccessory?.height;
        final hasSeparateIsland =
            shouldDetachLastItem || (resolvedAccessory != null && presence > 0);
        final totalGap = shouldDetachLastItem
            ? _kDetachedTabGap
            : resolvedAccessory == null
            ? 0.0
            : _kDetachedTabGap * presence;
        final preferredTotalWidth =
            preferredDockWidth +
            detachedDockWidth +
            accessoryDockWidth +
            totalGap;
        final dockWidth = isWide
            ? preferredTotalWidth.clamp(0.0, widthCap)
            : widthCap.toDouble();
        final collapsedMainDockWidth = hasSeparateIsland
            ? (dockWidth - detachedDockWidth - accessoryDockWidth - totalGap)
                  .clamp(_kLiquidTabWidth + _kLiquidDockPadding * 2, dockWidth)
            : dockWidth;
        final expandedAccessoryWidth = resolvedAccessory == null
            ? 0.0
            : (dockWidth - resolvedAccessory.height - totalGap).clamp(
                _kLiquidTabWidth + _kLiquidDockPadding * 2,
                dockWidth,
              );
        final dockMorphDuration = tokens.motion.standard;

        final bottomOffset = resolveUiEdgeAwareBottomOffset(
          context,
          minimum: floatingBottomMargin + tokens.spacing.x1,
          reduceSafeArea: false,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            0,
            horizontalInset,
            bottomOffset,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: dockWidth,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: accessoryExpanded ? 1 : 0),
                    // Always animates with the real duration. TweenAnimation-
                    // Builder already renders at its target with no motion
                    // on this widget's own first build (Flutter's built-in
                    // behavior), so this doesn't reintroduce motion for a
                    // freshly-mounted accessory. What it fixes: expanding
                    // the accessory while presence is still fading in used
                    // to force Duration.zero, snapping morphProgress
                    // instantly to its target instead of animating —
                    // confirmed via a runtime probe (width jumped in under
                    // 1ms rather than easing).
                    duration: dockMorphDuration,
                    curve: tokens.motion.standardCurve,
                    builder: (context, morphProgress, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: SizedBox(
                            key: const Key('ui_bottom_tab_dock'),
                            height: lerpDouble(
                              resolvedHeight + _kLiquidDockPadding * 2,
                              resolvedAccessory?.height ??
                                  resolvedHeight + _kLiquidDockPadding * 2,
                              morphProgress,
                            ),
                            child: _buildSurface(
                              context,
                              padding: EdgeInsets.lerp(
                                const EdgeInsets.all(_kLiquidDockPadding),
                                EdgeInsets.zero,
                                morphProgress,
                              )!,
                              child: _MorphingTabDock(
                                progress: morphProgress,
                                expandedWidth: math.max(
                                  0,
                                  collapsedMainDockWidth -
                                      _kLiquidDockPadding * 2,
                                ),
                                tabs: tabsRow,
                                leading: resolvedAccessory?.leadingItem == null
                                    ? null
                                    : _AccessoryLeadingCell(
                                        item: resolvedAccessory!.leadingItem!,
                                        onPressed:
                                            resolvedAccessory.onLeadingPressed,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        if (shouldDetachLastItem) ...[
                          const SizedBox(width: _kDetachedTabGap),
                          SizedBox(
                            width: detachedDockWidth,
                            child: _buildSurface(
                              context,
                              key: const Key('ui_bottom_tab_detached_dock'),
                              child: _TabRow(
                                items: [detachedItem!],
                                currentIndex: detachedSelected ? 0 : -1,
                                onChanged: (_) => onChanged(items.length - 1),
                                height: resolvedHeight,
                                equalWidths: false,
                              ),
                            ),
                          ),
                        ],
                        if (resolvedAccessory != null) ...[
                          SizedBox(width: totalGap),
                          Opacity(
                            opacity: presence,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX:
                                    tokens.effects.scaleBlur(4) *
                                    (1 - presence),
                                sigmaY:
                                    tokens.effects.scaleBlur(4) *
                                    (1 - presence),
                              ),
                              child: SizedBox(
                                key: const Key('ui_bottom_tab_accessory'),
                                width: lerpDouble(
                                  accessoryDockWidth,
                                  expandedAccessoryWidth,
                                  morphProgress,
                                ),
                                height: lerpDouble(
                                  accessoryCollapsedHeight!,
                                  resolvedAccessory.height,
                                  morphProgress,
                                ),
                                child: _buildSurface(
                                  context,
                                  padding: EdgeInsets.zero,
                                  child: resolvedAccessory.child,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurface(
    BuildContext context, {
    required Widget child,
    Key? key,
    EdgeInsetsGeometry padding = const EdgeInsets.all(_kLiquidDockPadding),
  }) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final resolvedBlurSigma = tokens.effects.scaleBlur(blurSigma);
    return _BlurredTabSurface(
      key: key,
      background: (backgroundColor ?? colors.surface).withValues(
        alpha: tokens.brightness == Brightness.dark ? 0.72 : 0.68,
      ),
      borderColor: colors.border.withValues(alpha: 0.78),
      borderRadius: tokens.radius.pillAll,
      boxShadow: tokens.shadows.lg,
      blurred: blurred && resolvedBlurSigma > 0,
      blurSigma: resolvedBlurSigma,
      padding: padding,
      child: child,
    );
  }
}

class _AccessoryLeadingCell extends StatelessWidget {
  const _AccessoryLeadingCell({required this.item, required this.onPressed});

  final UiBottomTabItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final icon = item.activeIcon ?? item.icon;
    return UiPressable(
      onPressed: onPressed,
      semanticsLabel: item.label,
      minTapSize: 44,
      builder: (context, state, _) => UiFocusRing(
        visible: state.focused,
        borderRadius: tokens.radius.pillAll,
        child: AnimatedScale(
          duration: tokens.motion.fast,
          curve: tokens.motion.standardCurve,
          scale: state.pressed ? 0.94 : 1,
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                color: tokens.colors.textPrimary,
                size: _kLiquidTabIconSize,
              ),
              child: SizedBox.square(
                dimension: _kLiquidTabIconSize,
                child: FittedBox(fit: BoxFit.contain, child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingTabDock extends StatelessWidget {
  const _MorphingTabDock({
    required this.progress,
    required this.expandedWidth,
    required this.tabs,
    required this.leading,
  });

  final double progress;
  final double expandedWidth;
  final Widget tabs;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001 || leading == null) {
      return tabs;
    }
    if (progress >= 0.999) {
      return KeyedSubtree(
        key: const Key('ui_bottom_tab_accessory_leading'),
        child: leading!,
      );
    }

    final fullDockOpacity = ((0.44 - progress) / 0.44).clamp(0.0, 1.0);
    final leadingOpacity = ((progress - 0.3) / 0.4).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            ignoring: progress > 0.12,
            child: ExcludeSemantics(
              excluding: progress > 0.12,
              child: Opacity(
                opacity: fullDockOpacity,
                child: Transform.scale(
                  scale: lerpDouble(1, 0.97, progress)!,
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: expandedWidth,
                    maxWidth: expandedWidth,
                    child: tabs,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: progress < 0.78,
            child: ExcludeSemantics(
              excluding: progress < 0.78,
              child: Opacity(
                key: const Key('ui_bottom_tab_accessory_leading'),
                opacity: leadingOpacity,
                child: Transform.scale(
                  scale: lerpDouble(0.9, 1, leadingOpacity)!,
                  child: leading!,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredTabSurface extends StatelessWidget {
  const _BlurredTabSurface({
    super.key,
    required this.background,
    required this.borderColor,
    required this.borderRadius,
    required this.padding,
    required this.boxShadow,
    required this.blurred,
    required this.blurSigma,
    required this.child,
  });

  final Color background;
  final Color borderColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> boxShadow;
  final bool blurred;
  final double blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget surface = UiBox(
      background: background,
      border: Border.all(color: borderColor),
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
    if (blurred && blurSigma > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: boxShadow,
          ),
          child: ClipRRect(borderRadius: borderRadius, child: surface),
        ),
      ),
    );
  }
}

class _TabRow extends StatefulWidget {
  const _TabRow({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.height,
    required this.equalWidths,
    this.animateLayout = true,
  });

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final bool equalWidths;
  final bool animateLayout;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  TabDragState _drag = TabDragState.idle;
  final GlobalKey _rowKey = GlobalKey();

  // Resolved once at drag start and reused for the duration of the gesture so
  // each pointer update doesn't walk the element tree via the GlobalKey.
  RenderBox? _dragRowBox;

  List<double>? _cachedNaturalWidths;
  List<String>? _cachedLabels;
  TextStyle? _cachedTextStyle;
  TextDirection? _cachedTextDirection;
  TextScaler? _cachedTextScaler;

  @override
  void didUpdateWidget(covariant _TabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.items.length != widget.items.length ||
        oldWidget.height != widget.height ||
        oldWidget.animateLayout != widget.animateLayout ||
        oldWidget.equalWidths != widget.equalWidths) {
      _drag = TabDragState.idle;
      _dragRowBox = null;
    }
  }

  RenderBox? _resolveRowBox() {
    final ro = _rowKey.currentContext?.findRenderObject();
    return ro is RenderBox ? ro : null;
  }

  void _startDrag(DragStartDetails details, TabLayout layout) {
    _dragRowBox = _resolveRowBox();
    setState(() {
      _drag = beginTabDrag(
        globalPosition: details.globalPosition,
        rowBox: _dragRowBox,
        layout: layout,
        textDirection: Directionality.of(context),
      );
    });
    if (!_drag.isActive) _dragRowBox = null;
  }

  void _updateDrag(
    DragUpdateDetails details,
    TabLayout layout,
    double maxLeft,
  ) {
    if (!_drag.isActive) return;
    final textDirection = Directionality.of(context);
    final next = updateTabDrag(
      state: _drag,
      primaryDelta: textDirection == TextDirection.rtl
          ? -(details.primaryDelta ?? 0)
          : details.primaryDelta ?? 0,
      globalPosition: details.globalPosition,
      rowBox: _dragRowBox,
      layout: layout,
      maxLeft: maxLeft,
      textDirection: textDirection,
    );
    if (!identical(next, _drag)) setState(() => _drag = next);
  }

  void _endDrag(TabLayout layout) {
    final result = endTabDrag(state: _drag, layout: layout);
    setState(() => _drag = result.state);
    _dragRowBox = null;
    final idx = result.selectionIndex;
    if (idx != null && idx != widget.currentIndex) {
      widget.onChanged(idx);
    }
  }

  void _cancelDrag() {
    setState(() => _drag = cancelTabDrag());
    _dragRowBox = null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    if (widget.items.isEmpty) {
      return SizedBox(height: widget.height);
    }

    final selectedIndex =
        widget.currentIndex >= 0 && widget.currentIndex < widget.items.length
        ? widget.currentIndex
        : null;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.maxWidth.isFinite || widget.items.isEmpty) {
            return Row(
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  Expanded(
                    child: _TabCell(
                      item: widget.items[i],
                      selected: i == selectedIndex,
                      onTap: () => widget.onChanged(i),
                    ),
                  ),
              ],
            );
          }

          final naturalWidths = _naturalWidthsFor(
            textStyle: tokens.typography.caption,
            textDirection: textDirection,
            textScaler: textScaler,
          );
          final layout = widget.equalWidths
              ? TabLayout.fromWidths(
                  widths: List<double>.filled(
                    widget.items.length,
                    constraints.maxWidth / widget.items.length,
                  ),
                  selectedIndex: selectedIndex ?? 0,
                )
              : TabLayout.resolve(
                  naturalWidths: naturalWidths,
                  selectedIndex: selectedIndex ?? 0,
                  availableWidth: constraints.maxWidth,
                  policy: _kBottomTabPolicy,
                );
          final selectedWidth = selectedIndex == null
              ? 0.0
              : layout.widths[selectedIndex];
          final maxLeft = constraints.maxWidth - selectedWidth;
          final indicatorStart = _drag.dragLeft ?? layout.selectedLeft;
          final indicatorLeft = selectedIndex == null
              ? 0.0
              : _physicalLeftForDirectionalStart(
                  start: indicatorStart,
                  width: selectedWidth,
                  availableWidth: constraints.maxWidth,
                  textDirection: textDirection,
                );
          final dragging = _drag.isActive;

          return Stack(
            key: _rowKey,
            children: [
              if (selectedIndex != null)
                AnimatedPositioned(
                  duration: dragging || !widget.animateLayout
                      ? Duration.zero
                      : tokens.motion.standard,
                  curve: tokens.motion.standardCurve,
                  left: indicatorLeft,
                  top: 0,
                  bottom: 0,
                  width: selectedWidth,
                  // Cache the pill's decoration as its own layer so moving it
                  // via AnimatedPositioned translates a cached raster instead
                  // of repainting (and re-sampling the blurred backdrop) on
                  // every drag/animation frame.
                  child: RepaintBoundary(
                    child: UiBox(
                      background: c.surfaceMuted.withValues(
                        alpha: tokens.brightness == Brightness.dark
                            ? 0.42
                            : 0.72,
                      ),
                      border: Border.all(
                        color: c.border.withValues(alpha: 0.68),
                      ),
                      borderRadius: tokens.radius.pillAll,
                    ),
                  ),
                ),
              for (var i = 0; i < widget.items.length; i++)
                AnimatedPositioned(
                  duration: widget.animateLayout
                      ? tokens.motion.standard
                      : Duration.zero,
                  curve: tokens.motion.standardCurve,
                  left: _physicalLeftForDirectionalStart(
                    start: layout.lefts[i],
                    width: layout.widths[i],
                    availableWidth: constraints.maxWidth,
                    textDirection: textDirection,
                  ),
                  top: 0,
                  bottom: 0,
                  width: layout.widths[i],
                  child: SizedBox.expand(
                    key: Key('ui_bottom_tab_slot_$i'),
                    child: _TabCell(
                      item: widget.items[i],
                      selected: i == selectedIndex,
                      onTap: () => widget.onChanged(i),
                    ),
                  ),
                ),
              if (selectedIndex != null)
                AnimatedPositioned(
                  duration: dragging || !widget.animateLayout
                      ? Duration.zero
                      : tokens.motion.standard,
                  curve: tokens.motion.standardCurve,
                  left: indicatorLeft,
                  top: 0,
                  bottom: 0,
                  width: selectedWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (d) => _startDrag(d, layout),
                    onHorizontalDragUpdate: (d) =>
                        _updateDrag(d, layout, maxLeft),
                    onHorizontalDragEnd: (_) => _endDrag(layout),
                    onHorizontalDragCancel: _cancelDrag,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static double _physicalLeftForDirectionalStart({
    required double start,
    required double width,
    required double availableWidth,
    required TextDirection textDirection,
  }) {
    if (textDirection == TextDirection.rtl) {
      return (availableWidth - start - width).clamp(0.0, availableWidth);
    }
    return start;
  }

  List<double> _naturalWidthsFor({
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final labels = [for (final item in widget.items) item.label];
    if (_cachedNaturalWidths != null &&
        listEquals(_cachedLabels, labels) &&
        _cachedTextStyle == textStyle &&
        _cachedTextDirection == textDirection &&
        _cachedTextScaler == textScaler) {
      return _cachedNaturalWidths!;
    }
    final widths = [
      for (final label in labels)
        _measureNaturalWidth(
          label,
          textStyle: textStyle,
          textDirection: textDirection,
          textScaler: textScaler,
        ),
    ];
    _cachedLabels = labels;
    _cachedTextStyle = textStyle;
    _cachedTextDirection = textDirection;
    _cachedTextScaler = textScaler;
    _cachedNaturalWidths = widths;
    return widths;
  }

  static double _measureNaturalWidth(
    String label, {
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    return painter.width + _kLiquidTabHorizontalPadding * 2;
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final UiBottomTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      onPressed: onTap,
      minTapSize: 44,
      semanticsLabel: item.label,
      builder: (context, state, _) {
        final color = selected ? c.textPrimary : c.textMuted;
        final icon = selected ? (item.activeIcon ?? item.icon) : item.icon;
        return UiFocusRing(
          visible: state.focused,
          borderRadius: tokens.radius.pillAll,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x2,
              vertical: 2,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null)
                      SizedBox.square(
                        dimension: _kLiquidTabIconSize,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: IconTheme(
                            data: IconThemeData(
                              color: color,
                              size: _kLiquidTabIconSize,
                            ),
                            child: icon,
                          ),
                        ),
                      ),
                    if (icon != null)
                      const SizedBox(height: _kLiquidTabIconGap),
                    AnimatedDefaultTextStyle(
                      duration: tokens.motion.fast,
                      curve: tokens.motion.standardCurve,
                      style: tokens.typography.caption.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if ((item.badge ?? 0) > 0)
                  PositionedDirectional(
                    end: -8,
                    top: -2,
                    child: _TabBadge(count: item.badge!),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiBox(
      background: tokens.colors.danger,
      borderRadius: tokens.radius.pillAll,
      padding: EdgeInsets.symmetric(horizontal: count > 9 ? 4 : 5, vertical: 1),
      child: UiText(
        count > 99 ? '99+' : '$count',
        variant: UiTextVariant.micro,
        style: TextStyle(
          color: tokens.colors.onDanger,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
