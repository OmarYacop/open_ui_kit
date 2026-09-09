part of 'bottom_tab_bar.dart';

/// Hit region of the drawer handle; the visible bar is centered inside it.
const _kHandleHitSize = 44.0;

/// Owns presentation and a persistable order of stable destination IDs.
class UiBottomTabDrawerController extends ChangeNotifier {
  UiBottomTabDrawerController({List<String> order = const []})
    : _order = List.unmodifiable(order.toSet());
  List<String> _order;
  bool _expanded = false;
  bool _customizing = false;
  List<String> get order => _order;
  bool get expanded => _expanded;
  bool get customizing => _customizing;
  set order(List<String> value) {
    final next = List<String>.unmodifiable(value.toSet());
    if (listEquals(next, _order)) return;
    _order = next;
    notifyListeners();
  }

  void open() {
    if (_expanded) return;
    _expanded = true;
    notifyListeners();
  }

  void close() {
    if (!_expanded && !_customizing) return;
    _expanded = _customizing = false;
    notifyListeners();
  }

  void customize() {
    _expanded = _customizing = true;
    notifyListeners();
  }

  void finishCustomizing() {
    if (!_customizing) return;
    _customizing = false;
    notifyListeners();
  }

  /// Ignores unavailable IDs and appends newly granted destinations.
  List<String> resolveOrder(Iterable<String> available) {
    final ids = available.toSet();
    return [
      ..._order.where(ids.contains),
      ...ids.where((id) => !_order.contains(id)),
    ];
  }
}

class _DrawerDestinationDrag {
  const _DrawerDestinationDrag(this.owner, this.id);
  final UiBottomTabDrawerController owner;
  final String id;
}

/// Four compact icons in a surface that expands to reveal a stationary grid.
/// Supply stable [UiBottomTabItem.id] values when persisting [controller.order].
class UiExpandingBottomTabBar extends StatelessWidget {
  const UiExpandingBottomTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.controller,
    this.maxVisibleItems = 4,
    this.backgroundColor,
    this.floatingMaxWidth = 640,
    this.floatingHorizontalMargin = 16,
    this.floatingBottomMargin = 12,
    this.accessory,
  }) : assert(maxVisibleItems > 0);
  final List<UiBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final UiBottomTabDrawerController? controller;
  final int maxVisibleItems;
  final Color? backgroundColor;
  final double floatingMaxWidth;
  final double floatingHorizontalMargin;
  final double floatingBottomMargin;
  final UiBottomTabAccessory? accessory;

  /// Default reference height. Runtime layout uses the theme navigation tokens.
  static const compactHeight = 64.0;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final safe = MediaQuery.viewPaddingOf(context);
        final width = math.max(
          1.0,
          math.min(
            floatingMaxWidth,
            constraints.maxWidth -
                safe.left -
                safe.right -
                floatingHorizontalMargin * 2,
          ),
        );
        return _ExpandingBottomDock(
          config: this,
          availableWidth: width,
          maxHeight: constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
        );
      },
    );
  }
}

class _ExpandingBottomDock extends StatefulWidget {
  const _ExpandingBottomDock({
    required this.config,
    required this.availableWidth,
    required this.maxHeight,
  });
  final UiExpandingBottomTabBar config;
  final double availableWidth;
  final double maxHeight;
  @override
  State<_ExpandingBottomDock> createState() => _ExpandingBottomDockState();
}

class _ExpandingBottomDockState extends State<_ExpandingBottomDock>
    with
        TickerProviderStateMixin,
        _BottomDockAccessoryState<_ExpandingBottomDock> {
  UiExpandingBottomTabBar get config => widget.config;
  @override
  UiBottomTabAccessory? get _accessory => config.accessory;
  @override
  double get _availableWidth => widget.availableWidth;
  late final _indicator = UiContourController(vsync: this)..addListener(_tick);
  late final _drawerMotion = UiFluidController(vsync: this)..addListener(_tick);
  final _ownedDrawer = UiBottomTabDrawerController();
  UiBottomTabDrawerController get _drawer =>
      widget.config.controller ?? _ownedDrawer;
  bool _drawerListening = false;
  double _drawerDragStartY = 0;
  double _drawerDragStartValue = 0;
  double _drawerDragExtent = 1;
  int? _pickedDestination;
  final _drawerScroll = ScrollController();
  final _gridKey = GlobalKey();
  List<int>? _dragOrder;
  String? _dragId;
  EdgeDraggingAutoScroller? _autoScroller;
  DragTargetDetails<_DrawerDestinationDrag>? _lastDragDetails;
  void Function(DragTargetDetails<_DrawerDestinationDrag>)? _previewDrag;

  void _finishDrag({bool commit = false}) {
    _autoScroller?.stopAutoScroll();
    _lastDragDetails = null;
    final order = _dragOrder;
    _dragOrder = null;
    _dragId = null;
    if (commit && order != null) {
      _drawer.order = order.map(_destinationId).toList();
    }
    if (mounted) setState(() {});
  }

  void _moveDestination(int from, int to) {
    final order = List<int>.of(_destinationOrder);
    final start = order.indexOf(from);
    final end = order.indexOf(to);
    if (start < 0 || end < 0 || start == end) return;
    order.insert(end, order.removeAt(start));
    _pickedDestination = null;
    _drawer.order = order.map(_destinationId).toList();
  }

  void _beginDrawerDrag(DragDownDetails details, double extent) {
    _drawerMotion.stop();
    _drawerDragStartY = details.globalPosition.dy;
    _drawerDragStartValue = _drawerMotion.value;
    _drawerDragExtent = extent;
  }

  void _updateDrawerDrag(DragUpdateDetails details) {
    // Never integrate local deltas from a moving target.
    _drawerMotion.value =
        (_drawerDragStartValue +
                (_drawerDragStartY - details.globalPosition.dy) /
                    _drawerDragExtent)
            .clamp(0.0, 1.0);
  }

  void _cancelDrawerDrag() => _animateDrawer(_drawer.expanded);

  void _endDrawerDrag(DragEndDetails details) {
    final open = details.velocity.pixelsPerSecond.dy.abs() > 300
        ? details.velocity.pixelsPerSecond.dy < 0
        : _drawerMotion.value > .4;
    if (open) {
      _drawer.open();
    } else {
      _drawer.close();
    }
    _animateDrawer(open);
  }

  void _animateDrawer(bool open, {bool initial = false}) {
    final target = open ? 1.0 : 0.0;
    if (initial) {
      _drawerMotion.value = target;
      return;
    }
    if (_drawerMotion.value == target && !_drawerMotion.isAnimating) return;
    final duration = UiMotionDuration.custom(
      Duration(
        milliseconds:
            (UiThemeTokens.of(context)
                        .bottomNavigation
                        .drawerDuration
                        .inMilliseconds *
                    (open ? 1.0 : .5) *
                    (target - _drawerMotion.value).abs())
                .round(),
      ),
    ).resolve(context);
    _drawerMotion.animateTo(
      target,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  void _drawerChanged() {
    _animateDrawer(_drawer.expanded);
    if (_drawer.customizing) {
      _indicator.open(context, duration: UiMotionDuration.fast);
    } else {
      _indicator.close(context, duration: UiMotionDuration.fast);
    }
    if (!_drawer.customizing) {
      _autoScroller?.stopAutoScroll();
      _dragOrder = null;
      _dragId = null;
    }
    if (!_drawer.expanded) {
      _pickedDestination = null;
      if (_drawerScroll.hasClients) _drawerScroll.jumpTo(0);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initial = !_drawerListening;
    if (!_drawerListening) {
      _drawerListening = true;
      _drawer.addListener(_drawerChanged);
      _animateDrawer(_drawer.expanded, initial: true);
      if (_drawer.customizing) {
        _indicator.open(
          context,
          duration: const UiMotionDuration.custom(Duration.zero),
        );
      }
    }
    _syncAccessory(initial: initial);
  }

  @override
  void didUpdateWidget(covariant _ExpandingBottomDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.controller != widget.config.controller) {
      (oldWidget.config.controller ?? _ownedDrawer).removeListener(
        _drawerChanged,
      );
      _drawer.addListener(_drawerChanged);
      _drawerChanged();
    }
    if (!listEquals(
      oldWidget.config.items.map((i) => i.id).toList(),
      config.items.map((i) => i.id).toList(),
    )) {
      _dragOrder = null;
      _dragId = null;
    }
    _syncAccessory();
  }

  @override
  void dispose() {
    if (_drawerListening) _drawer.removeListener(_drawerChanged);
    _autoScroller?.stopAutoScroll();
    _ownedDrawer.dispose();
    _drawerMotion.dispose();
    _drawerScroll.dispose();
    _indicator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildDrawer(context);

  String _destinationId(int index) => config.items[index].id ?? '$index';
  List<int> get _destinationOrder {
    final ids = [
      for (var i = 0; i < config.items.length; i++) _destinationId(i),
    ];
    assert(ids.toSet().length == ids.length, 'Destination IDs must be unique');
    return _drawer.resolveOrder(ids).map(ids.indexOf).toList();
  }

  void _selectDrawerDestination(int index) {
    if (_drawer.customizing) {
      if (_pickedDestination == null) {
        _pickedDestination = index;
        _tick();
      } else {
        _moveDestination(_pickedDestination!, index);
        _pickedDestination = null;
        _tick();
      }
      return;
    }
    _drawer.close();
    config.onChanged(index);
  }

  Widget _buildDrawer(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    // Icon geometry grown for the system font size; every formula below
    // (tile centering, row height, dock height) reads the scaled values so
    // the icon stays centred in the compact surface at any text scale.
    final nav = resolveScaledBottomNavigationTokens(context);
    final strings = UiLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final p = _drawerMotion.value.clamp(0.0, 1.0);
    final compactColumns = math.min(
      config.items.length,
      math.min(
        config.maxVisibleItems,
        math.max(1, (widget.availableWidth / nav.iconArea).floor()),
      ),
    );
    // Labels truncate within the same columns as the compact dock. A long
    // localized word must not add an entire row to the expanded navigation.
    final columns = compactColumns;
    final rows = (config.items.length / columns).ceil();
    final labelMetrics = TextPainter(
      text: TextSpan(text: 'M', style: tokens.typography.caption),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final textHeight = labelMetrics.height;
    labelMetrics.dispose();
    final rowHeight = math.max(
      nav.minRowHeight,
      ((nav.iconArea + nav.iconSize) / 2 + nav.iconTitleGap) + textHeight,
    );
    final contentHeight =
        (nav.compactHeight - nav.iconArea) / 2 +
        rowHeight * rows +
        nav.gridBottomPadding +
        nav.editActionHeight * _indicator.value;
    final compactBottom = resolveUiEdgeAwareBottomOffset(
      context,
      minimum: config.floatingBottomMargin + tokens.spacing.x1,
      reduceSafeArea: true,
    );
    final expandedBottom = math.max(
      8.0,
      MediaQuery.viewPaddingOf(context).bottom * .25,
    );
    final bottom = lerpDouble(compactBottom, expandedBottom, p)!;
    final accessory = _retainedAccessory;
    // The drag handle sits just above the icon tiles; its 44pt hit region may
    // extend above the dock, so reserve that clearance when nothing else does.
    final handleCenter =
        (nav.compactHeight - nav.iconArea) / 2 - nav.handleThickness / 2 - 2;
    final handleClearance = math.max(0.0, _kHandleHitSize / 2 - handleCenter);
    final restingAccessoryHeight = accessory == null
        ? handleClearance
        : math.max(
                accessory.height,
                accessory.collapsedHeight ?? accessory.height,
              ) +
              nav.accessoryGap;
    final maxHeight = math.max(
      nav.compactHeight,
      widget.maxHeight -
          MediaQuery.paddingOf(context).top -
          bottom -
          restingAccessoryHeight -
          handleClearance,
    );
    final expandedHeight = math.min(contentHeight, maxHeight);
    final height = lerpDouble(nav.compactHeight, expandedHeight, p)!;
    final extraWidth = math.min(8.0, config.floatingHorizontalMargin) * p;
    // The visible top edge moves by both height and bottom inset; a gesture
    // freezes that travel when it starts.
    final drawerDragExtent = math.max(
      1.0,
      expandedHeight - nav.compactHeight + expandedBottom - compactBottom,
    );
    // Grow the space above the dock so the accessory has real, hittable
    // bounds above the keyboard while the dock stays at the physical edge.
    final accessoryLift = accessory == null
        ? 0.0
        : math.max(
            0.0,
            UiKeyboardGeometry.currentInsetOf(context) - bottom - height,
          );
    final accessoryHeight = restingAccessoryHeight + accessoryLift;
    final totalHeight = height + accessoryHeight;
    final color = config.backgroundColor ?? tokens.colors.surface;
    final dockRect = Rect.fromLTWH(
      -extraWidth,
      accessoryHeight,
      widget.availableWidth + extraWidth * 2,
      height,
    );
    // Safe-area geometry is a portable fallback; hardware corner radii are
    // not consistently available through public cross-platform APIs.
    final expandedRadius = math.max(
      tokens.radius.xl.x,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    // A bottom safe inset is not a hardware corner radius. Use a conservative
    // window-corner envelope, then inset its curvature by the dock's gap.
    // This keeps the low resting edge without squaring into device corners.
    final bottomRadius = math.max(
      expandedRadius,
      MediaQuery.viewPaddingOf(context).bottom * 2 -
          math.min(
            config.floatingHorizontalMargin - extraWidth,
            expandedBottom,
          ),
    );
    final corners = BorderRadius.lerp(
      BorderRadius.circular(nav.compactHeight / 2),
      BorderRadius.only(
        topLeft: Radius.circular(expandedRadius),
        topRight: Radius.circular(expandedRadius),
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      ),
      p,
    )!;
    final dock = UiFluidGeometry(dockRect, corners.topLeft.x, corners: corners);
    Rect physical(Rect rect) => rtl
        ? Rect.fromLTWH(
            widget.availableWidth - rect.right,
            rect.top,
            rect.width,
            rect.height,
          )
        : rect;
    final sourceRect = Rect.fromLTWH(
      widget.availableWidth - nav.iconArea,
      accessoryHeight + (nav.compactHeight - nav.iconArea) / 2,
      nav.iconArea,
      nav.iconArea,
    );
    final source = UiFluidGeometry(physical(sourceRect), nav.iconArea / 2);
    final searchFrame = _searchMotion.sample(_search);
    final expansionFrame = _expansionMotion.sample(_expansion);
    final order = _dragOrder ?? _destinationOrder;
    // Visiting an overflow page only substitutes the final compact slot.
    // The expanded/editing grid and persisted order stay canonical.
    if (_dragOrder == null && !_drawer.expanded && p == 0) {
      final selectedPosition = order.indexOf(config.currentIndex);
      if (selectedPosition >= compactColumns) {
        final displaced = order[compactColumns - 1];
        order[compactColumns - 1] = config.currentIndex;
        order[selectedPosition] = displaced;
      }
    }
    final revealed = p > .98;
    final editing = _drawer.customizing;
    final gridWidth = math.max(
      1.0,
      widget.availableWidth - 2 * nav.gridHorizontalInset,
    );
    Widget destination(int index, int position) {
      final item = config.items[index];
      final label = editing && _pickedDestination != null
          ? strings.moveDestination(item.label)
          : item.label;
      final enabled = position < compactColumns || revealed;
      Widget iconTile() => UiBox(
        width: nav.iconArea,
        height: nav.iconArea,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: nav.selectionInset,
              top: nav.selectionInset,
              right: nav.selectionInset,
              bottom: nav.selectionInset,
              child: UiBox(
                borderRadius: tokens.radius.lgAll,
                background: _pickedDestination == index
                    ? tokens.colors.primary.withValues(alpha: .14)
                    : index == config.currentIndex
                    ? tokens.colors.surfaceMuted
                    : null,
              ),
            ),
            Center(
              child: IconTheme(
                data: IconThemeData(
                  size: nav.iconSize,
                  applyTextScaling: false,
                  color: index == config.currentIndex
                      ? tokens.colors.textPrimary
                      : tokens.colors.textMuted,
                ),
                child:
                    (index == config.currentIndex ? item.activeIcon : null) ??
                    item.icon ??
                    const SizedBox.shrink(),
              ),
            ),
            if ((item.badge ?? 0) > 0)
              PositionedDirectional(
                end: -2,
                top: -2,
                child: UiBox(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  borderRadius: tokens.radius.pillAll,
                  background: tokens.colors.primary,
                  child: UiText(
                    item.badge! > 99 ? '99+' : item.badge.toString(),
                    variant: UiTextVariant.caption,
                    style: TextStyle(color: tokens.colors.onPrimary),
                  ),
                ),
              ),
          ],
        ),
      );
      Widget tile({bool feedback = false}) => feedback
          ? iconTile()
          : SizedBox(
              height: rowHeight,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  iconTile(),
                  Positioned(
                    top: ((nav.iconArea + nav.iconSize) / 2 + nav.iconTitleGap),
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: position < compactColumns ? p : 1,
                      // Side padding keeps neighbouring labels apart and
                      // lets long labels ellipsize before touching the edge.
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.x1,
                        ),
                        child: UiText(
                          item.label,
                          variant: UiTextVariant.caption,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
      final child = UiPressable(
        builder: (context, state, child) => UiFocusRing(
          visible: state.focused,
          borderRadius: tokens.radius.lgAll,
          child: child!,
        ),
        key: ValueKey('ui_drawer_destination_${_destinationId(index)}'),
        onPressed: enabled ? () => _selectDrawerDestination(index) : null,
        child: Semantics(
          onLongPress: enabled && !editing ? _drawer.customize : null,
          label: label,
          selected: index == config.currentIndex,
          button: true,
          excludeSemantics: true,
          child: _DrawerEditingWiggle(
            strength: revealed ? _indicator.value : 0,
            seed: index,
            period: nav.wigglePeriod,
            angle: nav.wiggleAngle,
            child: tile(),
          ),
        ),
      );
      return ExcludeFocus(
        excluding: !enabled,
        child: ExcludeSemantics(
          excluding: !enabled,
          child: UiDraggable<_DrawerDestinationDrag>(
            enabled: enabled,
            activation: UiDragActivation.adaptive,
            data: _DrawerDestinationDrag(_drawer, _destinationId(index)),
            semanticLabel: item.label,
            decorateFeedback: false,
            childWhenDragging: const SizedBox.expand(),
            feedbackBuilder: (_) => tile(),
            onDragStarted: () {
              _dragOrder = List.of(_destinationOrder);
              _dragId = _destinationId(index);
              _pickedDestination = null;
              _drawer.customize();
            },
            onDragEnd: (_) => _finishDrag(),
            child: child,
          ),
        ),
      );
    }

    final cellWidth = gridWidth / columns;
    void previewAt(DragTargetDetails<_DrawerDestinationDrag> details) {
      if (_dragOrder == null || details.data.id != _dragId) return;
      final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      _lastDragDetails = details;
      final scrollable = Scrollable.maybeOf(_gridKey.currentContext!);
      if (scrollable != null) {
        if (_autoScroller?.scrollable != scrollable) {
          _autoScroller?.stopAutoScroll();
          _autoScroller = EdgeDraggingAutoScroller(
            scrollable,
            velocityScalar: 18,
            onScrollViewScrolled: () {
              final details = _lastDragDetails;
              if (mounted && details != null) _previewDrag?.call(details);
            },
          );
        }
        _autoScroller!.startAutoScrollIfNecessary(
          Rect.fromCenter(
            center: details.offset + Offset(cellWidth / 2, rowHeight / 2),
            width: 16,
            height: 16,
          ),
        );
      }
      // Feedback keeps the cell's dimensions. Its center identifies the slot.
      final point = box.globalToLocal(
        details.offset + Offset(cellWidth / 2, rowHeight / 2),
      );
      final x = rtl ? gridWidth - point.dx : point.dx;
      final column = (x / cellWidth).floor().clamp(0, columns - 1);
      final row = (point.dy / rowHeight).floor().clamp(0, rows - 1);
      final target = (row * columns + column).clamp(0, order.length - 1);
      final from = _dragOrder!.indexWhere((i) => _destinationId(i) == _dragId);
      if (from >= 0 && from != target) {
        setState(() => _dragOrder!.insert(target, _dragOrder!.removeAt(from)));
      }
    }

    _previewDrag = previewAt;
    final grid = DragTarget<_DrawerDestinationDrag>(
      onWillAcceptWithDetails: (details) =>
          identical(details.data.owner, _drawer) &&
          _destinationOrder.any((i) => _destinationId(i) == details.data.id),
      onMove: previewAt,
      onAcceptWithDetails: (details) {
        if (details.data.id == _dragId && _drawer.customizing) {
          _finishDrag(commit: true);
        }
      },
      onLeave: (_) => _autoScroller?.stopAutoScroll(),
      builder: (_, candidates, rejected) => SizedBox(
        key: _gridKey,
        width: gridWidth,
        height: rows * rowHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final index in _destinationOrder)
              AnimatedPositionedDirectional(
                key: ValueKey(_destinationId(index)),
                duration:
                    MediaQuery.disableAnimationsOf(context) ||
                        _dragOrder == null
                    ? Duration.zero
                    : nav.reorderDuration,
                curve: tokens.motion.standardCurve,
                start: lerpDouble(
                  (order.indexOf(index) % compactColumns) *
                      gridWidth /
                      compactColumns,
                  (order.indexOf(index) % columns) * cellWidth,
                  p,
                ),
                top: lerpDouble(
                  (order.indexOf(index) ~/ compactColumns) * rowHeight,
                  (order.indexOf(index) ~/ columns) * rowHeight,
                  p,
                ),
                width: lerpDouble(gridWidth / compactColumns, cellWidth, p),
                height: rowHeight,
                child: destination(index, order.indexOf(index)),
              ),
          ],
        ),
      ),
    );
    final content = SizedBox(
      height: widget.maxHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_drawer.expanded && p == 0,
              child: GestureDetector(
                onTap: _drawer.close,
                child: ColoredBox(
                  color: tokens.colors.overlay.withValues(
                    alpha: p * nav.scrimOpacity,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left:
                config.floatingHorizontalMargin +
                MediaQuery.viewPaddingOf(context).left,
            right:
                config.floatingHorizontalMargin +
                MediaQuery.viewPaddingOf(context).right,
            bottom: bottom,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: widget.availableWidth,
                height: totalHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (accessory != null)
                      _buildSearch(
                        context,
                        accessory,
                        searchFrame,
                        expansionFrame,
                        sourceRect,
                        physical,
                        color,
                      ),
                    UiFluidSurface(
                      key: const Key('ui_expanding_dock_surface'),
                      geometry: dock,
                      contentSize: Size(
                        widget.availableWidth + 16,
                        expandedHeight,
                      ),
                      alignment: Alignment.topCenter,
                      fit: BoxFit.none,
                      color: color,
                      shadows: tokens.shadows.md,
                      child: Stack(
                        children: [
                          Positioned(
                            top: (nav.compactHeight - nav.iconArea) / 2,
                            left: 0,
                            right: 0,
                            bottom: nav.editActionHeight * _indicator.value,
                            child: SingleChildScrollView(
                              controller: _drawerScroll,
                              physics: revealed
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: Center(child: grid),
                            ),
                          ),
                          if (editing || _indicator.value > 0)
                            PositionedDirectional(
                              bottom: nav.checkCornerInset,
                              end: nav.checkCornerInset,
                              child: Opacity(
                                opacity: _indicator.value,
                                child: UiIconButton(
                                  key: const Key(
                                    'ui_drawer_finish_customizing',
                                  ),
                                  icon: const Icon(LucideIcons.check),
                                  semanticsLabel:
                                      strings.finishCustomizingDestinations,
                                  intent: UiIntent.secondary,
                                  borderWidth: 0,
                                  borderRadius: tokens.radius.pillAll,
                                  onPressed: !editing
                                      ? null
                                      : () {
                                          _pickedDestination = null;
                                          _drawer.finishCustomizing();
                                        },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Wide drag band: the whole compact dock (and the strip
                    // above the grid once expanded) drives the deck, so users
                    // need not find the 32pt pill. Translucent so taps and
                    // hold-to-reorder on the tiles below still win the arena.
                    if (!editing && _dragOrder == null)
                      Positioned(
                        top: accessoryHeight,
                        left: -extraWidth,
                        width: widget.availableWidth + extraWidth * 2,
                        height: lerpDouble(
                          nav.compactHeight,
                          (nav.compactHeight - nav.iconArea) / 2 +
                              nav.handleThickness +
                              8,
                          p,
                        )!,
                        child: ExcludeSemantics(
                          child: RawGestureDetector(
                            behavior: HitTestBehavior.translucent,
                            gestures: {
                              VerticalDragGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                    VerticalDragGestureRecognizer
                                  >(
                                    () => VerticalDragGestureRecognizer(
                                      debugOwner: this,
                                      // Mouse drags on tiles reorder
                                      // immediately; keep them out of the band.
                                      supportedDevices: const {
                                        PointerDeviceKind.touch,
                                        PointerDeviceKind.stylus,
                                        PointerDeviceKind.invertedStylus,
                                        PointerDeviceKind.trackpad,
                                      },
                                    ),
                                    (recognizer) {
                                      recognizer.dragStartBehavior =
                                          DragStartBehavior.down;
                                      recognizer.onDown = (details) {
                                        _beginDrawerDrag(
                                          details,
                                          drawerDragExtent,
                                        );
                                      };
                                      recognizer.onUpdate = _updateDrawerDrag;
                                      recognizer.onCancel = _cancelDrawerDrag;
                                      recognizer.onEnd = _endDrawerDrag;
                                    },
                                  ),
                            },
                          ),
                        ),
                      ),
                    Positioned(
                      top: accessoryHeight + handleCenter - _kHandleHitSize / 2,
                      left: (widget.availableWidth - _kHandleHitSize) / 2,
                      width: _kHandleHitSize,
                      height: _kHandleHitSize,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          dragStartBehavior: DragStartBehavior.down,
                          onVerticalDragDown: (details) =>
                              _beginDrawerDrag(details, drawerDragExtent),
                          onVerticalDragUpdate: _updateDrawerDrag,
                          onVerticalDragCancel: _cancelDrawerDrag,
                          onVerticalDragEnd: _endDrawerDrag,
                          child: UiPressable(
                            builder: (context, state, child) => UiFocusRing(
                              visible: state.focused,
                              borderRadius: tokens.radius.lgAll,
                              child: child!,
                            ),
                            key: const Key('ui_drawer_handle'),
                            onPressed: () => _drawer.expanded
                                ? _drawer.close()
                                : _drawer.open(),
                            child: Semantics(
                              button: true,
                              label: _drawer.expanded
                                  ? strings.collapseDestinations
                                  : strings.showAllDestinations,
                              child: SizedBox(
                                width: _kHandleHitSize,
                                height: _kHandleHitSize,
                                child: Center(
                                  child: UiBox(
                                    width: nav.handleWidth,
                                    height: nav.handleThickness,
                                    borderRadius: tokens.radius.pillAll,
                                    background: tokens.colors.textMuted,
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
                          painter: _BottomDockOutlinePainter(
                            surfaces: [
                              dock,
                              if (accessory != null)
                                UiFluidGeometry.lerp(
                                  source,
                                  _searchTarget(
                                    accessory,
                                    expansionFrame,
                                    physical,
                                  ),
                                  searchFrame.geometryProgress,
                                ),
                            ],
                            connections: [
                              if (accessory != null)
                                (
                                  source,
                                  UiFluidGeometry.lerp(
                                    source,
                                    _searchTarget(
                                      accessory,
                                      expansionFrame,
                                      physical,
                                    ),
                                    searchFrame.geometryProgress,
                                  ),
                                  fluidBridgeStrength(
                                    searchFrame.contentProgress,
                                  ),
                                ),
                            ],
                            continuous: tokens.radius.isContinuous,
                            color: tokens.colors.border.withValues(alpha: .78),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    void dismiss() {
      if (config.accessory?.expanded ?? false) {
        config.accessory?.onLeadingPressed?.call();
      } else if (_drawer.customizing) {
        _pickedDestination = null;
        _drawer.finishCustomizing();
      } else {
        _drawer.close();
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): dismiss,
        const SingleActivator(LogicalKeyboardKey.f2): _drawer.customize,
      },
      child: PopScope<Object?>(
        canPop: widget.config.controller != null || !_drawer.expanded,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && widget.config.controller == null) dismiss();
        },
        child: BlockSemantics(blocking: _drawer.expanded, child: content),
      ),
    );
  }
}

/// Repaints cells independently; the glass surface never joins the wiggle ticker.
class _DrawerEditingWiggle extends StatefulWidget {
  const _DrawerEditingWiggle({
    required this.strength,
    required this.seed,
    required this.period,
    required this.angle,
    required this.child,
  });
  final double strength;
  final int seed;
  final Duration period;
  final double angle;
  final Widget child;
  @override
  State<_DrawerEditingWiggle> createState() => _DrawerEditingWiggleState();
}

class _DrawerEditingWiggleState extends State<_DrawerEditingWiggle>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: Duration(
      microseconds: (widget.period.inMicroseconds * (1 + widget.seed % 3 * .06))
          .round(),
    ),
  );
  bool _reduced = false;
  void _sync() {
    if (widget.strength > 0 &&
        !_reduced &&
        widget.period > Duration.zero &&
        widget.angle > 0) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_DrawerEditingWiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _motion.stop();
      _motion.duration = Duration(
        microseconds: math.max(
          1,
          (widget.period.inMicroseconds * (1 + widget.seed % 3 * .06)).round(),
        ),
      );
    }
    _sync();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (_, child) => Transform.rotate(
        angle: _reduced || widget.period <= Duration.zero
            ? 0
            : math.sin(_motion.value * math.pi * 2 + widget.seed * 1.7) *
                  widget.angle *
                  widget.strength,
        child: child,
      ),
    ),
  );
}
