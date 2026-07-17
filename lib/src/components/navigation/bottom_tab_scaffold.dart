import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/intl/intl.dart';
import '../surfaces/ui_drawer.dart';
import '../surfaces/ui_responsive_navigation_scaffold.dart';
import 'bottom_tab_bar.dart';
import 'ui_navigation_drawer.dart';

const _kBottomTabScaffoldControlWidth = 72.0;
const _kBottomTabScaffoldDockPadding = 6.0;

class UiBottomTabRailConfig {
  const UiBottomTabRailConfig({
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
}

typedef UiBottomTabRailBuilder = Widget Function(
  BuildContext context,
  UiBottomTabRailConfig config,
);

typedef UiBottomTabOverflowDrawerBuilder = Widget Function(
  BuildContext context,
  UiDrawerController<void> controller,
);

/// Page shell with a [UiBottomTabBar] and per-tab state preservation.
///
/// Uses an [IndexedStack] so each tab's subtree is built once and kept
/// alive across switches — scroll position, controllers, and
/// `StatefulWidget` state all survive. Set `preserveState: false` to
/// tear down off-screen tabs (useful for tabs that pull data on mount).
class UiBottomTabScaffold extends StatelessWidget {
  const UiBottomTabScaffold({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.pages,
    this.preserveState = true,
    this.tabBarBackgroundColor,
    this.tabBarLayout = UiBottomTabBarLayout.floatingDock,
    this.tabBarAdaptiveBreakpoint = 700,
    this.tabBarFloatingMaxWidth = 640,
    this.tabBarFloatingHorizontalMargin = 16,
    this.tabBarFloatingBottomMargin = 12,
    this.convertToRailOnWideScreens = false,
    this.railBreakpoint = 600,
    this.railBuilder,
    this.bottomItems,
    this.bottomCurrentIndex,
    this.onBottomChanged,
    this.maxVisibleBottomItems = 3,
    this.overflowDrawerBuilder,
  })  : assert(
          items.length == pages.length,
          'items and pages must have the same length',
        ),
        assert(maxVisibleBottomItems > 0),
        assert(
          !convertToRailOnWideScreens || railBuilder != null,
          'railBuilder is required when convertToRailOnWideScreens is true',
        );

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<Widget> pages;

  /// When true (default), all pages are built once and kept alive in an
  /// [IndexedStack]. When false, only the current page is mounted.
  final bool preserveState;

  final Color? tabBarBackgroundColor;
  final UiBottomTabBarLayout tabBarLayout;
  final double tabBarAdaptiveBreakpoint;
  final double tabBarFloatingMaxWidth;
  final double tabBarFloatingHorizontalMargin;
  final double tabBarFloatingBottomMargin;

  /// When true, wide layouts render [railBuilder] instead of the bottom bar.
  /// Compact Android and iOS devices retain the bottom bar in landscape even
  /// when their long edge crosses [railBreakpoint].
  final bool convertToRailOnWideScreens;

  final double railBreakpoint;
  final UiBottomTabRailBuilder? railBuilder;

  /// Optional phone/tablet bottom-bar item set.
  ///
  /// Use this when the bottom bar needs an overflow item such as "More" while
  /// the canonical [items] list still maps one-to-one with [pages].
  final List<UiBottomTabItem>? bottomItems;
  final int? bottomCurrentIndex;
  final ValueChanged<int>? onBottomChanged;

  /// Maximum canonical app destinations shown directly in the bottom bar.
  ///
  /// If [items] exceeds this count while the bottom bar is active, Open UI Kit
  /// automatically appends a localized "More" control. Tapping it opens a
  /// [UiDrawer] containing every canonical item. This does not affect rail
  /// layouts; once [railBreakpoint] is reached, [railBuilder] receives the full
  /// canonical item list.
  final int maxVisibleBottomItems;

  /// Optional application-owned composition for the automatic More drawer.
  ///
  /// The scaffold still owns presentation and selection state; the builder
  /// only supplies the structured drawer content.
  final UiBottomTabOverflowDrawerBuilder? overflowDrawerBuilder;

  @override
  Widget build(BuildContext context) {
    final i = currentIndex.clamp(0, pages.length - 1);
    final body =
        preserveState ? _PreservedPageStack(index: i, pages: pages) : pages[i];
    final hasManualBottomItems = bottomItems != null ||
        bottomCurrentIndex != null ||
        onBottomChanged != null;
    final effectiveBottomItems = bottomItems ?? items;
    final effectiveBottomIndex = effectiveBottomItems.isEmpty
        ? 0
        : (bottomCurrentIndex ?? i).clamp(0, effectiveBottomItems.length - 1);
    final effectiveBottomChanged = onBottomChanged ?? onChanged;

    if (convertToRailOnWideScreens && railBuilder != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth.isFinite &&
              constraints.maxWidth >= railBreakpoint &&
              !_isCompactMobileDevice(context, railBreakpoint);
          if (useRail) {
            return UiResponsiveNavigationScaffold(
              phoneBreakpoint: railBreakpoint,
              body: body,
              sidebar: railBuilder!(
                context,
                UiBottomTabRailConfig(
                  items: items,
                  currentIndex: i,
                  onChanged: onChanged,
                ),
              ),
            );
          }

          return _BottomTabBody(
            body: body,
            items: effectiveBottomItems,
            currentIndex: effectiveBottomIndex,
            onChanged: effectiveBottomChanged,
            canonicalItems: items,
            canonicalCurrentIndex: i,
            onCanonicalChanged: onChanged,
            automaticOverflow: !hasManualBottomItems,
            maxVisibleItems: maxVisibleBottomItems,
            backgroundColor: tabBarBackgroundColor,
            layout: tabBarLayout,
            adaptiveBreakpoint: tabBarAdaptiveBreakpoint,
            floatingMaxWidth: tabBarFloatingMaxWidth,
            floatingHorizontalMargin: tabBarFloatingHorizontalMargin,
            floatingBottomMargin: tabBarFloatingBottomMargin,
            overflowDrawerBuilder: overflowDrawerBuilder,
          );
        },
      );
    }

    return _BottomTabBody(
      body: body,
      items: effectiveBottomItems,
      currentIndex: effectiveBottomIndex,
      onChanged: effectiveBottomChanged,
      canonicalItems: items,
      canonicalCurrentIndex: i,
      onCanonicalChanged: onChanged,
      automaticOverflow: !hasManualBottomItems,
      maxVisibleItems: maxVisibleBottomItems,
      backgroundColor: tabBarBackgroundColor,
      layout: tabBarLayout,
      adaptiveBreakpoint: tabBarAdaptiveBreakpoint,
      floatingMaxWidth: tabBarFloatingMaxWidth,
      floatingHorizontalMargin: tabBarFloatingHorizontalMargin,
      floatingBottomMargin: tabBarFloatingBottomMargin,
      overflowDrawerBuilder: overflowDrawerBuilder,
    );
  }

  bool _isCompactMobileDevice(BuildContext context, double breakpoint) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }

    return MediaQuery.sizeOf(context).shortestSide < breakpoint;
  }
}

/// Keeps every visited page mounted while allowing only the selected page's
/// render subtree to participate in layout.
///
/// A regular [IndexedStack] lays out every child whenever its constraints
/// change. That is unnecessary for app-shell pages whose body is tightly
/// constrained, and becomes especially costly while a navigation rail is
/// animating the body's width.
class _PreservedPageStack extends StatelessWidget {
  const _PreservedPageStack({required this.index, required this.pages});

  final int index;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: [
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
          _ActivePageLayout(
            active: pageIndex == index,
            child: pages[pageIndex],
          ),
      ],
    );
  }
}

class _ActivePageLayout extends SingleChildRenderObjectWidget {
  const _ActivePageLayout({required this.active, required super.child});

  final bool active;

  @override
  _RenderActivePageLayout createRenderObject(BuildContext context) {
    return _RenderActivePageLayout(active: active);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActivePageLayout renderObject,
  ) {
    renderObject.active = active;
  }
}

class _RenderActivePageLayout extends RenderProxyBox {
  _RenderActivePageLayout({required bool active}) : _active = active;

  bool _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsLayoutForSizedByParentChange();
  }

  @override
  bool get sizedByParent => !_active;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!_active) return constraints.smallest;
    return super.computeDryLayout(constraints);
  }

  @override
  void performResize() {
    assert(!_active);
    size = constraints.smallest;
  }

  @override
  void performLayout() {
    if (_active) super.performLayout();
  }
}

class _BottomTabBody extends StatefulWidget {
  const _BottomTabBody({
    required this.body,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    required this.canonicalItems,
    required this.canonicalCurrentIndex,
    required this.onCanonicalChanged,
    required this.automaticOverflow,
    required this.maxVisibleItems,
    required this.backgroundColor,
    required this.layout,
    required this.adaptiveBreakpoint,
    required this.floatingMaxWidth,
    required this.floatingHorizontalMargin,
    required this.floatingBottomMargin,
    required this.overflowDrawerBuilder,
  });

  final Widget body;
  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<UiBottomTabItem> canonicalItems;
  final int canonicalCurrentIndex;
  final ValueChanged<int> onCanonicalChanged;
  final bool automaticOverflow;
  final int maxVisibleItems;
  final Color? backgroundColor;
  final UiBottomTabBarLayout layout;
  final double adaptiveBreakpoint;
  final double floatingMaxWidth;
  final double floatingHorizontalMargin;
  final double floatingBottomMargin;
  final UiBottomTabOverflowDrawerBuilder? overflowDrawerBuilder;

  @override
  State<_BottomTabBody> createState() => _BottomTabBodyState();
}

class _BottomTabBodyState extends State<_BottomTabBody> {
  bool _moreDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflow = widget.automaticOverflow
            ? _resolveOverflowLayout(context, constraints)
            : null;
        final resolvedItems = overflow?.items ?? widget.items;
        final resolvedCurrentIndex = overflow == null
            ? widget.currentIndex
            : _moreDrawerOpen
                ? overflow.moreIndex
                : overflow.currentIndex;
        final resolvedChanged = overflow == null
            ? widget.onChanged
            : (int index) => _handleOverflowTap(context, overflow, index);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: widget.body),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: UiBottomTabBar(
                items: resolvedItems,
                currentIndex: resolvedCurrentIndex,
                onChanged: resolvedChanged,
                backgroundColor: widget.backgroundColor,
                layout: widget.layout,
                adaptiveBreakpoint: widget.adaptiveBreakpoint,
                floatingMaxWidth: widget.floatingMaxWidth,
                floatingHorizontalMargin: widget.floatingHorizontalMargin,
                floatingBottomMargin: widget.floatingBottomMargin,
                equalWidthsWhenLastSelected: overflow != null,
              ),
            ),
          ],
        );
      },
    );
  }

  _BottomOverflowLayout? _resolveOverflowLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    if (widget.canonicalItems.length <= 1) return null;

    final capacity = _resolveBottomControlCapacity(constraints.maxWidth);
    final directLimit = widget.maxVisibleItems.clamp(
      1,
      widget.canonicalItems.length,
    );
    final needsOverflow = widget.canonicalItems.length > directLimit ||
        widget.canonicalItems.length > capacity;
    if (!needsOverflow) return null;

    final directCount = directLimit.clamp(1, (capacity - 1).clamp(1, capacity));
    final visibleIndices = List<int>.generate(directCount, (index) => index);
    final strings = UiLocalizations.of(context);
    final visibleItems = [
      for (final index in visibleIndices) widget.canonicalItems[index],
      UiBottomTabItem(
        label: strings.more,
        icon: const Icon(LucideIcons.menu),
        activeIcon: const Icon(LucideIcons.menu),
      ),
    ];
    final visibleCurrentIndex = visibleIndices.indexOf(
      widget.canonicalCurrentIndex,
    );

    return _BottomOverflowLayout(
      items: visibleItems,
      visibleCanonicalIndices: visibleIndices,
      moreIndex: visibleItems.length - 1,
      currentIndex: visibleCurrentIndex == -1
          ? visibleItems.length - 1
          : visibleCurrentIndex,
    );
  }

  int _resolveBottomControlCapacity(double availableWidth) {
    final resolvedWidth = availableWidth.isFinite
        ? (availableWidth - widget.floatingHorizontalMargin * 2)
            .clamp(0.0, widget.floatingMaxWidth)
        : widget.floatingMaxWidth;
    final capacity = ((resolvedWidth - _kBottomTabScaffoldDockPadding * 2) /
            _kBottomTabScaffoldControlWidth)
        .floor();
    return capacity.clamp(2, widget.maxVisibleItems + 1);
  }

  void _handleOverflowTap(
    BuildContext context,
    _BottomOverflowLayout overflow,
    int index,
  ) {
    if (index == overflow.moreIndex) {
      _openOverflowDrawer(context);
      return;
    }

    final canonicalIndex = overflow.visibleCanonicalIndices[index];
    widget.onCanonicalChanged(canonicalIndex);
  }

  void _openOverflowDrawer(BuildContext context) {
    if (_moreDrawerOpen) return;
    setState(() => _moreDrawerOpen = true);
    unawaited(
      _showOverflowDrawer(context).whenComplete(() {
        if (mounted) setState(() => _moreDrawerOpen = false);
      }),
    );
  }

  Future<void> _showOverflowDrawer(BuildContext context) {
    return UiDrawerScope.show<void>(
      context,
      side: UiDrawerSide.start,
      variant: UiDrawerVariant.stacked,
      blurBackdrop: true,
      controlledBuilder: (drawerContext, controller) =>
          widget.overflowDrawerBuilder?.call(drawerContext, controller) ??
          _defaultOverflowDrawer(drawerContext, controller),
      builder: (_) => const SizedBox.shrink(),
    );
  }

  Widget _defaultOverflowDrawer(
    BuildContext context,
    UiDrawerController<void> controller,
  ) {
    final strings = UiLocalizations.of(context);
    return UiNavigationDrawer(
      title: strings.more,
      variant: UiDrawerVariant.stacked,
      destinations: [
        for (var index = 0; index < widget.canonicalItems.length; index++)
          UiNavigationDrawerDestination(
            label: widget.canonicalItems[index].label,
            icon: widget.canonicalCurrentIndex == index
                ? widget.canonicalItems[index].activeIcon ??
                    widget.canonicalItems[index].icon
                : widget.canonicalItems[index].icon,
            badgeCount: widget.canonicalItems[index].badge,
            selected: widget.canonicalCurrentIndex == index,
            onPressed: () {
              controller.dismiss();
              widget.onCanonicalChanged(index);
            },
          ),
      ],
    );
  }
}

class _BottomOverflowLayout {
  const _BottomOverflowLayout({
    required this.items,
    required this.visibleCanonicalIndices,
    required this.moreIndex,
    required this.currentIndex,
  });

  final List<UiBottomTabItem> items;
  final List<int> visibleCanonicalIndices;
  final int moreIndex;
  final int currentIndex;
}
