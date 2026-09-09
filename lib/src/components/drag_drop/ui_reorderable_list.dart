import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// The builder receives a fully wired handle; place it beside any custom content.
typedef UiReorderableItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
  Widget handle,
);

/// Controlled vertical sorting with stable keys, auto-scroll and keyboard moves.
///
/// [onReorder] receives the final destination index, after removal. Update the
/// backing collection synchronously: `items.insert(to, items.removeAt(from))`.
/// Items are never mutated by the component. Only the supplied handle starts a
/// drag, leaving row buttons, editors and selection independent.
class UiReorderableList<T> extends StatefulWidget {
  const UiReorderableList({
    super.key,
    required this.items,
    required this.itemKey,
    required this.itemBuilder,
    required this.itemLabel,
    required this.onReorder,
    this.enabled = true,
    this.shrinkWrap = false,
    this.itemExtent,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.moveUpLabel = 'Move up',
    this.moveDownLabel = 'Move down',
  }) : itemCount = null,
       itemAt = null;

  /// Lazily builds content; keys and labels must be cheap metadata lookups.
  const UiReorderableList.builder({
    super.key,
    required this.itemCount,
    required this.itemAt,
    required this.itemKey,
    required this.itemBuilder,
    required this.itemLabel,
    required this.onReorder,
    this.enabled = true,
    this.shrinkWrap = false,
    this.itemExtent,
    this.physics,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.moveUpLabel = 'Move up',
    this.moveDownLabel = 'Move down',
  }) : items = const [];

  final int? itemCount;
  final T Function(int index)? itemAt;
  final List<T> items;
  final LocalKey Function(T item) itemKey;
  final String Function(T item) itemLabel;
  final UiReorderableItemBuilder<T> itemBuilder;
  final void Function(int from, int to) onReorder;
  final bool enabled;
  final bool shrinkWrap;
  final double? itemExtent;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final String moveUpLabel;
  final String moveDownLabel;

  @override
  State<UiReorderableList<T>> createState() => _UiReorderableListState<T>();
}

class _UiReorderableListState<T> extends State<UiReorderableList<T>> {
  final _listKey = GlobalKey<ReorderableListState>();
  List<LocalKey>? _dragKeys;
  final _moveFocus = FocusNode();
  LocalKey? _keyboardKey;

  @override
  void dispose() {
    _moveFocus.dispose();
    super.dispose();
  }

  void _keyboardMove(int from, int to) {
    _keyboardKey = widget.itemKey(_item(from));
    _move(from, to);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled && _moveFocus.context != null) {
        _moveFocus.requestFocus();
      }
    });
  }

  int get _count => widget.itemCount ?? widget.items.length;
  T _item(int index) => widget.itemAt?.call(index) ?? widget.items[index];
  List<LocalKey> get _keys =>
      List.generate(_count, (index) => widget.itemKey(_item(index)));

  @override
  void didUpdateWidget(covariant UiReorderableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        (_dragKeys != null && !_sameKeys(_dragKeys!, _keys))) {
      _listKey.currentState?.cancelReorder();
      _dragKeys = null;
    }
  }

  bool _sameKeys(List<LocalKey> a, List<LocalKey> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _move(int from, int to) {
    if (!widget.enabled || from == to || to < 0 || to >= _count) {
      return;
    }
    widget.onReorder(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    assert(
      _keys.toSet().length == _count,
      'Reorderable items need unique stable keys.',
    );
    return ReorderableList(
      key: _listKey,
      itemCount: _count,
      itemExtent: widget.itemExtent,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      controller: widget.controller,
      padding: widget.padding,
      onReorderStart: (_) => _dragKeys = _keys,
      onReorderItem: (from, to) {
        if (_dragKeys != null && _sameKeys(_dragKeys!, _keys)) _move(from, to);
        _dragKeys = null;
      },
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final progress = tokens.motion.standard == Duration.zero
              ? 1.0
              : tokens.motion.standardCurve.transform(animation.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.card,
              borderRadius: tokens.radius.mdAll,
              boxShadow: BoxShadow.lerpList(
                tokens.shadows.none,
                tokens.shadows.lg,
                progress,
              ),
            ),
            child: child,
          );
        },
      ),
      itemBuilder: (context, index) {
        final item = _item(index);
        return KeyedSubtree(
          key: widget.itemKey(item),
          child: widget.itemBuilder(
            context,
            item,
            index,
            UiDragHandle(
              index: index,
              focusNode: widget.itemKey(item) == _keyboardKey
                  ? _moveFocus
                  : null,
              enabled: widget.enabled,
              semanticLabel: widget.itemLabel(item),
              moveUpLabel: widget.moveUpLabel,
              moveDownLabel: widget.moveDownLabel,
              onMoveUp: index > 0
                  ? () => _keyboardMove(index, index - 1)
                  : null,
              onMoveDown: index < _count - 1
                  ? () => _keyboardMove(index, index + 1)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// A 44px grip with focus indication, pointer dragging and semantic move actions.
/// Focus the handle and press Arrow Up/Down to move one position.
class UiDragHandle extends StatefulWidget {
  const UiDragHandle({
    super.key,
    required this.index,
    required this.semanticLabel,
    this.enabled = true,
    this.focusNode,
    this.onMoveUp,
    this.onMoveDown,
    this.moveUpLabel = 'Move up',
    this.moveDownLabel = 'Move down',
  });

  final FocusNode? focusNode;
  final int index;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String moveUpLabel;
  final String moveDownLabel;

  @override
  State<UiDragHandle> createState() => _UiDragHandleState();
}

class _UiDragHandleState extends State<UiDragHandle> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: widget.enabled,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        if (!widget.enabled || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final action = event.logicalKey == LogicalKeyboardKey.arrowUp
            ? widget.onMoveUp
            : event.logicalKey == LogicalKeyboardKey.arrowDown
            ? widget.onMoveDown
            : null;
        if (action == null) return KeyEventResult.ignored;
        action();
        return KeyEventResult.handled;
      },
      child: Semantics(
        label: widget.semanticLabel,
        enabled: widget.enabled,
        customSemanticsActions: widget.enabled
            ? {
                if (widget.onMoveUp != null)
                  CustomSemanticsAction(label: widget.moveUpLabel):
                      widget.onMoveUp!,
                if (widget.onMoveDown != null)
                  CustomSemanticsAction(label: widget.moveDownLabel):
                      widget.onMoveDown!,
              }
            : null,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.grab
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: ReorderableDragStartListener(
            index: widget.index,
            enabled: widget.enabled,
            child: UiFocusRing(
              visible: _focused,
              offset: -2,
              borderRadius: tokens.radius.smAll,
              child: AnimatedContainer(
                duration: tokens.motion.fast,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hovered && widget.enabled
                      ? tokens.colors.accent
                      : const Color(0x00000000),
                  borderRadius: tokens.radius.smAll,
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(12, 18),
                    painter: _GripPainter(
                      tokens.colors.mutedForeground.withValues(
                        alpha: widget.enabled ? 1 : 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GripPainter extends CustomPainter {
  const _GripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final x in [size.width * 0.25, size.width * 0.75]) {
      for (final y in [size.height / 6, size.height / 2, size.height * 5 / 6]) {
        canvas.drawCircle(Offset(x, y), 1.25, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter oldDelegate) => color != oldDelegate.color;
}
