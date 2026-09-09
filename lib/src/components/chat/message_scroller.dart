import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/theme/ui_theme_extensions.dart';
import 'marker.dart';
import 'message_scroll_controls.dart';

@immutable
class UiMessageScrollerItem {
  const UiMessageScrollerItem({
    required this.id,
    required this.child,
    this.isOutgoing = false,
  });

  final String id;
  final Widget child;

  /// Whether this item was authored by the current user.
  ///
  /// A newly appended outgoing item dismisses an active unread boundary.
  final bool isOutgoing;
}

typedef UiUnreadMarkerBuilder = Widget Function(BuildContext context);

/// Imperative access to a [UiMessageScroller]'s live-edge state.
class UiMessageScrollerController extends ChangeNotifier {
  _UiMessageScrollerState? _state;
  bool _isAtLiveEdge = true;
  int _unseenCount = 0;
  String? _firstUnseenMessageId;

  bool get isAtLiveEdge => _isAtLiveEdge;

  /// Whether a user drag or fling currently owns the viewport.
  bool get isScrolling => _state?._userScrolling ?? false;
  int get unseenCount => _unseenCount;
  String? get firstUnseenMessageId => _firstUnseenMessageId;
  bool get hasUnreadMarker => _state?._showsUnreadMarker ?? false;

  Future<void> jumpToLatest({bool animated = true}) async {
    await _state?._jumpToLatest(animated: animated);
  }

  /// Whether the row is already visible inside the padded reading area.
  bool isMessageVisible(String id) => _state?._isMessageVisible(id) ?? false;

  /// Set [onlyIfNeeded] to reveal a reply without repositioning a visible row.
  Future<bool> jumpToMessage(
    String id, {
    bool animated = true,
    bool onlyIfNeeded = false,
  }) async {
    return await _state?._jumpToMessage(
          id,
          animated: animated,
          onlyIfNeeded: onlyIfNeeded,
        ) ??
        false;
  }

  Future<bool> jumpToFirstUnseen({bool animated = true}) async {
    final id = _firstUnseenMessageId;
    if (id == null) return false;
    final found = await _state?._jumpToMessage(id, animated: animated) ?? false;
    if (found) _update(unseenCount: 0, clearFirstUnseen: true);
    return found;
  }

  void dismissUnreadMarker() => _state?._dismissUnreadMarker();

  void _attach(_UiMessageScrollerState state) => _state = state;

  void _detach(_UiMessageScrollerState state) {
    if (identical(_state, state)) _state = null;
  }

  void _update({
    bool? atLiveEdge,
    int? unseenCount,
    String? firstUnseenMessageId,
    bool clearFirstUnseen = false,
  }) {
    final nextEdge = atLiveEdge ?? _isAtLiveEdge;
    final nextCount = unseenCount ?? _unseenCount;
    final nextFirst = clearFirstUnseen
        ? null
        : firstUnseenMessageId ?? _firstUnseenMessageId;
    if (nextEdge == _isAtLiveEdge &&
        nextCount == _unseenCount &&
        nextFirst == _firstUnseenMessageId) {
      return;
    }
    _isAtLiveEdge = nextEdge;
    _unseenCount = nextCount;
    _firstUnseenMessageId = nextFirst;
    notifyListeners();
  }

  void _unreadMarkerChanged() => notifyListeners();
}

/// A chat viewport that follows new content only while the reader is at the
/// live edge and preserves their position when older items are prepended.
class UiMessageScroller extends StatefulWidget {
  const UiMessageScroller({
    super.key,
    required this.items,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.itemSpacing = 12,
    this.liveEdgeThreshold = 56,
    this.loadEarlierThreshold = 160,
    this.startAtEnd = true,
    this.autoFollow = true,
    this.initialMessageId,
    this.initialUnreadMessageId,
    this.unreadMarkerLabel = 'Unread messages',
    this.unreadMarkerBuilder,
    this.onLoadEarlier,
    this.jumpToLatestLabel = 'Latest',
    this.newMessagesLabelBuilder,
    this.scrollControlsBuilder,
  });

  final List<UiMessageScrollerItem> items;
  final UiMessageScrollerController? controller;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final double liveEdgeThreshold;
  final double loadEarlierThreshold;
  final bool startAtEnd;
  final bool autoFollow;
  final String? initialMessageId;

  /// The first unread item when this scroller session is created.
  ///
  /// The boundary is a snapshot: later rebuilds do not move it. It disappears
  /// when an outgoing item is appended or [UiMessageScrollerController]
  /// dismisses it. Pass null when reopening a room that has already been read.
  final String? initialUnreadMessageId;
  final String unreadMarkerLabel;
  final UiUnreadMarkerBuilder? unreadMarkerBuilder;
  final Future<void> Function()? onLoadEarlier;
  final String jumpToLatestLabel;
  final String Function(int count)? newMessagesLabelBuilder;
  final Widget Function(
    BuildContext context,
    UiMessageScrollerController controller,
  )?
  scrollControlsBuilder;

  @override
  State<UiMessageScroller> createState() => _UiMessageScrollerState();
}

class _UiMessageScrollerState extends State<UiMessageScroller>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seekVisibility = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 140),
  );
  late final ScrollController _scrollController = _MessageScrollController(
    _layoutCorrection,
  );
  (String, double)? _pendingReadingAnchor;
  final Set<int> _activePointers = {};
  int _positionRevision = 0;
  final Map<String, GlobalKey> _keys = {};
  late UiMessageScrollerController _publicController;
  bool _initialized = false;
  bool _programmaticScroll = false;
  int _scrollCommandRevision = 0;
  bool _ownsPublicController = false;
  bool _loadingEarlier = false;
  bool _loadEarlierInFlight = false;

  late final String? _unreadBoundaryId = widget.initialUnreadMessageId;
  late bool _showsUnreadMarker = _unreadBoundaryId != null;

  @override
  void initState() {
    super.initState();
    _attachController();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialPosition());
  }

  @override
  void didUpdateWidget(UiMessageScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_programmaticScroll &&
        (!_publicController.isAtLiveEdge ||
            !widget.autoFollow ||
            _userScrolling) &&
        !listEquals(
          oldWidget.items.map((i) => i.id).toList(),
          widget.items.map((i) => i.id).toList(),
        )) {
      _pendingReadingAnchor ??= _captureReadingAnchor(oldWidget.items);
    }
    final activeIds = widget.items.map((item) => item.id).toSet();
    if (_showsUnreadMarker && _unreadBoundaryId != null) {
      activeIds.add(_unreadMarkerId);
    }
    if (_initialized &&
        _showsUnreadMarker &&
        !activeIds.contains(_unreadBoundaryId)) {
      _showsUnreadMarker = false;
    }
    _keys.removeWhere((id, _) => !activeIds.contains(id));
    if (oldWidget.controller != widget.controller) {
      final currentEdge = _publicController.isAtLiveEdge;
      final currentUnseen = _publicController.unseenCount;
      final previousController = _publicController;
      previousController._detach(this);
      if (_ownsPublicController) previousController.dispose();
      _attachController();
      _publicController._update(
        atLiveEdge: currentEdge,
        unseenCount: currentUnseen,
        firstUnseenMessageId: previousController.firstUnseenMessageId,
      );
    }
    final wasAtLiveEdge = _publicController.isAtLiveEdge;
    final revision = ++_positionRevision;
    final scrollCommand = _scrollCommandRevision;
    final oldIds = oldWidget.items.map((item) => item.id).toSet();
    final oldLastIndex = oldWidget.items.isEmpty
        ? -1
        : widget.items.indexWhere((item) => item.id == oldWidget.items.last.id);
    // Only messages added after the old tail are arrivals. Treating every new
    // ID as an arrival makes pagination and restored history incorrectly show
    // an unread badge.
    final appendedItems = oldLastIndex < 0
        ? widget.items.where((item) => !oldIds.contains(item.id)).toList()
        : widget.items
              .skip(oldLastIndex + 1)
              .where((item) => !oldIds.contains(item.id))
              .toList(growable: false);
    final appended = appendedItems.length;
    final appendedOutgoing = appendedItems.any((item) => item.isOutgoing);
    final appendedIncoming = appendedItems
        .where((item) => !item.isOutgoing)
        .toList(growable: false);
    if (appendedOutgoing) _dismissUnreadMarker(notify: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      if (revision != _positionRevision) return;
      if (!_initialized && widget.items.isNotEmpty) {
        await _initialPosition();
        return;
      }
      final mayFollow =
          widget.autoFollow &&
          !_userScrolling &&
          scrollCommand == _scrollCommandRevision;
      if (appendedOutgoing && mayFollow) {
        await _jumpToLatest();
      } else if (appended > 0 && wasAtLiveEdge && mayFollow) {
        await _jumpToLatest();
      } else if (appendedIncoming.isNotEmpty) {
        _publicController._update(
          atLiveEdge: false,
          unseenCount: _publicController.unseenCount + appendedIncoming.length,
          firstUnseenMessageId:
              _publicController.firstUnseenMessageId ??
              appendedIncoming.first.id,
        );
      }
    });
  }

  bool get _userScrolling =>
      _activePointers.isNotEmpty ||
      (!_programmaticScroll &&
          _scrollController.hasClients &&
          _scrollController.position.isScrollingNotifier.value);

  void _dismissUnreadMarker({bool notify = true}) {
    if (!_showsUnreadMarker) return;
    if (notify) {
      setState(() => _showsUnreadMarker = false);
    } else {
      _showsUnreadMarker = false;
    }
    _publicController._unreadMarkerChanged();
  }

  List<UiMessageScrollerItem> _displayItems() {
    if (!_showsUnreadMarker || _unreadBoundaryId == null) {
      return widget.items;
    }
    final boundaryIndex = widget.items.indexWhere(
      (item) => item.id == _unreadBoundaryId,
    );
    if (boundaryIndex < 0) return widget.items;
    return [
      ...widget.items.take(boundaryIndex),
      UiMessageScrollerItem(
        id: _unreadMarkerId,
        child:
            widget.unreadMarkerBuilder?.call(context) ??
            UiUnreadMessagesMarker(label: widget.unreadMarkerLabel),
      ),
      ...widget.items.skip(boundaryIndex),
    ];
  }

  String get _unreadMarkerId => '__ui_unread_marker__$_unreadBoundaryId';

  void _attachController() {
    _ownsPublicController = widget.controller == null;
    _publicController = widget.controller ?? UiMessageScrollerController();
    _publicController._attach(this);
  }

  Future<void> _initialPosition() async {
    if (!mounted || _initialized || widget.items.isEmpty) return;
    _initialized = true;
    if (widget.initialMessageId != null) {
      await _jumpToMessage(widget.initialMessageId!, animated: false);
    } else if (widget.startAtEnd) {
      await _jumpToLatest(animated: false);
    } else {
      await _jumpToMessage(widget.items.first.id, animated: false);
    }
  }

  void _handleScroll({bool metricsOnly = false}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final lastBox = widget.items.isEmpty
        ? null
        : _laidOutBox(widget.items.last.id);
    final viewport = lastBox == null
        ? null
        : RenderAbstractViewport.maybeOf(lastBox);
    final atEdge =
        lastBox is RenderBox &&
        viewport is RenderBox &&
        lastBox
                .localToGlobal(
                  Offset(0, lastBox.size.height),
                  ancestor: viewport,
                )
                .dy <=
            (viewport as RenderBox).size.height + widget.liveEdgeThreshold;
    if (!metricsOnly || _publicController.unseenCount == 0) {
      _publicController._update(
        atLiveEdge: atEdge,
        unseenCount: atEdge ? 0 : null,
        clearFirstUnseen: atEdge,
      );
    }
    if (position.maxScrollExtent - position.pixels >
            widget.loadEarlierThreshold &&
        !_loadEarlierInFlight) {
      _loadingEarlier = false;
    } else if (!_loadingEarlier && widget.onLoadEarlier != null) {
      _loadingEarlier = true;
      _loadEarlier();
    }
  }

  Future<void> _loadEarlier() async {
    _loadEarlierInFlight = true;
    try {
      await widget.onLoadEarlier?.call();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'open_ui_kit',
          context: ErrorDescription('while loading earlier chat messages'),
        ),
      );
    } finally {
      _loadEarlierInFlight = false;
      if (mounted &&
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels >
              widget.loadEarlierThreshold) {
        _loadingEarlier = false;
      }
    }
  }

  (String, double)? _captureReadingAnchor(List<UiMessageScrollerItem> items) {
    for (final item in items) {
      final row = _laidOutBox(item.id);
      if (row == null) continue;
      final viewport = RenderAbstractViewport.of(row);
      final view = viewport as RenderBox;
      final top = row.localToGlobal(Offset.zero, ancestor: view).dy;
      if (top < view.size.height && top + row.size.height > 0) {
        return (item.id, _rowLayoutOffset(row));
      }
    }
    return null;
  }

  double _rowLayoutOffset(RenderBox row) {
    RenderObject child = row;
    while (child.parent is! RenderSliverMultiBoxAdaptor) {
      child = child.parent!;
    }
    return (child.parentData! as SliverMultiBoxAdaptorParentData).layoutOffset!;
  }

  double _layoutCorrection() {
    final anchor = _pendingReadingAnchor;
    _pendingReadingAnchor = null;
    if (anchor == null) return 0;
    final row = _laidOutBox(anchor.$1);
    if (row == null) return 0;
    return _rowLayoutOffset(row) - anchor.$2;
  }

  Future<void> _jumpToLatest({bool animated = true}) async {
    if (!_scrollController.hasClients || widget.items.isEmpty) return;
    final command = ++_scrollCommandRevision;
    _seekVisibility.value = 1;
    _programmaticScroll = true;
    await _moveTo(0, animated: animated);
    if (!mounted || command != _scrollCommandRevision) return;
    _programmaticScroll = false;
    _publicController._update(
      atLiveEdge: true,
      unseenCount: 0,
      clearFirstUnseen: true,
    );
  }

  Future<void> _moveTo(double offset, {required bool animated}) async {
    final position = _scrollController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animated && !MediaQuery.disableAnimationsOf(context)) {
      await _scrollController.animateTo(
        target,
        duration: UiThemeTokens.motionOf(context).standard,
        curve: UiThemeTokens.motionOf(context).standardCurve,
      );
    } else {
      _scrollController.jumpTo(target);
    }
    // Explicitly request layout even when the requested offset is unchanged.
    // endOfFrame also schedules a frame when called between frames.
    await WidgetsBinding.instance.endOfFrame;
  }

  // Only use rows in the sliver's current layout. A kept-alive row can retain
  // a RenderBox and a stale reveal offset after leaving the laid-out range.
  RenderBox? _laidOutBox(String id) {
    final box = _keys[id]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    RenderObject child = box;
    while (child.parent != null &&
        child.parent is! RenderSliverMultiBoxAdaptor) {
      child = child.parent!;
    }
    final data = child.parentData;
    if (data is! SliverMultiBoxAdaptorParentData ||
        data.keptAlive ||
        data.layoutOffset == null) {
      return null;
    }
    return box;
  }

  bool _isMessageVisible(String id) {
    final row = _laidOutBox(id);
    if (row == null) return false;
    final view = RenderAbstractViewport.of(row) as RenderBox;
    final padding = widget.padding.resolve(Directionality.of(context));
    final top = row.localToGlobal(Offset.zero, ancestor: view).dy;
    final bottom = top + row.size.height;
    final availableBottom = view.size.height - padding.bottom;
    if (row.size.height > availableBottom - padding.top) {
      return top <= padding.top + 1 && bottom >= availableBottom - 1;
    }
    return top >= padding.top - 1 && bottom <= availableBottom + 1;
  }

  Future<bool> _jumpToMessage(
    String id, {
    bool animated = true,
    bool onlyIfNeeded = false,
  }) async {
    if (!_scrollController.hasClients ||
        !_displayItems().any((item) => item.id == id)) {
      return false;
    }
    if (onlyIfNeeded && _isMessageVisible(id)) {
      _scrollCommandRevision++;
      _seekVisibility.value = 1;
      _scrollController.jumpTo(_scrollController.offset);
      _programmaticScroll = false;
      return true;
    }
    final command = ++_scrollCommandRevision;
    _programmaticScroll = true;
    final distant = _laidOutBox(id) == null;
    final fadeSeek =
        distant && animated && !MediaQuery.disableAnimationsOf(context);
    if (!fadeSeek) _seekVisibility.value = 1;
    try {
      if (fadeSeek) {
        await _seekVisibility.animateTo(0, curve: Curves.easeOutCubic).orCancel;
        if (!mounted || command != _scrollCommandRevision) return false;
      }
      // Unknown variable-height targets use a single fade-through. Offset
      // estimates run while hidden; only measured nearby targets scroll.
      // ListView has no index-to-offset API for unknown variable-height rows.
      // Seek using its current measured range, then reveal the actual target.
      // This work runs only for an explicit command, never during user scrolling.
      final limit = widget.items.length + 10;
      for (var attempt = 0; attempt < limit; attempt++) {
        if (!mounted || command != _scrollCommandRevision) return false;
        final items = _displayItems();
        final index = items.indexWhere((item) => item.id == id);
        if (index < 0) return false;
        final box = _laidOutBox(id);
        if (box != null) {
          final viewport = RenderAbstractViewport.of(box);
          // In an upward list, alignment .5 centers the whole row. Public
          // message jumps retain the leading-edge-at-mid-viewport contract.
          final reveal = viewport.getOffsetToReveal(box, 0).offset;
          var target =
              reveal -
              _scrollController.position.viewportDimension / 2 +
              box.size.height;
          if (onlyIfNeeded) {
            // Once a reveal is needed, settle the measured row in the clear
            // viewport instead of stopping at an estimate beside floating UI.
            final view = viewport as RenderBox;
            final padding = widget.padding.resolve(Directionality.of(context));
            final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
            final available = (view.size.height - padding.vertical).clamp(
              0.0,
              double.infinity,
            );
            final desiredTop =
                padding.top +
                (available - box.size.height).clamp(0.0, double.infinity) / 2;
            target = _scrollController.offset + desiredTop - top;
          }
          await _moveTo(target, animated: animated && !distant);
          if (!mounted || command != _scrollCommandRevision) return false;
          final result = _laidOutBox(id);
          if (result == null) continue;
          final view = RenderAbstractViewport.of(result) as RenderBox;
          final top = result.localToGlobal(Offset.zero, ancestor: view).dy;
          if (top < view.size.height && top + result.size.height > 0) {
            return true;
          }
          continue;
        }
        double totalHeight = 0;
        var count = 0;
        int? nearestIndex;
        double? nearestOffset;
        for (var i = 0; i < items.length; i++) {
          final row = _laidOutBox(items[i].id);
          if (row == null) continue;
          totalHeight += row.size.height;
          count++;
          if (nearestIndex == null ||
              (i - index).abs() < (nearestIndex - index).abs()) {
            nearestIndex = i;
            nearestOffset = RenderAbstractViewport.of(row)
                .getOffsetToReveal(row, 0)
                .offset;
          }
        }
        final position = _scrollController.position;
        final estimate = nearestIndex == null
            ? position.maxScrollExtent
            : nearestOffset! + (nearestIndex - index) * (totalHeight / count);
        await _moveTo(estimate, animated: false);
      }
      return false;
    } on TickerCanceled {
      return false;
    } finally {
      if (mounted && command == _scrollCommandRevision) {
        if (fadeSeek) {
          try {
            await _seekVisibility
                .animateTo(1, curve: Curves.easeOutCubic)
                .orCancel;
          } on TickerCanceled {
            // A newer navigation or touch owns the viewport now.
          }
        }
        if (mounted && command == _scrollCommandRevision) {
          _programmaticScroll = false;
          _handleScroll();
        }
      }
    }
  }

  @override
  void dispose() {
    _seekVisibility.dispose();
    _publicController._detach(this);
    if (_ownsPublicController) _publicController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.map((item) => item.id).toSet().length == widget.items.length,
      'UiMessageScroller item IDs must be unique.',
    );
    final tokens = UiThemeTokens.of(context);
    final displayItems = _displayItems();

    final indices = <Key, int>{};
    for (var i = 0; i < displayItems.length; i++) {
      indices[_keys.putIfAbsent(displayItems[i].id, GlobalKey.new)] =
          displayItems.length - i - 1;
    }
    return Stack(
      children: [
        Listener(
          onPointerDown: (event) {
            _activePointers.add(event.pointer);
            _scrollCommandRevision++;
            _seekVisibility.value = 1;
            _programmaticScroll = false;
          },
          onPointerUp: (event) => _activePointers.remove(event.pointer),
          onPointerCancel: (event) => _activePointers.remove(event.pointer),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _handleScroll(metricsOnly: true);
                });
              }
              return false;
            },
            child: FadeTransition(
              opacity: _seekVisibility,
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: widget.padding,
                itemCount: displayItems.length,
                findChildIndexCallback: (key) => indices[key],
                itemBuilder: (context, index) {
                  final item = displayItems[displayItems.length - index - 1];
                  return Padding(
                    key: _keys[item.id],
                    padding: EdgeInsets.only(
                      bottom: index == 0 ? 0 : widget.itemSpacing,
                    ),
                    child: item.child,
                  );
                },
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _publicController,
          builder: (context, _) => PositionedDirectional(
            end: tokens.spacing.x3,
            bottom: tokens.spacing.x3,
            child:
                widget.scrollControlsBuilder?.call(
                  context,
                  _publicController,
                ) ??
                UiMessageScrollControls(
                  show: !_publicController.isAtLiveEdge,
                  queuedMessageCount: _publicController.unseenCount,
                  onScrollToBottom: _jumpToLatest,
                  scrollToBottomLabel: widget.jumpToLatestLabel,
                  queueLabelBuilder: widget.newMessagesLabelBuilder,
                ),
          ),
        ),
      ],
    );
  }
}

// Content changes may shift a visible row's layout offset. Apply that one
// correction during viewport layout, preserving Flutter's current drag/fling
// activity. All input, physics and ballistic behavior remain Flutter's defaults.
class _MessageScrollController extends ScrollController {
  _MessageScrollController(this.layoutCorrection);

  final double Function() layoutCorrection;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _MessageScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    layoutCorrection: layoutCorrection,
  );
}

class _MessageScrollPosition extends ScrollPositionWithSingleContext {
  _MessageScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.layoutCorrection,
  });

  final double Function() layoutCorrection;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final correction = layoutCorrection();
    if (correction.abs() > .01) {
      correctBy(correction);
      return false;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
