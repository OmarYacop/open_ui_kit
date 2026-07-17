import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/layout/layout.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
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

/// Bottom tab bar.
///
/// Renders token-driven surface, icon + label stack per item, active
/// highlight, optional badge, and a pinned safe-area inset so it can
/// sit at the bottom of a `UiPageScaffold` without extra padding.
enum UiBottomTabBarLayout {
  edgeToEdge,
  floatingDock,
  adaptive,
}

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
  final bool blurred;
  final double blurSigma;
  final bool detachLastItem;

  /// Uses an equal-width row when the final item is selected.
  ///
  /// Overflow scaffolds use this for the in-group "More" destination so no
  /// previously selected tab remains visually dominant while its drawer is
  /// open.
  final bool equalWidthsWhenLastSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final bottomInset = MediaQuery.maybePaddingOf(context)?.bottom ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth.isFinite &&
            constraints.maxWidth >= adaptiveBreakpoint;
        final resolvedLayout = switch (layout) {
          UiBottomTabBarLayout.edgeToEdge => UiBottomTabBarLayout.edgeToEdge,
          UiBottomTabBarLayout.floatingDock =>
            UiBottomTabBarLayout.floatingDock,
          UiBottomTabBarLayout.adaptive => isWide
              ? UiBottomTabBarLayout.floatingDock
              : UiBottomTabBarLayout.edgeToEdge,
        };

        final shouldDetachLastItem = detachLastItem &&
            resolvedLayout != UiBottomTabBarLayout.edgeToEdge &&
            items.length > 1;
        final mainItems =
            shouldDetachLastItem ? items.sublist(0, items.length - 1) : items;
        final detachedItem = shouldDetachLastItem ? items.last : null;
        final mainCurrentIndex =
            currentIndex < mainItems.length ? currentIndex : -1;
        final detachedSelected =
            shouldDetachLastItem && currentIndex == items.length - 1;

        final tabsRow = _TabRow(
          items: mainItems,
          currentIndex: mainCurrentIndex,
          onChanged: onChanged,
          height: height,
          equalWidths: equalWidthsWhenLastSelected &&
              !shouldDetachLastItem &&
              currentIndex == items.length - 1,
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
            ? (constraints.maxWidth - horizontalInset * 2)
                .clamp(0.0, floatingMaxWidth)
            : floatingMaxWidth;
        final preferredDockWidth =
            mainItems.length * _kLiquidTabWidth + _kLiquidDockPadding * 2;
        final detachedDockWidth = shouldDetachLastItem
            ? _kLiquidTabWidth + _kLiquidDockPadding * 2
            : 0.0;
        final totalGap = shouldDetachLastItem ? _kDetachedTabGap : 0.0;
        final preferredTotalWidth =
            preferredDockWidth + detachedDockWidth + totalGap;
        final dockWidth = isWide
            ? preferredTotalWidth.clamp(0.0, widthCap)
            : widthCap.toDouble();
        final mainDockWidth = shouldDetachLastItem
            ? (dockWidth - detachedDockWidth - totalGap).clamp(
                _kLiquidTabWidth + _kLiquidDockPadding * 2,
                dockWidth,
              )
            : dockWidth;

        final bottomOffset = resolveUiEdgeAwareBottomOffset(
          context,
          minimum: floatingBottomMargin + tokens.spacing.x1,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: mainDockWidth,
                    child: _BlurredTabSurface(
                      key: const Key('ui_bottom_tab_dock'),
                      background: (backgroundColor ?? c.surface).withValues(
                        alpha:
                            tokens.brightness == Brightness.dark ? 0.72 : 0.68,
                      ),
                      borderColor: c.border.withValues(alpha: 0.78),
                      borderRadius: tokens.radius.pillAll,
                      boxShadow: tokens.shadows.lg,
                      blurred: blurred,
                      blurSigma: blurSigma,
                      padding: const EdgeInsets.all(_kLiquidDockPadding),
                      child: tabsRow,
                    ),
                  ),
                  if (shouldDetachLastItem) ...[
                    const SizedBox(width: _kDetachedTabGap),
                    SizedBox(
                      width: detachedDockWidth,
                      child: _BlurredTabSurface(
                        key: const Key('ui_bottom_tab_detached_dock'),
                        background: (backgroundColor ?? c.surface).withValues(
                          alpha: tokens.brightness == Brightness.dark
                              ? 0.72
                              : 0.68,
                        ),
                        borderColor: c.border.withValues(alpha: 0.78),
                        borderRadius: tokens.radius.pillAll,
                        boxShadow: tokens.shadows.lg,
                        blurred: blurred,
                        blurSigma: blurSigma,
                        padding: const EdgeInsets.all(_kLiquidDockPadding),
                        child: _TabRow(
                          items: [detachedItem!],
                          currentIndex: detachedSelected ? 0 : -1,
                          onChanged: (_) => onChanged(items.length - 1),
                          height: height,
                          equalWidths: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: surface,
        ),
      ),
    );
  }
}

class _TabRow extends StatefulWidget {
  const _TabRow({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.height,
    required this.equalWidths,
  });

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final bool equalWidths;

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
          final selectedWidth =
              selectedIndex == null ? 0.0 : layout.widths[selectedIndex];
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
                  duration: dragging ? Duration.zero : tokens.motion.standard,
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
                        alpha:
                            tokens.brightness == Brightness.dark ? 0.42 : 0.72,
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
                  duration: tokens.motion.standard,
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
                  duration: dragging ? Duration.zero : tokens.motion.standard,
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
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
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
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 4 : 5,
        vertical: 1,
      ),
      child: UiText(
        count > 99 ? '99+' : '$count',
        variant: UiTextVariant.caption,
        style: TextStyle(
          color: tokens.colors.onDanger,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}
