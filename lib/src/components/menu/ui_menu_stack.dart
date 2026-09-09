import '../../foundation/primitives/ui_corner_clip.dart';
// Public constructor names remain stable while getters expose resolved defaults.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/motion/ui_fluid_motion.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/tokens/ui_menu_tokens.dart';
import '../surfaces/ui_fluid_surface.dart';
import 'ui_dropdown_menu.dart';
import 'ui_menu_transition.dart';

/// Bridges a held gesture from an anchor into its separately mounted popup.
/// Attach to one stack at a time; the anchor forwards its long-press updates.
class UiMenuGestureController {
  _UiMenuStackState? _state;
  void begin() => _state?._beginExternalDrag();
  void update(Offset globalPosition) => _state?._updateDrag(globalPosition);
  void end(LongPressEndDetails details) => _state?._endDrag(details);
  void cancel() => _state?._clearDrag();
  void back() => _state?._back();
  void focus() {
    final state = _state;
    if (state != null) {
      final page = state._pages[state._activeIndex];
      final nodes = page.nodes.values.where(
        (node) => node.canRequestFocus && node.context != null,
      );
      if (nodes.isNotEmpty) {
        nodes.first.requestFocus();
      } else {
        page.focus.requestFocus();
      }
    }
  }
}

/// Bounded menu stack. Submenus morph from their selected row,
/// covering a retained parent at [parentScale]. The caller owns root overlay
/// placement/dismissal; Back and Escape pop one nested level.
class UiMenuStack extends StatefulWidget {
  const UiMenuStack({
    super.key,
    required this.title,
    required this.items,
    double? parentScale,
    @Deprecated('Use scrimOpacity instead. Scheduled removal: 1.0.0.')
    this.blurSigma = 0,
    double? scrimOpacity,
    double? backdropBlurSigma,
    double? surfaceOpacity,
    Duration? submenuDwellDuration,
    this.backLabel = 'Back',
    this.onSelected,
    this.onDismiss,
    this.closeOnSelect = true,
    this.dismissOnTapOutside = true,
    this.dismissOnAncestorScroll = true,
    Duration? closeDuration,
    this.onDepthChanged,
    this.handleSystemBack = true,
    this.gestureController,
    this.rootController,
    this.rootSourceGeometry,
    this.rootSourceColor,
    this.rootInitialSourceGeometry,
    this.rootInitialSourceColor,
    this.rootInitialSourceBorder,
    this.rootSourceBorder,
    this.rootSourceShadows,
    this.rootSourceFit = BoxFit.contain,
    this.rootMenuBounds,
    this.rootAlignBottom = false,
    this.rootTrigger,
  }) : _parentScale = parentScale,
       _scrimOpacity = scrimOpacity,
       _backdropBlurSigma = backdropBlurSigma,
       _surfaceOpacity = surfaceOpacity,
       _submenuDwellDuration = submenuDwellDuration,
       _closeDuration = closeDuration,
       assert(
         (rootController == null &&
                 rootSourceGeometry == null &&
                 rootTrigger == null) ||
             (rootController != null &&
                 rootSourceGeometry != null &&
                 rootTrigger != null),
       );

  /// Optional More-to-menu presentation. Supply all three root properties.
  /// The caller owns the controller; outside dismissal closes this presentation
  /// as a whole, retaining nested pages until the compact endpoint is reached.
  /// An anchored host can handle route Back through its gesture controller.
  final bool handleSystemBack;
  final UiMenuGestureController? gestureController;
  final UiFluidController? rootController;
  final UiFluidGeometry? rootSourceGeometry;

  /// Actual compact trigger paint, interpolated into the expanded menu style.
  /// Omission preserves the shared menu surface at both endpoints.
  final Color? rootSourceColor;

  /// Optional current pressed frame; closing still targets the resting source.
  final UiFluidGeometry? rootInitialSourceGeometry;
  final Color? rootInitialSourceColor;
  final BorderSide? rootInitialSourceBorder;
  final BorderSide? rootSourceBorder;
  final List<BoxShadow>? rootSourceShadows;
  final BoxFit rootSourceFit;

  /// Optional bounds for expanded menus within the animation viewport.
  /// Allows the root trigger to sit outside the expanded menu's layout area.
  final Rect? rootMenuBounds;

  /// Places content-sized root menus against the bottom of their viewport.
  final bool rootAlignBottom;
  final Widget? rootTrigger;
  final String title;
  final List<UiMenuNode> items;
  final double? _parentScale;
  double get parentScale => _parentScale ?? UiMenuTokens.defaults.parentScale;
  @Deprecated('Use scrimOpacity instead. Scheduled removal: 1.0.0.')
  final double blurSigma;
  final double? _scrimOpacity;
  double get scrimOpacity =>
      _scrimOpacity ?? UiMenuTokens.defaults.scrimOpacity;

  /// Blurs content behind each translucent menu, keeping its own text sharp.
  /// Set to zero to disable. Reduced motion also disables this effect.
  final double? _backdropBlurSigma;
  double get backdropBlurSigma =>
      _backdropBlurSigma ?? UiMenuTokens.defaults.backdropBlurSigma;

  /// Translucent tint above the filtered backdrop; one makes it opaque.
  final double? _surfaceOpacity;
  double get surfaceOpacity =>
      _surfaceOpacity ?? UiMenuTokens.defaults.surfaceOpacity;

  /// Delay before a held pointer opens the submenu it is resting over.
  final Duration? _submenuDwellDuration;
  Duration get submenuDwellDuration =>
      _submenuDwellDuration ?? UiMenuTokens.defaults.submenuDwellDuration;
  final String backLabel;
  final ValueChanged<UiMenuItem>? onSelected;

  /// Requests dismissal of the caller-owned root overlay. Without a callback,
  /// the bounded stack returns to its root page.
  final VoidCallback? onDismiss;
  final bool closeOnSelect;
  final bool dismissOnTapOutside;
  final bool dismissOnAncestorScroll;
  final Duration? _closeDuration;
  Duration get closeDuration =>
      _closeDuration ?? UiMenuTokens.defaults.closeDuration;
  final ValueChanged<int>? onDepthChanged;

  @override
  State<UiMenuStack> createState() => _UiMenuStackState();
}

class _OpenSubmenuIntent extends Intent {
  const _OpenSubmenuIntent();
}

class _MenuDragTarget {
  const _MenuDragTarget(
    this.page,
    this.node,
    this.context, {
    this.back = false,
  });
  final bool back;
  final _MenuPage page;
  final UiMenuNode? node;
  final BuildContext context;
}

class _MenuPage {
  _MenuPage(
    this.title,
    this.items,
    this.controller, {
    this.source,
    this.returnFocus,
    this.opener,
    this.sourceSize,
  });
  final String title;
  final List<UiMenuNode> items;
  final UiFluidController controller;
  final UiFluidGeometry? source;
  final FocusNode? returnFocus;
  final UiMenuSubmenu? opener;
  final Size? sourceSize;
  // Input ownership follows intent, not the remaining visual spring tail.
  bool get released => controller.target == 0;
  final bodyKey = GlobalKey();
  final headerKey = GlobalKey();
  double? contentHeight;
  bool measuring = false;
  final focus = FocusScopeNode();
  final scroll = ScrollController();
  final scrollKey = GlobalKey();
  final nodes = <UiMenuNode, FocusNode>{};
  final busy = <UiMenuItem>{};
  bool focusRequested = false;
  double cover = 0, coverOrigin = 0;
  int coverRevision = -1;

  double sampleCover(double springStrength) {
    if (coverRevision != controller.revision) {
      coverOrigin = cover;
      coverRevision = controller.revision;
    }
    // Follow the same geometry response, including a new response on reversal.
    cover = controller.retargeting
        ? coverOrigin +
              (controller.target - coverOrigin) *
                  (controller.target == 0
                      ? Curves.easeOutCubic.transform(
                          controller.transitionProgress,
                        )
                      : uiFluidSpring(
                          controller.transitionProgress,
                          strength: springStrength,
                        ))
        : uiFluidSpring(
            ((controller.value - .34) / .66).clamp(0.0, 1.0),
            strength: springStrength,
          );
    return cover.clamp(0.0, 1.0);
  }

  void dispose() {
    controller.dispose();
    focus.dispose();
    scroll.dispose();
    for (final node in nodes.values) {
      node.dispose();
    }
  }
}

class _UiMenuStackState extends State<UiMenuStack>
    with TickerProviderStateMixin {
  final _viewport = GlobalKey();
  late final List<_MenuPage> _pages = [
    _MenuPage(
      widget.title,
      widget.items,
      UiFluidController(vsync: this, value: 1),
    ),
  ];
  final _rootTriggerTag = Object();
  Timer? _dwell, _dragScroll;
  _MenuDragTarget? _dragTarget;
  bool _dragging = false;
  Offset? _dragPosition;

  Object? _targetAt(Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );
    for (final entry in result.path) {
      if (entry.target case RenderMetaData(metaData: final data)) {
        if (identical(data, _rootTriggerTag) ||
            (data is _MenuDragTarget && _pages.contains(data.page))) {
          return data;
        }
      }
    }
    return null;
  }

  bool _selectable(_MenuDragTarget target) =>
      target.back ||
      switch (target.node) {
        UiMenuSubmenu(:final enabled) => enabled,
        UiMenuItem(:final enabled, :final loading) =>
          enabled && !loading && !target.page.busy.contains(target.node),
        _ => false,
      };

  void _scrollDuringDrag() {
    if (!_dragging || _dragPosition == null) return;
    final page = _pages[_activeIndex];
    final box = page.scrollKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !page.scroll.hasClients) return;
    final local = box.globalToLocal(_dragPosition!);
    if (!(Offset.zero & box.size).contains(local)) return;
    final delta = local.dy < 24
        ? -12.0
        : local.dy > box.size.height - 24
        ? 12.0
        : 0.0;
    final position = page.scroll.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    page.scroll.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dragging && _dragPosition != null) {
        _updateDrag(_dragPosition!);
      }
    });
  }

  void _clearDrag() {
    _dragScroll?.cancel();
    _dwell?.cancel();
    _dwell = null;
    _dragging = false;
    _dragPosition = null;
    if (_dragTarget != null && mounted) setState(() => _dragTarget = null);
  }

  void _beginExternalDrag() {
    _dragging = true;
    _dragScroll?.cancel();
    _dragScroll = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _scrollDuringDrag(),
    );
  }

  void _startDrag(LongPressStartDetails details) {
    final hit = _targetAt(details.globalPosition);
    if (identical(hit, _rootTriggerTag)) {
      _dragging = true;
      widget.rootController?.open(context);
    } else if (hit is _MenuDragTarget && _selectable(hit)) {
      _dragging = true;
      _updateDrag(details.globalPosition);
      if (hit.node case final UiMenuSubmenu submenu) {
        _dwell?.cancel();
        _push(hit.page, submenu, hit.context);
        setState(() => _dragTarget = null);
      }
    }
    if (_dragging) {
      _dragScroll?.cancel();
      _dragScroll = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _scrollDuringDrag(),
      );
    }
  }

  void _updateDrag(Offset position) {
    if (!_dragging) return;
    _dragPosition = position;
    final hit = _targetAt(position);
    final next = hit is _MenuDragTarget && _selectable(hit) ? hit : null;
    if (hit is _MenuDragTarget &&
        hit.node == null &&
        !hit.back &&
        _pages.indexOf(hit.page) < _activeIndex) {
      _closeDescendants(_pages.indexOf(hit.page));
    }
    if (next?.page == _dragTarget?.page && next?.node == _dragTarget?.node) {
      return;
    }
    _dwell?.cancel();
    setState(() => _dragTarget = next);
    if (next?.node is UiMenuSubmenu) {
      _dwell = Timer(
        (widget._submenuDwellDuration ??
            UiThemeTokens.of(context).menu.submenuDwellDuration),
        () {
          if (!mounted || !_dragging || _dragPosition == null) return;
          final current = _targetAt(_dragPosition!);
          if (current is! _MenuDragTarget ||
              current.page != next!.page ||
              current.node != next.node) {
            return;
          }
          _push(next.page, next.node! as UiMenuSubmenu, next.context);
          setState(() => _dragTarget = null);
        },
      );
    }
  }

  void _endDrag(LongPressEndDetails details) {
    if (!_dragging) return;
    final target = _dragTarget;
    final hit = _targetAt(details.globalPosition);
    _clearDrag();
    if (target != null &&
        hit is _MenuDragTarget &&
        hit.page == target.page &&
        hit.node == target.node &&
        _selectable(hit)) {
      if (hit.back) {
        _back();
      } else if (hit.node case final UiMenuItem item) {
        _activate(hit.page, item);
      } else if (hit.node case final UiMenuSubmenu submenu) {
        _push(hit.page, submenu, hit.context);
      }
    } else if (hit == null) {
      _dismiss();
    }
  }

  bool _removalScheduled = false;
  final _tapGroup = Object();
  final _ancestorPositions = <ScrollPosition>{};
  int get _activeIndex =>
      _pages.lastIndexWhere((page) => page == _pages.first || !page.released);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final position in _ancestorPositions) {
      position.removeListener(_ancestorScrolled);
    }
    _ancestorPositions.clear();
    context.visitAncestorElements((element) {
      if (element case StatefulElement(state: final ScrollableState state)) {
        if (_ancestorPositions.add(state.position)) {
          state.position.addListener(_ancestorScrolled);
        }
      }
      return true;
    });
  }

  void _ancestorScrolled() {
    if (widget.dismissOnAncestorScroll) _dismiss();
  }

  bool get _rootClosing =>
      widget.rootController != null && widget.rootController!.target == 0;

  @override
  void initState() {
    super.initState();
    widget.gestureController?._state = this;
    widget.rootController?.addListener(_rootChanged);
  }

  int _rootRevision = -1;

  void _rootChanged() {
    if (_rootRevision != widget.rootController!.revision) {
      _rootRevision = widget.rootController!.revision;
      setState(() {});
      if (widget.rootController!.target == 1) {
        for (final page in _pages.skip(1)) {
          if (!page.controller.isAnimating &&
              !page.released &&
              page.controller.value < 1) {
            page.controller.open(context);
          }
        }
      }
    }
    if (widget.rootController!.value != 0 || _removalScheduled) return;
    _removalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removalScheduled = false;
      if (!mounted || widget.rootController?.value != 0) return;
      final removed = _pages.skip(1).toList();
      setState(() => _pages.removeRange(1, _pages.length));
      for (final page in removed) {
        page.dispose();
      }
      widget.onDepthChanged?.call(0);
    });
  }

  void _dismiss() {
    _clearDrag();
    if (widget.rootController case final controller?) {
      if (controller.target == 0) return;
      // Keep the stack intact: its layers leave together, not through a cascade
      // of independent row-return animations.
      for (final page in _pages.skip(1)) {
        page.controller.stop();
      }
      controller.close(context);
      widget.onDismiss?.call();
      return;
    }
    for (final page in _pages.skip(1)) {
      if (!page.released) {
        page.controller.close(
          context,
          duration:
              (widget._closeDuration ??
              UiThemeTokens.of(context).menu.closeDuration),
        );
      }
    }
    if (mounted) setState(() {});
    widget.onDismiss?.call();
  }

  @override
  void didUpdateWidget(UiMenuStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gestureController != widget.gestureController) {
      oldWidget.gestureController?._state = null;
      widget.gestureController?._state = this;
    }
    if (oldWidget.rootController != widget.rootController) {
      oldWidget.rootController?.removeListener(_rootChanged);
      widget.rootController?.addListener(_rootChanged);
    }
    if (oldWidget.items != widget.items || oldWidget.title != widget.title) {
      // Keep the last measured destination until the replacement content has
      // laid out. Falling back to viewport height here moves the whole surface
      // for one frame, especially for bottom-aligned card menus.
      final contentHeight = _pages.first.contentHeight;
      for (final page in _pages) {
        page.dispose();
      }
      _pages
        ..clear()
        ..add(
          _MenuPage(
            widget.title,
            widget.items,
            UiFluidController(vsync: this, value: 1),
          )..contentHeight = contentHeight,
        );
    }
  }

  void _push(_MenuPage parent, UiMenuSubmenu submenu, BuildContext rowContext) {
    if (_rootClosing) return;
    if (_pages.last != parent) {
      final parentIndex = _pages.indexOf(parent);
      if (parentIndex < 0 || !_pages[parentIndex + 1].released) return;
      final closing = _pages[parentIndex + 1];
      final reuse = closing.opener == submenu;
      final removed = _pages.sublist(parentIndex + (reuse ? 2 : 1));
      _pages.removeRange(parentIndex + (reuse ? 2 : 1), _pages.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final page in removed) {
          page.dispose();
        }
      });
      if (reuse) {
        closing.focusRequested = false;
        setState(() => closing.controller.open(context));
        return;
      }
    }
    final row = rowContext.findRenderObject()! as RenderBox;
    final viewport = _viewport.currentContext!.findRenderObject()! as RenderBox;
    final rect = MatrixUtils.transformRect(
      row.getTransformTo(viewport),
      Offset.zero & row.size,
    );
    final page = _MenuPage(
      submenu.label,
      submenu.items,
      UiFluidController(vsync: this, value: .34),
      source: UiFluidGeometry(
        rect,
        (UiThemeTokens.of(context).radius.md.x +
                UiThemeTokens.of(context).radius.lg.x) /
            2,
      ),
      opener: submenu,
      sourceSize: row.size,
      returnFocus: parent.nodes[submenu],
    );
    page.controller.addListener(() {
      _removeClosed(page);
      if (!page.focusRequested &&
          page.controller.target == 1 &&
          page.controller.value > .5) {
        page.focusRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pages.last == page && page.controller.target == 1) {
            page.focus.requestFocus();
            page.focus.nextFocus();
          }
        });
      }
    });
    setState(() => _pages.add(page));
    page.controller.open(context);
    widget.onDepthChanged?.call(_pages.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.contains(page)) page.focus.requestFocus();
    });
  }

  void _closeDescendants(int index) {
    if (_rootClosing) return;
    for (final page in _pages.skip(index + 1)) {
      if (!page.released) {
        page.controller.close(
          context,
          duration:
              (widget._closeDuration ??
              UiThemeTokens.of(context).menu.closeDuration),
        );
      }
    }
    setState(() {});
    _pages[index].focus.requestFocus();
  }

  double _closingContentExit(_MenuPage page) => page.released
      ? Curves.easeInOut.transform(
          (page.controller.transitionProgress / .22).clamp(0.0, 1.0),
        )
      : 0;

  Widget _parentTapTarget(UiFluidGeometry geometry, int index) =>
      Positioned.fromRect(
        rect: geometry.rect,
        child: UiCornerClip(
          borderRadius: geometry.borderRadius,
          child: TapRegion(
            groupId: _tapGroup,
            child: MetaData(
              metaData: _MenuDragTarget(_pages[index], null, context),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _closeDescendants(index),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

  void _openFocusedSubmenu() {
    final page = _pages[_activeIndex];
    for (final entry in page.nodes.entries) {
      if (entry.key is UiMenuSubmenu &&
          entry.value.hasFocus &&
          entry.value.context != null &&
          (entry.key as UiMenuSubmenu).enabled) {
        _push(page, entry.key as UiMenuSubmenu, entry.value.context!);
        return;
      }
    }
  }

  void _back() {
    if (_rootClosing) return;
    final index = _activeIndex;
    if (index == 0) {
      // Back is navigation, never a toggle of an outgoing animation.
      _dismiss();
      return;
    }
    final page = _pages[index];
    setState(
      () => page.controller.close(
        context,
        duration:
            (widget._closeDuration ??
            UiThemeTokens.of(context).menu.closeDuration),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _pages.contains(page) &&
          page.released &&
          _activeIndex == index - 1) {
        page.returnFocus?.requestFocus();
      }
    });
  }

  void _removeClosed(_MenuPage page) {
    if (page.controller.value != 0 ||
        page.controller.target != 0 ||
        _removalScheduled) {
      return;
    }
    _removalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removalScheduled = false;
      if (!mounted) return;
      final removed = <_MenuPage>[];
      final closedIndex = _pages.indexWhere(
        (page) =>
            page != _pages.first && page.released && page.controller.value == 0,
      );
      if (closedIndex > 0) {
        removed.addAll(_pages.sublist(closedIndex).reversed);
        _pages.removeRange(closedIndex, _pages.length);
      }
      if (removed.isEmpty) return;
      setState(() {});
      final returnFocus = removed.last.returnFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && returnFocus?.context != null) {
          returnFocus!.requestFocus();
        }
      });
      for (final removedPage in removed) {
        removedPage.dispose();
      }
      widget.onDepthChanged?.call(_pages.length);
    });
  }

  Future<void> _activate(_MenuPage page, UiMenuItem item) async {
    if (!item.enabled || item.loading || page.busy.contains(item)) return;
    setState(() => page.busy.add(item));
    try {
      if (widget.closeOnSelect) _dismiss();
      await item.onPressed?.call();
      if (mounted) widget.onSelected?.call(item);
    } finally {
      if (mounted && _pages.contains(page)) {
        setState(() => page.busy.remove(item));
      }
    }
  }

  Widget _dragRegion(_MenuPage page, Widget child, {bool back = false}) =>
      MetaData(
        metaData: _MenuDragTarget(page, null, context, back: back),
        behavior: HitTestBehavior.translucent,
        child: child,
      );

  Widget _row(_MenuPage page, UiMenuNode node) {
    final tokens = UiThemeTokens.of(context);
    if (node is UiMenuSeparator) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.x2),
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: tokens.colors.border),
        ),
      );
    }
    if (node is UiMenuGroup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (node.label != null)
            Padding(
              padding: EdgeInsets.all(tokens.spacing.x2),
              child: UiText(node.label!, tone: UiTextTone.muted),
            ),
          ...node.items.map((item) => _row(page, item)),
        ],
      );
    }
    final submenu = node is UiMenuSubmenu ? node : null;
    final item = node is UiMenuItem ? node : null;
    final label = submenu?.label ?? item!.label;
    final enabled =
        submenu?.enabled ??
        (item!.enabled && !item.loading && !page.busy.contains(item));
    final leading = submenu?.leading ?? item?.leading;
    final labelColor = !enabled
        ? tokens.colors.textMuted
        : item?.destructive == true
        ? tokens.colors.danger
        : tokens.colors.textPrimary;
    final pageIndex = _pages.indexOf(page);
    final child = pageIndex + 1 < _pages.length ? _pages[pageIndex + 1] : null;
    final transferred = submenu != null && child?.opener == submenu;
    return Builder(
      builder: (rowContext) => MetaData(
        metaData: _MenuDragTarget(page, node, rowContext),
        child: Semantics(
          container: true,
          excludeSemantics: true,
          label: label,
          button: true,
          enabled: enabled,
          onTap: enabled
              ? () => submenu != null
                    ? _push(page, submenu, rowContext)
                    : _activate(page, item!)
              : null,
          hint: [
            if (item?.destructive == true) 'destructive action',
            if (item?.loading == true) 'busy',
            if (!enabled) 'disabled',
          ].join(', '),
          child: UiPressable(
            minTapSize: tokens.menu.rowMinHeight,
            excludeFromSemantics: true,
            focusNode: page.nodes.putIfAbsent(node, FocusNode.new),
            semanticsLabel: label,
            enabled: enabled,
            onPressed: () => submenu != null
                ? _push(page, submenu, rowContext)
                : _activate(page, item!),
            // While promoted, this slot owns layout/focus/input only. Its label,
            // leading widget, chevron and highlight must not paint below the morph.
            builder: (context, state, _) => transferred
                ? SizedBox(
                    height: child!.sourceSize!.height,
                    width: double.infinity,
                  )
                : DecoratedBox(
                    decoration: tokens.radius.decoration(
                      color:
                          (_dragTarget?.page == page &&
                                  _dragTarget?.node == node) ||
                              state.hovered ||
                              state.pressed ||
                              (state.focused &&
                                  FocusManager.instance.highlightMode ==
                                      FocusHighlightMode.traditional)
                          ? tokens.colors.surfaceMuted
                          : const Color(0x00000000),
                      borderRadius: BorderRadius.circular(
                        (tokens.radius.md.x + tokens.radius.lg.x) / 2,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.menu.rowPaddingHorizontal,
                        vertical: tokens.menu.rowPaddingVertical,
                      ),
                      child: Row(
                        children: [
                          if (leading != null) ...[
                            IconTheme.merge(
                              data: IconThemeData(
                                color: labelColor,
                                size: tokens.menu.iconSize,
                              ),
                              child: leading,
                            ),
                            SizedBox(width: tokens.spacing.x2),
                          ],
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UiText(
                                  label,
                                  variant: UiTextVariant.bodySm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: labelColor),
                                ),
                                if (item?.subtitle != null)
                                  UiText(
                                    item!.subtitle!,
                                    variant: UiTextVariant.caption,
                                    tone: UiTextTone.muted,
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          ),
                          if (item?.shortcut != null)
                            UiText(
                              item!.shortcut!.label,
                              tone: UiTextTone.muted,
                            ),
                          if (submenu != null)
                            Icon(
                              UiDirectionalIcons.chevronForward(context),
                              size: tokens.menu.iconSize,
                              color: labelColor,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _content(_MenuPage page, bool nested) {
    final tokens = UiThemeTokens.of(context);
    return UiAnchoredOverlayTapRegion(
      groupId: _tapGroup,
      enabled:
          page == _pages.first && widget.dismissOnTapOutside && !_rootClosing,
      onDismiss: _dismiss,
      child: FocusScope(
        node: page.focus,
        child: FocusTraversalGroup(
          child: Column(
            children: [
              if (nested)
                SizedBox(key: page.headerKey, height: page.source!.rect.height)
              else
                SizedBox(key: page.headerKey, height: tokens.spacing.x1),
              Expanded(
                child: SingleChildScrollView(
                  key: page.scrollKey,
                  controller: page.scroll,
                  child: Padding(
                    key: page.bodyKey,
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.x1,
                      0,
                      tokens.spacing.x1,
                      tokens.spacing.x1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: page.items
                          .map((node) => _row(page, node))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _measureContent(_MenuPage page) {
    if (page.measuring) return;
    page.measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      page.measuring = false;
      if (!mounted || !_pages.contains(page)) return;
      final body =
          page.bodyKey.currentContext?.findRenderObject() as RenderBox?;
      final header =
          page.headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (body == null || header == null || !body.hasSize || !header.hasSize) {
        return;
      }
      final height = body.size.height + header.size.height;
      if (page.contentHeight == null ||
          (page.contentHeight! - height).abs() > .1) {
        setState(() => page.contentHeight = height);
      }
    });
  }

  Widget _promotedHeader(
    _MenuPage page,
    UiFluidMorphFrame frame,
    Rect destination,
    Color tint,
  ) {
    final tokens = UiThemeTokens.of(context);
    final source = page.source!.rect;
    final travel = destination.height - source.height;
    final expansion = travel.abs() < .001
        ? 1.0
        : ((frame.geometry.rect.height - source.height) / travel).clamp(
            0.0,
            1.0,
          );
    return Positioned.fromRect(
      rect: frame.geometry.rect,
      child: TapRegion(
        groupId: _tapGroup,
        child: UiCornerClip(
          borderRadius: frame.geometry.borderRadius,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              height: source.height,
              child: _dragRegion(
                page,
                UiPressable(
                  minTapSize: tokens.menu.rowMinHeight,
                  semanticsLabel: widget.backLabel,
                  onPressed: _back,
                  builder: (context, state, _) => DecoratedBox(
                    decoration: tokens.radius.decoration(
                      color:
                          state.hovered ||
                              state.pressed ||
                              (_dragTarget?.page == page &&
                                  _dragTarget?.back == true)
                          ? tokens.colors.surfaceMuted
                          : const Color(0x00000000),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.menu.rowPaddingHorizontal,
                        vertical: tokens.menu.rowPaddingVertical,
                      ),
                      child: Row(
                        children: [
                          if (page.opener?.leading != null) ...[
                            IconTheme.merge(
                              data: IconThemeData(
                                size: tokens.menu.iconSize,
                                color: Color.alphaBlend(
                                  tint,
                                  tokens.colors.textPrimary,
                                ),
                              ),
                              child: page.opener!.leading!,
                            ),
                            SizedBox(width: tokens.spacing.x2),
                          ],
                          Expanded(
                            child: UiText(
                              page.title,
                              variant: UiTextVariant.bodySm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color.alphaBlend(
                                  tint,
                                  tokens.colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: math.pi * expansion,
                            child: Icon(
                              UiDirectionalIcons.chevronForward(context),
                              size: tokens.menu.iconSize,
                              color: Color.alphaBlend(
                                tint,
                                tokens.colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                back: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      (widget._parentScale ?? UiThemeTokens.of(context).menu.parentScale) > 0 &&
          (widget._parentScale ?? UiThemeTokens.of(context).menu.parentScale) <=
              1,
    );
    assert(
      (widget._scrimOpacity ?? UiThemeTokens.of(context).menu.scrimOpacity) >=
              0 &&
          (widget._scrimOpacity ??
                  UiThemeTokens.of(context).menu.scrimOpacity) <=
              1,
    );
    assert(
      (widget._backdropBlurSigma ??
              UiThemeTokens.of(context).menu.backdropBlurSigma) >=
          0,
    );
    assert(
      (widget._surfaceOpacity ??
                  UiThemeTokens.of(context).menu.surfaceOpacity) >=
              0 &&
          (widget._surfaceOpacity ??
                  UiThemeTokens.of(context).menu.surfaceOpacity) <=
              1,
    );
    final tokens = UiThemeTokens.of(context);
    return GestureDetector(
      onLongPressStart: _startDrag,
      onLongPressMoveUpdate: (details) => _updateDrag(details.globalPosition),
      onLongPressEnd: _endDrag,
      onLongPressCancel: _clearDrag,
      child: PopScope(
        canPop:
            !widget.handleSystemBack ||
            (_pages.length == 1 &&
                widget.onDismiss == null &&
                (widget.rootController == null ||
                    widget.rootController!.value == 0)),
        onPopInvokedWithResult: (didPop, result) {
          if (widget.handleSystemBack && !didPop) _back();
        },
        child: Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                _OpenSubmenuIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                DismissIntent(),
            if (_pages.length > 1 ||
                widget.onDismiss != null ||
                widget.rootController != null)
              const SingleActivator(LogicalKeyboardKey.escape):
                  const DismissIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                const NextFocusIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                const PreviousFocusIntent(),
          },
          child: Actions(
            actions: {
              _OpenSubmenuIntent: CallbackAction<_OpenSubmenuIntent>(
                onInvoke: (_) {
                  _openFocusedSubmenu();
                  return null;
                },
              ),
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _back();
                  return null;
                },
              ),
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                assert(
                  constraints.hasBoundedWidth && constraints.hasBoundedHeight,
                  'UiMenuStack needs a bounded viewport.',
                );
                final bounds =
                    widget.rootMenuBounds ??
                    (Offset.zero & constraints.biggest);
                final width = bounds.right;
                final height = bounds.bottom;
                return AnimatedBuilder(
                  animation: Listenable.merge([
                    ..._pages.map((page) => page.controller),
                    if (widget.rootController != null) widget.rootController!,
                  ]),
                  builder: (context, _) => Stack(
                    key: _viewport,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        Positioned.fill(
                          child: Builder(
                            builder: (context) {
                              final page = _pages[i];
                              final covered = i < _pages.length - 1;
                              final blocked =
                                  covered && !_pages[i + 1].released;
                              final released = i > 0 && page.released;
                              final rootExit = _rootClosing
                                  ? Curves.easeInOut.transform(
                                      (widget
                                                  .rootController!
                                                  .transitionProgress /
                                              .22)
                                          .clamp(0.0, 1.0),
                                    )
                                  : 0.0;
                              // Descendant headers live in sibling layers. Once
                              // an ancestor closes, they must leave with its
                              // content, not remain painted until stack disposal.
                              var ancestorExit = rootExit;
                              for (var ancestor = 1; ancestor < i; ancestor++) {
                                ancestorExit = math.max(
                                  ancestorExit,
                                  _closingContentExit(_pages[ancestor]),
                                );
                              }
                              final coverExit = i > 0
                                  ? math.max(
                                      ancestorExit,
                                      _closingContentExit(page),
                                    )
                                  : ancestorExit;
                              final cover =
                                  (covered
                                      ? _pages[i + 1].sampleCover(
                                          tokens.menu.springStrength,
                                        )
                                      : 0.0) *
                                  (1 - coverExit);
                              final tint = Color.fromRGBO(
                                0,
                                0,
                                0,
                                (widget._scrimOpacity ??
                                        UiThemeTokens.of(context)
                                            .menu
                                            .scrimOpacity) *
                                    cover,
                              );
                              final scale =
                                  1 -
                                  (1 -
                                          (widget._parentScale ??
                                              UiThemeTokens.of(context)
                                                  .menu
                                                  .parentScale)) *
                                      cover;
                              final baseTop = i == 0
                                  ? bounds.top + tokens.spacing.x3
                                  : page.source!.rect.top;
                              final left = i == 0
                                  ? bounds.left + tokens.spacing.x3
                                  : page.source!.rect.left;
                              _measureContent(page);
                              final surfaceHeight = math.max(
                                1.0,
                                math.min(
                                  bounds.height - tokens.spacing.x3 * 2,
                                  page.contentHeight ??
                                      height - baseTop - tokens.spacing.x3,
                                ),
                              );
                              final top = i == 0 && widget.rootAlignBottom
                                  ? height - tokens.spacing.x3 - surfaceHeight
                                  : baseTop.clamp(
                                      bounds.top + tokens.spacing.x3,
                                      math.max(
                                        bounds.top + tokens.spacing.x3,
                                        height -
                                            tokens.spacing.x3 -
                                            surfaceHeight,
                                      ),
                                    );
                              final rect = Rect.fromLTWH(
                                left,
                                top.toDouble(),
                                math.max(1, width - left - tokens.spacing.x3),
                                surfaceHeight,
                              );
                              final content = IgnorePointer(
                                ignoring: blocked || _rootClosing,
                                child: _dragRegion(page, _content(page, i > 0)),
                              );
                              final surface = i == 0
                                  ? widget.rootController != null
                                        ? UiFluidMorph(
                                            stableDestinationHitTargets: true,
                                            initialSourceGeometry: widget
                                                .rootInitialSourceGeometry,
                                            initialSourceColor:
                                                widget.rootInitialSourceColor,
                                            initialSourceBorder:
                                                widget.rootInitialSourceBorder,
                                            sourceFit: widget.rootSourceFit,
                                            sourceColor: widget.rootSourceColor,
                                            sourceBorder:
                                                widget.rootSourceBorder,
                                            sourceShadows:
                                                widget.rootSourceShadows,
                                            sourceBackdropBlurSigma:
                                                widget.rootSourceColor == null
                                                ? null
                                                : 0,
                                            pressExpansion:
                                                tokens.menu.pressExpansion,
                                            travelArc: tokens.menu.travelArc,
                                            springStrength:
                                                tokens.menu.springStrength,
                                            border: BorderSide(
                                              width: tokens.menu.borderWidth,
                                              color:
                                                  tokens.menu.borderColor ??
                                                  tokens.colors.textPrimary
                                                      .withValues(
                                                        alpha: tokens
                                                            .menu
                                                            .borderOpacity,
                                                      ),
                                            ),
                                            controller: widget.rootController!,
                                            sourceGeometry:
                                                widget.rootSourceGeometry!,
                                            destinationGeometry:
                                                UiFluidGeometry(
                                                  rect,
                                                  tokens.radius.lg.x,
                                                ),
                                            overlayBuilder: blocked
                                                ? (context, frame) =>
                                                      _parentTapTarget(
                                                        frame.geometry,
                                                        i,
                                                      )
                                                : null,
                                            source: TapRegion(
                                              groupId: _tapGroup,
                                              child: MetaData(
                                                metaData: _rootTriggerTag,
                                                child: widget.rootTrigger!,
                                              ),
                                            ),
                                            destination: content,
                                            color: tokens.colors.surface
                                                .withValues(
                                                  alpha:
                                                      (widget._surfaceOpacity ??
                                                      UiThemeTokens.of(context)
                                                          .menu
                                                          .surfaceOpacity),
                                                ),
                                            foregroundColor: tint,
                                            backdropBlurSigma:
                                                (widget._backdropBlurSigma ??
                                                UiThemeTokens.of(context)
                                                    .menu
                                                    .backdropBlurSigma),
                                            alignment: AlignmentDirectional
                                                .topEnd
                                                .resolve(
                                                  Directionality.of(context),
                                                ),
                                          )
                                        : Stack(
                                            children: [
                                              UiFluidSurface(
                                                border: BorderSide(
                                                  width:
                                                      tokens.menu.borderWidth,
                                                  color:
                                                      tokens.menu.borderColor ??
                                                      tokens.colors.textPrimary
                                                          .withValues(
                                                            alpha: tokens
                                                                .menu
                                                                .borderOpacity,
                                                          ),
                                                ),
                                                geometry: UiFluidGeometry(
                                                  rect,
                                                  tokens.radius.lg.x,
                                                ),
                                                foregroundColor: tint,
                                                contentSize: rect.size,
                                                color: tokens.colors.surface
                                                    .withValues(
                                                      alpha:
                                                          (widget
                                                              ._surfaceOpacity ??
                                                          UiThemeTokens.of(
                                                                context,
                                                              )
                                                              .menu
                                                              .surfaceOpacity),
                                                    ),
                                                backdropBlurSigma:
                                                    (widget
                                                        ._backdropBlurSigma ??
                                                    UiThemeTokens.of(context)
                                                        .menu
                                                        .backdropBlurSigma),
                                                child: content,
                                              ),
                                              if (blocked)
                                                _parentTapTarget(
                                                  UiFluidGeometry(
                                                    rect,
                                                    tokens.radius.lg.x,
                                                  ),
                                                  i,
                                                ),
                                            ],
                                          )
                                  : UiMenuTransition(
                                      springStrength:
                                          tokens.menu.springStrength,
                                      border: BorderSide(
                                        width: tokens.menu.borderWidth,
                                        color:
                                            tokens.menu.borderColor ??
                                            tokens.colors.textPrimary
                                                .withValues(
                                                  alpha:
                                                      tokens.menu.borderOpacity,
                                                ),
                                      ),
                                      controller: page.controller,
                                      sourceGeometry: page.source!,
                                      destinationGeometry: UiFluidGeometry(
                                        rect,
                                        tokens.radius.lg.x,
                                      ),
                                      color: tokens.colors.surface.withValues(
                                        alpha:
                                            (widget._surfaceOpacity ??
                                            UiThemeTokens.of(context)
                                                .menu
                                                .surfaceOpacity),
                                      ),
                                      foregroundColor: tint,
                                      backdropBlurSigma:
                                          (widget._backdropBlurSigma ??
                                          UiThemeTokens.of(context)
                                              .menu
                                              .backdropBlurSigma),
                                      destination: content,
                                      overlayBuilder: (context, frame) => Stack(
                                        children: [
                                          IgnorePointer(
                                            ignoring: blocked,
                                            child: Stack(
                                              children: [
                                                _promotedHeader(
                                                  page,
                                                  frame,
                                                  rect,
                                                  tint,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (blocked)
                                            _parentTapTarget(frame.geometry, i),
                                        ],
                                      ),
                                    );
                              return IgnorePointer(
                                ignoring: released || (i > 0 && _rootClosing),
                                child: ExcludeFocus(
                                  excluding:
                                      (blocked && !_rootClosing) ||
                                      released ||
                                      (i > 0 && _rootClosing),
                                  child: ExcludeSemantics(
                                    excluding:
                                        (blocked && !_rootClosing) ||
                                        released ||
                                        (i > 0 && _rootClosing),
                                    child: Transform.scale(
                                      scale: scale,
                                      alignment: Alignment.topCenter,
                                      child: Opacity(
                                        opacity: i > 0 ? 1 - ancestorExit : 1,
                                        child: surface,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.gestureController?._state = null;
    _dragScroll?.cancel();
    _dwell?.cancel();
    widget.rootController?.removeListener(_rootChanged);
    for (final position in _ancestorPositions) {
      position.removeListener(_ancestorScrolled);
    }
    for (final page in _pages) {
      page.dispose();
    }
    super.dispose();
  }
}
