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
  int get unseenCount => _unseenCount;
  String? get firstUnseenMessageId => _firstUnseenMessageId;
  bool get hasUnreadMarker => _state?._showsUnreadMarker ?? false;

  Future<void> jumpToLatest({bool animated = true}) async {
    await _state?._jumpToLatest(animated: animated);
  }

  Future<bool> jumpToMessage(
    String id, {
    bool animated = true,
  }) async {
    return await _state?._jumpToMessage(id, animated: animated) ?? false;
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
    final nextFirst =
        clearFirstUnseen ? null : firstUnseenMessageId ?? _firstUnseenMessageId;
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
  )? scrollControlsBuilder;

  @override
  State<UiMessageScroller> createState() => _UiMessageScrollerState();
}

class _UiMessageScrollerState extends State<UiMessageScroller> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  late UiMessageScrollerController _publicController;
  bool _initialized = false;
  bool _ownsPublicController = false;
  bool _loadingEarlier = false;
  bool _loadEarlierInFlight = false;
  bool _wasAtLiveEdge = true;
  double _oldMaxExtent = 0;
  double _oldPixels = 0;
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
    final activeIds = widget.items.map((item) => item.id).toSet();
    if (_showsUnreadMarker && _unreadBoundaryId != null) {
      activeIds.add(_unreadMarkerId);
    }
    if (_showsUnreadMarker && !activeIds.contains(_unreadBoundaryId)) {
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
    _wasAtLiveEdge = _publicController.isAtLiveEdge;
    if (_scrollController.hasClients) {
      _oldMaxExtent = _scrollController.position.maxScrollExtent;
      _oldPixels = _scrollController.position.pixels;
    }
    final oldIds = oldWidget.items.map((item) => item.id).toSet();
    final oldLastIndex = oldWidget.items.isEmpty
        ? -1
        : widget.items.indexWhere(
            (item) => item.id == oldWidget.items.last.id,
          );
    final appendedItems =
        (oldLastIndex < 0 ? widget.items : widget.items.skip(oldLastIndex + 1))
            .where((item) => !oldIds.contains(item.id))
            .toList(growable: false);
    final appended = appendedItems.length;
    final appendedOutgoing = appendedItems.any((item) => item.isOutgoing);
    final appendedIncoming =
        appendedItems.where((item) => !item.isOutgoing).toList(growable: false);
    if (appendedOutgoing) _dismissUnreadMarker(notify: false);
    final prepended = oldWidget.items.isNotEmpty &&
        widget.items.isNotEmpty &&
        widget.items.first.id != oldWidget.items.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      if (prepended && !_wasAtLiveEdge) {
        final delta =
            _scrollController.position.maxScrollExtent - _oldMaxExtent;
        _scrollController.jumpTo(
          (_oldPixels + delta).clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
      if (appendedOutgoing && widget.autoFollow) {
        await _jumpToLatest();
      } else if (appended > 0 && _wasAtLiveEdge && widget.autoFollow) {
        await _jumpToLatest();
      } else if (appendedIncoming.isNotEmpty && !_wasAtLiveEdge) {
        _publicController._update(
          unseenCount: _publicController.unseenCount + appendedIncoming.length,
          firstUnseenMessageId: _publicController.firstUnseenMessageId ??
              appendedIncoming.first.id,
        );
      }
    });
  }

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
        child: widget.unreadMarkerBuilder?.call(context) ??
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
    if (!mounted || _initialized) return;
    _initialized = true;
    if (widget.initialMessageId != null) {
      await _jumpToMessage(widget.initialMessageId!, animated: false);
    } else if (widget.startAtEnd) {
      await _jumpToLatest(animated: false);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atEdge =
        position.maxScrollExtent - position.pixels <= widget.liveEdgeThreshold;
    _publicController._update(
      atLiveEdge: atEdge,
      unseenCount: atEdge ? 0 : null,
      clearFirstUnseen: atEdge,
    );
    if (position.pixels > widget.loadEarlierThreshold &&
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
          _scrollController.position.pixels > widget.loadEarlierThreshold) {
        _loadingEarlier = false;
      }
    }
  }

  Future<void> _jumpToLatest({bool animated = true}) async {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      final motion = UiThemeTokens.motionOf(context);
      await _scrollController.animateTo(
        target,
        duration: motion.standard,
        curve: motion.standardCurve,
      );
    } else {
      _scrollController.jumpTo(target);
    }
    _publicController._update(
      atLiveEdge: true,
      unseenCount: 0,
      clearFirstUnseen: true,
    );
  }

  Future<bool> _jumpToMessage(
    String id, {
    bool animated = true,
  }) async {
    final displayItems = _displayItems();
    final index = displayItems.indexWhere((item) => item.id == id);
    if (index < 0 || !_scrollController.hasClients) return false;
    var targetContext = _keys[id]?.currentContext;
    for (var attempt = 0; targetContext == null && attempt < 12; attempt++) {
      final position = _scrollController.position;
      final averageExtent = widget.items.length <= 1
          ? position.viewportDimension
          : (position.maxScrollExtent + position.viewportDimension) /
              widget.items.length;
      final mountedEntries = <(int, BuildContext)>[];
      for (var builtIndex = 0; builtIndex < displayItems.length; builtIndex++) {
        final builtContext = _keys[displayItems[builtIndex].id]?.currentContext;
        if (builtContext != null && builtContext.mounted) {
          mountedEntries.add((builtIndex, builtContext));
        }
      }
      double estimate;
      if (mountedEntries.isEmpty) {
        estimate = averageExtent * index;
      } else {
        mountedEntries.sort(
          (a, b) => (a.$1 - index).abs().compareTo((b.$1 - index).abs()),
        );
        final nearest = mountedEntries.first;
        final renderObject = nearest.$2.findRenderObject();
        final viewport = renderObject == null
            ? null
            : RenderAbstractViewport.maybeOf(renderObject);
        final nearestOffset = viewport == null
            ? position.pixels
            : viewport.getOffsetToReveal(renderObject!, 0).offset;
        estimate = nearestOffset + (index - nearest.$1) * averageExtent;
      }
      _scrollController.jumpTo(
        estimate.clamp(0, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      targetContext = _keys[id]?.currentContext;
    }
    if (targetContext == null || !targetContext.mounted) return false;
    await Scrollable.ensureVisible(
      targetContext,
      duration:
          animated ? UiThemeTokens.motionOf(context).standard : Duration.zero,
      curve: UiThemeTokens.motionOf(context).standardCurve,
      alignment: .5,
    );
    return true;
  }

  @override
  void dispose() {
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

    return AnimatedBuilder(
      animation: _publicController,
      builder: (context, _) {
        return Stack(children: [
          ListView.builder(
            controller: _scrollController,
            padding: widget.padding,
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final key = _keys.putIfAbsent(item.id, GlobalKey.new);
              return Padding(
                key: key,
                padding: EdgeInsets.only(
                  bottom:
                      index == displayItems.length - 1 ? 0 : widget.itemSpacing,
                ),
                child: item.child,
              );
            },
          ),
          PositionedDirectional(
            end: tokens.spacing.x3,
            bottom: tokens.spacing.x3,
            child: widget.scrollControlsBuilder?.call(
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
        ]);
      },
    );
  }
}
