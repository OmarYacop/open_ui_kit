import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'tab_layout.dart';

/// Tab list item.
@immutable
class UiTab {
  const UiTab({required this.label, this.icon});
  final String label;
  final Widget? icon;
}

enum UiTabsLayout {
  fill,
  intrinsic,
  adaptive,
}

const _kLiquidTabWidth = 72.0;
const _kLiquidTabHeight = 36.0;
const _kLiquidTabPadding = 4.0;
const _kLiquidTabIconSize = 16.0;
const _kLiquidTabIconGap = 8.0;
const _kLiquidTabHorizontalPadding = 16.0;

const _kTabsPolicy = TabLayoutPolicy(
  inactiveMin: 64.0,
  inactiveExpandCap: 160.0,
  selectedExtraRoom: 40.0,
  selectedAbsMin: 96.0,
  selectedMax: 220.0,
);

/// Shadcn-style segmented tab list.
///
/// Renders a muted container with an animated pill indicator that glides
/// to the selected tab. The pill shares a single `AnimatedPositioned`
/// layer underneath the labels so the active state transition reads as
/// one cohesive motion rather than per-item redraws.
class UiTabs extends StatelessWidget {
  const UiTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.expand = true,
    this.layout = UiTabsLayout.adaptive,
    this.adaptiveBreakpoint = 700,
    this.intrinsicMaxWidth = 560,
  }) : assert(tabs.length > 0, 'UiTabs requires at least one tab');

  final List<UiTab> tabs;
  final int value;
  final ValueChanged<int> onChanged;
  final bool expand;
  final UiTabsLayout layout;
  final double adaptiveBreakpoint;
  final double intrinsicMaxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiBox(
      background: c.muted,
      borderRadius: tokens.radius.lgAll,
      padding: const EdgeInsets.all(_kLiquidTabPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth.isFinite &&
              constraints.maxWidth >= adaptiveBreakpoint;
          final resolvedLayout = switch (layout) {
            UiTabsLayout.fill => UiTabsLayout.fill,
            UiTabsLayout.intrinsic => UiTabsLayout.intrinsic,
            UiTabsLayout.adaptive =>
              isWide ? UiTabsLayout.intrinsic : UiTabsLayout.fill,
          };

          final useExpanded = expand;
          if (resolvedLayout == UiTabsLayout.intrinsic &&
              constraints.maxWidth.isFinite) {
            final intrinsicWidthCap =
                (tabs.length * _kLiquidTabWidth).clamp(0.0, intrinsicMaxWidth);
            final targetWidth =
                constraints.maxWidth.clamp(0.0, intrinsicWidthCap);
            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                key: const Key('ui_tabs_intrinsic_container'),
                width: targetWidth,
                child: _TabStack(
                  tabs: tabs,
                  value: value,
                  onChanged: onChanged,
                  expand: useExpanded,
                  availableWidth: targetWidth,
                ),
              ),
            );
          }

          return _TabStack(
            tabs: tabs,
            value: value,
            onChanged: onChanged,
            expand: useExpanded,
            availableWidth: constraints.maxWidth,
          );
        },
      ),
    );
  }
}

class _TabStack extends StatefulWidget {
  const _TabStack({
    required this.tabs,
    required this.value,
    required this.onChanged,
    required this.expand,
    required this.availableWidth,
  });

  final List<UiTab> tabs;
  final int value;
  final ValueChanged<int> onChanged;
  final bool expand;
  final double availableWidth;

  @override
  State<_TabStack> createState() => _TabStackState();
}

class _TabStackState extends State<_TabStack> {
  TabDragState _drag = TabDragState.idle;
  final GlobalKey _stackKey = GlobalKey();

  // Resolved once at drag start and reused for the duration of the gesture so
  // each pointer update doesn't walk the element tree via the GlobalKey.
  RenderBox? _dragRowBox;

  List<double>? _cachedNaturalWidths;
  List<String>? _cachedLabels;
  List<bool>? _cachedHasIcons;
  TextStyle? _cachedTextStyle;
  TextDirection? _cachedTextDirection;
  TextScaler? _cachedTextScaler;

  @override
  void didUpdateWidget(covariant _TabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.tabs.length != widget.tabs.length ||
        oldWidget.availableWidth != widget.availableWidth) {
      _drag = TabDragState.idle;
      _dragRowBox = null;
    }
  }

  RenderBox? _resolveRowBox() {
    final ro = _stackKey.currentContext?.findRenderObject();
    return ro is RenderBox ? ro : null;
  }

  void _startDrag(DragStartDetails details, TabLayout layout) {
    _dragRowBox = _resolveRowBox();
    setState(() {
      _drag = beginTabDrag(
        globalPosition: details.globalPosition,
        rowBox: _dragRowBox,
        layout: layout,
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
    final next = updateTabDrag(
      state: _drag,
      primaryDelta: details.primaryDelta ?? 0,
      globalPosition: details.globalPosition,
      rowBox: _dragRowBox,
      layout: layout,
      maxLeft: maxLeft,
    );
    if (!identical(next, _drag)) setState(() => _drag = next);
  }

  void _endDrag(TabLayout layout) {
    final result = endTabDrag(state: _drag, layout: layout);
    setState(() => _drag = result.state);
    _dragRowBox = null;
    final idx = result.selectionIndex;
    if (idx != null && idx != widget.value) {
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
    final selectedIndex = widget.value.clamp(0, widget.tabs.length - 1);

    if (!widget.expand || !widget.availableWidth.isFinite) {
      // Fall back to a simple intrinsic row when we can't measure width
      // (e.g. unbounded parents).
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              _TabButton(
                tab: widget.tabs[i],
                selected: i == selectedIndex,
                onTap: () => widget.onChanged(i),
              ),
          ],
        ),
      );
    }

    final naturalWidths = _naturalWidthsFor(
      textStyle: tokens.typography.label,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    final layout = TabLayout.resolve(
      naturalWidths: naturalWidths,
      selectedIndex: selectedIndex,
      availableWidth: widget.availableWidth,
      policy: _kTabsPolicy,
    );
    final selectedWidth = layout.widths[selectedIndex];
    final maxLeft = widget.availableWidth - selectedWidth;
    final indicatorLeft = _drag.dragLeft ?? layout.selectedLeft;
    final dragging = _drag.isActive;

    return SizedBox(
      height: _kLiquidTabHeight,
      child: Stack(
        key: _stackKey,
        children: [
          AnimatedPositioned(
            duration: dragging ? Duration.zero : tokens.motion.standard,
            curve: tokens.motion.standardCurve,
            left: indicatorLeft,
            top: 0,
            bottom: 0,
            width: selectedWidth,
            // Cache the pill's decoration as its own layer — left/width drive
            // the `AnimatedPositioned` translate/resize but the pill visuals
            // don't change, so the layer can be reused instead of repainted
            // every drag/animation frame.
            child: RepaintBoundary(
              child: UiBox(
                background: c.surface,
                border: Border.all(color: c.border, width: 1),
                borderRadius: tokens.radius.mdAll,
              ),
            ),
          ),
          for (var i = 0; i < widget.tabs.length; i++)
            AnimatedPositioned(
              duration: tokens.motion.standard,
              curve: tokens.motion.standardCurve,
              left: layout.lefts[i],
              top: 0,
              bottom: 0,
              width: layout.widths[i],
              child: SizedBox.expand(
                key: Key('ui_tabs_slot_$i'),
                child: _TabButton(
                  tab: widget.tabs[i],
                  selected: i == selectedIndex,
                  onTap: () => widget.onChanged(i),
                ),
              ),
            ),
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
              onHorizontalDragUpdate: (d) => _updateDrag(d, layout, maxLeft),
              onHorizontalDragEnd: (_) => _endDrag(layout),
              onHorizontalDragCancel: _cancelDrag,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _naturalWidthsFor({
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final labels = [for (final t in widget.tabs) t.label];
    final hasIcons = [for (final t in widget.tabs) t.icon != null];
    if (_cachedNaturalWidths != null &&
        listEquals(_cachedLabels, labels) &&
        listEquals(_cachedHasIcons, hasIcons) &&
        _cachedTextStyle == textStyle &&
        _cachedTextDirection == textDirection &&
        _cachedTextScaler == textScaler) {
      return _cachedNaturalWidths!;
    }
    final widths = [
      for (final tab in widget.tabs)
        _measureNaturalWidth(
          tab,
          textStyle: textStyle,
          textDirection: textDirection,
          textScaler: textScaler,
        ),
    ];
    _cachedLabels = labels;
    _cachedHasIcons = hasIcons;
    _cachedTextStyle = textStyle;
    _cachedTextDirection = textDirection;
    _cachedTextScaler = textScaler;
    _cachedNaturalWidths = widths;
    return widths;
  }

  static double _measureNaturalWidth(
    UiTab tab, {
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: tab.label, style: textStyle),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final iconWidth =
        tab.icon == null ? 0.0 : _kLiquidTabIconSize + _kLiquidTabIconGap;
    return painter.width + iconWidth + _kLiquidTabHorizontalPadding * 2;
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final UiTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      onPressed: onTap,
      minTapSize: 0,
      semanticsLabel: tab.label,
      builder: (context, state, _) {
        return UiFocusRing(
          visible: state.focused,
          borderRadius: tokens.radius.mdAll,
          child: AnimatedContainer(
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x3,
            ),
            alignment: Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final label = AnimatedDefaultTextStyle(
                  duration: tokens.motion.fast,
                  curve: tokens.motion.standardCurve,
                  style: tokens.typography.label.copyWith(
                    color: selected ? c.textPrimary : c.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
                final boundedWidth = constraints.hasBoundedWidth;
                return Row(
                  mainAxisSize:
                      boundedWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tab.icon != null) ...[
                      IconTheme.merge(
                        data: IconThemeData(
                          color: selected ? c.textPrimary : c.textMuted,
                          size: _kLiquidTabIconSize,
                        ),
                        child: tab.icon!,
                      ),
                      const SizedBox(width: _kLiquidTabIconGap),
                    ],
                    if (boundedWidth) Flexible(child: label) else label,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fade + subtle upward slide between tab panels.
///
/// Useful pair for [UiTabs] when the body below changes with selection.
class UiTabViews extends StatelessWidget {
  const UiTabViews({
    super.key,
    required this.index,
    required this.children,
  }) : assert(children.length > 0, 'UiTabViews requires at least one view');

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final idx = index.clamp(0, children.length - 1);
    return AnimatedSwitcher(
      duration: tokens.motion.standard,
      switchInCurve: tokens.motion.standardCurve,
      switchOutCurve: tokens.motion.standardCurve,
      transitionBuilder: (child, animation) {
        return UiSlideFadeTransition(
          animation: animation,
          beginOffset: const Offset(0, 0.04),
          child: child,
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: ValueKey<int>(idx),
        child: children[idx],
      ),
    );
  }
}
