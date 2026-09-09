part of 'bottom_tab_bar.dart';

const _kPagedArrowSize = 48.0;
const _kPagedArrowGap = 8.0;
const _kPagedIndicatorHeight = 8.0;
const _kPagedAccessoryGap = 0.0;
const _kPagedActivation = 0.92;

/// A floating bottom dock that browses destinations in small, stable sets.
///
/// Arrows only browse the dock; [onChanged] runs only for a destination tap.
/// They release from the dock as independent fluid surfaces. A contextual
/// [accessory] sits above the dock, releasing from the next arrow when present,
/// or the dock's directional end otherwise. Its scope is the selected page,
/// independent of the set being browsed.
///
/// This is an opt-in alternative to the scaffold's legacy More drawer. It is
/// always a floating dock, including when used on a narrow viewport. Prefer a
/// rail on larger screens. Sets adapt below [maxVisibleItems] only when needed
/// to preserve 44px destination targets alongside the arrow accessories.
class UiPagedBottomTabBar extends StatelessWidget {
  const UiPagedBottomTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.maxVisibleItems = 3,
    this.indicatorIdleDuration = const Duration(milliseconds: 1200),
    this.backgroundColor,
    this.floatingMaxWidth = 640,
    this.floatingHorizontalMargin = 16,
    this.floatingBottomMargin = 12,
    this.accessory,
  }) : assert(maxVisibleItems > 0);

  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int maxVisibleItems;
  final Duration indicatorIdleDuration;
  final Color? backgroundColor;
  final double floatingMaxWidth;
  final double floatingHorizontalMargin;
  final double floatingBottomMargin;
  final UiBottomTabAccessory? accessory;

  /// Height reserved above the bottom inset, shared with the scaffold so the
  /// released accessory remains inside the navigation's actual hit-test area.
  static double contentHeight(
    BuildContext context,
    Iterable<UiBottomTabItem> items, {
    UiBottomTabAccessory? accessory,
  }) =>
      resolveBottomTabBarHeight(context, items.map((item) => item.label)) +
      _kLiquidDockPadding * 2 +
      _kPagedIndicatorHeight +
      (accessory == null
          ? 0
          : math.max(
                  accessory.height,
                  accessory.collapsedHeight ?? accessory.height,
                ) +
                _kPagedAccessoryGap);

  @override
  Widget build(BuildContext context) {
    assert(!indicatorIdleDuration.isNegative);
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          0.0,
          math.min(
            floatingMaxWidth,
            constraints.maxWidth - floatingHorizontalMargin * 2,
          ),
        );
        int capacity(int arrows, int limit) => math.max(
          1,
          math.min(
            limit,
            ((available -
                        _kLiquidDockPadding * 2 -
                        arrows * (_kPagedArrowSize + _kPagedArrowGap)) /
                    44)
                .floor(),
          ),
        );
        final solo = capacity(0, maxVisibleItems);
        final end = capacity(1, maxVisibleItems);
        // Reclaim the extra arrow's slot at each end without reshuffling
        // destinations as the user browses. Keep three targets when they fit.
        final middle = capacity(2, math.min(end, math.max(3, end - 1)));
        final starts = <int>[0];
        if (items.length > solo) {
          var start = end;
          while (start < items.length) {
            starts.add(start);
            start += items.length - start <= end ? end : middle;
          }
        }
        return _PagedBottomDock(
          config: this,
          starts: starts,
          availableWidth: available,
        );
      },
    );
  }
}

class _PagedBottomDock extends StatefulWidget {
  const _PagedBottomDock({
    required this.config,
    required this.starts,
    required this.availableWidth,
  });

  final UiPagedBottomTabBar config;
  final List<int> starts;
  final double availableWidth;

  @override
  State<_PagedBottomDock> createState() => _PagedBottomDockState();
}

class _PagedBottomDockState extends State<_PagedBottomDock>
    with TickerProviderStateMixin, _BottomDockAccessoryState<_PagedBottomDock> {
  late final _paging = UiContourCrossfadeController<int>(vsync: this)
    ..addListener(_tick);
  late final _previous = UiFluidController(vsync: this)..addListener(_tick);
  late final _next = UiFluidController(vsync: this)..addListener(_tick);
  late final _indicator = UiContourController(vsync: this)..addListener(_tick);
  final _previousMotion = UiFluidSplitMotion();
  final _nextMotion = UiFluidSplitMotion();
  final _previousFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _dockFocus = FocusNode(skipTraversal: true);
  Timer? _idleTimer;
  int _page = 0;
  int _direction = 1;
  bool _initialized = false;

  UiPagedBottomTabBar get config => widget.config;
  @override
  UiBottomTabAccessory? get _accessory => config.accessory;
  @override
  double get _availableWidth => widget.availableWidth;
  int get _setCount => widget.starts.length;
  int _pageForIndex(int index) =>
      math.max(0, widget.starts.lastIndexWhere((start) => start <= index));
  bool get _hasPrevious => _page > 0;
  bool get _hasNext => _page < _setCount - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initial = !_initialized;
    if (initial) {
      _page = _pageForIndex(config.currentIndex);
      _initialized = true;
    }
    _paging.update(
      context,
      _page,
      identity: (_page, Object.hashAll(widget.starts)),
    );
    _drive(_previous, _hasPrevious, initial: initial);
    _drive(_next, _hasNext, initial: initial);
    _syncAccessory(initial: initial);
  }

  @override
  void didUpdateWidget(covariant _PagedBottomDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectionChanged =
        config.currentIndex != oldWidget.config.currentIndex;
    final capacityChanged = !listEquals(widget.starts, oldWidget.starts);
    if (selectionChanged || capacityChanged) {
      _setPage(_pageForIndex(config.currentIndex));
    } else if (_page >= _setCount) {
      _setPage(_setCount - 1);
    }
    _drive(_previous, _hasPrevious);
    _drive(_next, _hasNext);
    _syncAccessory();
  }

  void _setPage(int page) {
    _direction = page < _page ? -1 : 1;
    _page = page;
    _paging.update(
      context,
      page,
      identity: (page, Object.hashAll(widget.starts)),
    );
    _drive(_previous, _hasPrevious);
    _drive(_next, _hasNext);
  }

  void _browse(int delta) {
    final target = (_page + delta).clamp(0, _setCount - 1);
    if (target == _page) return;
    final movingFocus = delta > 0
        ? _nextFocus.hasFocus
        : _previousFocus.hasFocus;
    setState(() => _setPage(target));
    if (movingFocus && (delta > 0 ? !_hasNext : !_hasPrevious)) {
      _dockFocus.requestFocus();
    }
    _showIndicator();
  }

  void _showIndicator() {
    _idleTimer?.cancel();
    if (_setCount < 2) return;
    _indicator.open(context, duration: UiMotionDuration.fast);
    _idleTimer = Timer(config.indicatorIdleDuration, () {
      if (mounted) _indicator.close(context, duration: UiMotionDuration.fast);
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _paging.dispose();
    _previous.dispose();
    _next.dispose();
    _indicator.dispose();
    _previousFocus.dispose();
    _nextFocus.dispose();
    _dockFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final strings = UiLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tabHeight = resolveBottomTabBarHeight(
      context,
      config.items.map((e) => e.label),
    );
    final dockHeight = tabHeight + _kLiquidDockPadding * 2;
    final accessory = _retainedAccessory;
    final totalHeight = UiPagedBottomTabBar.contentHeight(
      context,
      config.items,
      accessory: accessory,
    );
    final previousFrame = _previousMotion.sample(_previous);
    final nextFrame = _nextMotion.sample(_next);
    final searchFrame = _searchMotion.sample(_search);
    final expansionFrame = _expansionMotion.sample(_expansion);
    final previous = previousFrame.geometryProgress;
    final next = nextFrame.geometryProgress;
    // The entire group spans the available width. Accessories claim space
    // from the dock, keeping their outer endpoints (and search's x) fixed.
    final dock = Rect.fromLTWH(
      previous * (_kPagedArrowSize + _kPagedArrowGap),
      totalHeight - dockHeight,
      math.max(
        1,
        widget.availableWidth -
            (previous + next) * (_kPagedArrowSize + _kPagedArrowGap),
      ),
      dockHeight,
    );
    final previousTarget = Rect.fromCenter(
      center: Offset(_kPagedArrowSize / 2, dock.center.dy),
      width: _kPagedArrowSize,
      height: _kPagedArrowSize,
    );
    final nextTarget = Rect.fromCenter(
      center: Offset(
        widget.availableWidth - _kPagedArrowSize / 2,
        dock.center.dy,
      ),
      width: _kPagedArrowSize,
      height: _kPagedArrowSize,
    );
    final previousSource = Rect.fromCenter(
      center: Offset(dock.left + _kPagedArrowSize / 2, dock.center.dy),
      width: _kPagedArrowSize,
      height: _kPagedArrowSize,
    );
    final nextSource = Rect.fromCenter(
      center: Offset(dock.right - _kPagedArrowSize / 2, dock.center.dy),
      width: _kPagedArrowSize,
      height: _kPagedArrowSize,
    );
    Rect physical(Rect rect) => rtl
        ? Rect.fromLTWH(
            widget.availableWidth - rect.right,
            rect.top,
            rect.width,
            rect.height,
          )
        : rect;
    UiFluidGeometry geometry(Rect rect) =>
        UiFluidGeometry(physical(rect), rect.shortestSide / 2);
    final color = config.backgroundColor ?? tokens.colors.surface;
    final startIndex = widget.starts[_page];
    final visible = config.items.sublist(
      startIndex,
      _hasNext ? widget.starts[_page + 1] : config.items.length,
    );
    final localIndex = config.currentIndex - startIndex;
    final bottomOffset = resolveUiEdgeAwareBottomOffset(
      context,
      minimum: config.floatingBottomMargin + tokens.spacing.x1,
      reduceSafeArea: false,
    );

    Widget arrow({
      required bool leading,
      required UiFluidController controller,
      required UiFluidSplitFrame frame,
      required Rect source,
      required Rect target,
    }) {
      final available = leading ? _hasPrevious : _hasNext;
      return Positioned.fill(
        child: Offstage(
          offstage: controller.value == 0 && !available,
          child: UiFluidSplit(
            key: Key(
              leading ? 'ui_paged_previous_split' : 'ui_paged_next_split',
            ),
            controller: controller,
            frame: frame,
            sourceGeometry: geometry(source),
            source: const SizedBox.shrink(),
            color: color,
            branches: [
              UiFluidBranch(
                geometry: geometry(target),
                shadows: tokens.shadows.md,
                child: ExcludeSemantics(
                  excluding: !available,
                  child: UiIconButton(
                    focusNode: leading ? _previousFocus : _nextFocus,
                    icon: Icon(
                      leading
                          ? UiDirectionalIcons.chevronBack(context)
                          : UiDirectionalIcons.chevronForward(context),
                    ),
                    semanticsLabel: leading
                        ? strings.previousDestinations
                        : strings.nextDestinations,
                    size: UiSize.lg,
                    onPressed: available
                        ? () => _browse(leading ? -1 : 1)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          config.floatingHorizontalMargin,
          0,
          config.floatingHorizontalMargin,
          bottomOffset,
        ),
        child: Align(
          heightFactor: 1,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: widget.availableWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Sources paint behind the retained dock/arrow surfaces, so a
                // branch visibly splits from those surfaces without a second icon.
                if (accessory != null)
                  _buildSearch(
                    context,
                    accessory,
                    searchFrame,
                    expansionFrame,
                    nextTarget,
                    physical,
                    color,
                  ),
                arrow(
                  leading: true,
                  controller: _previous,
                  frame: previousFrame,
                  source: previousSource,
                  target: previousTarget,
                ),
                arrow(
                  leading: false,
                  controller: _next,
                  frame: nextFrame,
                  source: nextSource,
                  target: nextTarget,
                ),
                UiFluidSurface(
                  key: const Key('ui_bottom_tab_dock'),
                  geometry: geometry(dock),
                  contentSize: dock.size,
                  color: color,
                  child: Padding(
                    padding: const EdgeInsets.all(_kLiquidDockPadding),
                    child: Focus(
                      focusNode: _dockFocus,
                      child: ClipRect(
                        child: IgnorePointer(
                          ignoring: _paging.progress < _kPagedActivation,
                          child: ExcludeFocus(
                            excluding: _paging.progress < _kPagedActivation,
                            child: ExcludeSemantics(
                              excluding: _paging.progress < _kPagedActivation,
                              child: Transform.translate(
                                offset: Offset(
                                  (rtl ? -1 : 1) *
                                      _direction *
                                      tokens.spacing.x4 *
                                      (1 - _paging.progress),
                                  0,
                                ),
                                child: Opacity(
                                  opacity: _paging.progress,
                                  child: _TabRow(
                                    key: ValueKey((startIndex, visible.length)),
                                    items: visible,
                                    currentIndex: localIndex >= visible.length
                                        ? -1
                                        : localIndex,
                                    onChanged: (index) {
                                      _showIndicator();
                                      config.onChanged(startIndex + index);
                                    },
                                    height: tabHeight,
                                    equalWidths: true,
                                    animateLayout: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const Key('ui_paged_shared_outline'),
                      painter: _BottomDockOutlinePainter(
                        surfaces: [
                          geometry(dock),
                          if (_previous.value > 0)
                            UiFluidGeometry.lerp(
                              geometry(previousSource),
                              geometry(previousTarget),
                              previous,
                            ),
                          if (_next.value > 0)
                            UiFluidGeometry.lerp(
                              geometry(nextSource),
                              geometry(nextTarget),
                              next,
                            ),
                          if (accessory != null)
                            UiFluidGeometry.lerp(
                              geometry(nextTarget),
                              _searchTarget(
                                accessory,
                                expansionFrame,
                                physical,
                              ),
                              searchFrame.geometryProgress,
                            ),
                        ],
                        connections: [
                          if (_previous.value > 0)
                            (
                              geometry(previousSource),
                              UiFluidGeometry.lerp(
                                geometry(previousSource),
                                geometry(previousTarget),
                                previous,
                              ),
                              fluidBridgeStrength(
                                previousFrame.contentProgress,
                              ),
                            ),
                          if (_next.value > 0)
                            (
                              geometry(nextSource),
                              UiFluidGeometry.lerp(
                                geometry(nextSource),
                                geometry(nextTarget),
                                next,
                              ),
                              fluidBridgeStrength(nextFrame.contentProgress),
                            ),
                          if (accessory != null)
                            (
                              geometry(nextTarget),
                              UiFluidGeometry.lerp(
                                geometry(nextTarget),
                                _searchTarget(
                                  accessory,
                                  expansionFrame,
                                  physical,
                                ),
                                searchFrame.geometryProgress,
                              ),
                              fluidBridgeStrength(searchFrame.contentProgress),
                            ),
                        ],
                        continuous: tokens.radius.isContinuous,
                        color: tokens.colors.border.withValues(alpha: .78),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: dockHeight,
                  height: _kPagedIndicatorHeight,
                  child: ExcludeSemantics(
                    excluding: _indicator.value == 0 || _setCount < 2,
                    child: Semantics(
                      liveRegion: true,
                      label: strings.destinationSet(_page + 1, _setCount),
                      child: Opacity(
                        key: const Key('ui_paged_indicator'),
                        opacity: _setCount < 2 ? 0 : _indicator.value,
                        child: Center(
                          child: _setCount > 5
                              ? UiText(
                                  '${_page + 1} / $_setCount',
                                  variant: UiTextVariant.caption,
                                  tone: UiTextTone.muted,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var page = 0; page < _setCount; page++)
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: tokens.spacing.x1 / 2,
                                        ),
                                        child: UiBox(
                                          width: page == _page
                                              ? tokens.spacing.x3
                                              : tokens.spacing.x1,
                                          height: tokens.spacing.x1,
                                          borderRadius: tokens.radius.pillAll,
                                          background: tokens.colors.textMuted
                                              .withValues(
                                                alpha: page == _page ? 1 : .3,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
