import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/intl/intl.dart';
import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_progress.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/scrolling/ui_scroll_configuration.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Base type for anything that can appear in a [UiDropdownMenu].
sealed class UiMenuNode {
  const UiMenuNode();
}

/// Single actionable row in the menu.
class UiMenuItem extends UiMenuNode {
  const UiMenuItem({
    required this.label,
    this.onPressed,
    this.leading,
    this.shortcut,
    this.enabled = true,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final Widget? leading;

  /// Optional trailing shortcut glyph (e.g. `UiMenuShortcut('⌘K')`).
  final UiMenuShortcut? shortcut;
  final bool enabled;
  final bool destructive;
  final bool loading;
}

/// Shortcut display widget (kept alongside items, not an item itself).
@immutable
class UiMenuShortcut {
  const UiMenuShortcut(this.label);
  final String label;
}

/// Labelled cluster of items; renders an optional caption + items.
class UiMenuGroup extends UiMenuNode {
  const UiMenuGroup({this.label, required this.items});
  final String? label;
  final List<UiMenuItem> items;
}

/// Horizontal separator between groups/items.
class UiMenuSeparator extends UiMenuNode {
  const UiMenuSeparator();
}

/// Long-press / hover submenu. Rendered inline as a row that opens a
/// nested menu on tap.
class UiMenuSubmenu extends UiMenuNode {
  const UiMenuSubmenu({
    required this.label,
    required this.items,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final List<UiMenuNode> items;
  final Widget? leading;
  final bool enabled;
}

/// Dropdown menu surface + trigger.
///
/// The [trigger] widget is made tappable; on tap (and optionally long press)
/// an overlay with the [items] renders below. When [openOnLongPress] is true,
/// the initiating pointer can drag across items and release to select one.
/// Keyboard users can move up/down through the rows and activate them with
/// Enter/Space.
class UiDropdownMenu extends StatefulWidget {
  const UiDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
    this.minWidth = 220,
    this.maxWidth = 320,
    this.openOnLongPress = true,
    this.closeOnSelect = true,
    this.dismissOnTapOutside = true,
  });

  final Widget trigger;
  final List<UiMenuNode> items;
  final double minWidth;
  final double maxWidth;

  /// Opens the menu on long press and enables drag-to-select for that press.
  final bool openOnLongPress;
  final bool closeOnSelect;

  /// Whether a pointer tap outside the trigger and menu dismisses it.
  ///
  /// Outside taps never block the underlying control. Scroll and drag gestures
  /// do not dismiss the menu. Defaults to true.
  final bool dismissOnTapOutside;

  @override
  State<UiDropdownMenu> createState() => _UiDropdownMenuState();
}

class _UiDropdownMenuState extends State<UiDropdownMenu> {
  final GlobalKey _targetKey = GlobalKey();
  final FocusScopeNode _focusScope = FocusScopeNode(debugLabel: 'UiMenu');
  final Object _tapRegionGroup = Object();
  final Map<ScrollPosition, double> _anchorScrollOffsets =
      <ScrollPosition, double>{};
  OverlayState? _overlay;
  OverlayEntry? _entry;
  int? _focusIndex;
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  int? _activePointer;
  bool _dragSelecting = false;
  // Placement state — set by `_resolveOverlayPlacement` right before
  // inserting the overlay entry. Mirrors the same idea as `UiSelect`:
  // if there's more room above the trigger than below, flip the menu.
  bool _openAbove = false;
  double _menuMaxHeight = 360;
  double _menuWidth = 220;
  bool _contentFits = true;
  double? _triggerWidth;
  double _overlayLeft = 0;
  double _overlayTop = 0;

  @override
  void dispose() {
    _close(notify: false);
    _focusScope.dispose();
    super.dispose();
  }

  List<UiMenuItem> _flatItems() {
    final acc = <UiMenuItem>[];
    for (final n in widget.items) {
      switch (n) {
        case UiMenuItem():
          acc.add(n);
        case UiMenuGroup():
          acc.addAll(n.items);
        case UiMenuSubmenu():
        case UiMenuSeparator():
          break;
      }
    }
    return acc;
  }

  void _syncItemKeys(int length) {
    while (_itemKeys.length < length) {
      _itemKeys.add(GlobalKey());
    }
    if (_itemKeys.length > length) {
      _itemKeys.removeRange(length, _itemKeys.length);
    }
  }

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = UiLayeredOverlay.maybeOf(
          context,
          UiOverlayLayer.floating,
        ) ??
        Overlay.maybeOf(context);
    if (overlay == null) return;
    final items = _flatItems();
    _syncItemKeys(items.length);
    _focusIndex = items.isEmpty ? null : 0;
    _resolveOverlayPlacement(overlay);
    // Semantic layer overlays are siblings of the page subtree rather than
    // ancestors, so capture all inherited themes at the trigger boundary.
    final capturedThemes = InheritedTheme.capture(from: context, to: null);
    _overlay = overlay;
    _listenToAncestorScrollables();
    _entry = OverlayEntry(
      builder: (overlayContext) => capturedThemes.wrap(
        UiScrollConfiguration(child: _buildOverlay(overlayContext)),
      ),
    );
    overlay.insert(_entry!);
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusScope.requestFocus();
    });
  }

  /// Pick whichever side of the trigger has more room and cap the
  /// menu's max height to that side's available space. Mirrors the
  /// logic used by `UiSelect` so both overlays behave the same when
  /// they're near the top or bottom of the screen.
  void _resolveOverlayPlacement(OverlayState overlay) {
    final tokens = UiThemeTokens.of(context);
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final bodyStyle = tokens.typography.body;
    final captionStyle = tokens.typography.caption;
    final surfaceInset = tokens.spacing.x2 / 1.5;
    final itemGap = tokens.spacing.x1;
    final bodyHeight =
        textScaler.scale(bodyStyle.fontSize ?? 14) * (bodyStyle.height ?? 1) +
            tokens.spacing.x3;
    final captionHeight = textScaler.scale(captionStyle.fontSize ?? 12) *
            (captionStyle.height ?? 1) +
        tokens.spacing.x3;

    double nodeHeight(UiMenuNode node) => switch (node) {
          UiMenuItem() || UiMenuSubmenu() => bodyHeight,
          UiMenuSeparator() => 1 + tokens.spacing.x2,
          UiMenuGroup() => (node.label == null ? 0 : captionHeight) +
              node.items.length * bodyHeight +
              math.max(0, node.items.length - 1) * itemGap,
        };

    // Match shadcn's p-1 content inset. Unlike the previous fixed 360px
    // ceiling, the desired height accounts for every row inside groups and
    // lets a menu use all of the safe viewport when it is available.
    final estimated = widget.items.fold<double>(
          surfaceInset * 2,
          (height, node) => height + nodeHeight(node),
        ) +
        math.max(0, widget.items.length - 1) * itemGap;
    final desiredWidth = _preferredMenuWidth(
      tokens: tokens,
      textScaler: textScaler,
      surfaceInset: surfaceInset,
    );
    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: estimated,
      maxHeight: estimated,
      desiredWidth: desiredWidth,
      minWidth: math.min(widget.minWidth, desiredWidth),
    );
    if (geometry == null) return;

    _triggerWidth = geometry.triggerWidth;
    _openAbove = geometry.openAbove;
    // Geometry describes the complete surface. The constraints below apply
    // inside the menu's content inset on each edge.
    _menuMaxHeight = math.max(0, geometry.maxHeight - surfaceInset * 2);
    _menuWidth = math.max(
      0,
      math.min(desiredWidth, geometry.width) - surfaceInset * 2,
    );
    _contentFits = estimated <= geometry.maxHeight + 0.5;
    final outerHeight = math.min(estimated, geometry.maxHeight);
    _overlayLeft = geometry.targetOverlayRect.left + geometry.horizontalOffset;
    _overlayTop = geometry.openAbove
        ? geometry.targetOverlayRect.top - geometry.gap - outerHeight
        : geometry.targetOverlayRect.bottom + geometry.gap;
  }

  double _preferredMenuWidth({
    required UiThemeTokens tokens,
    required TextScaler textScaler,
    required double surfaceInset,
  }) {
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final rowPadding = tokens.spacing.x2 * 2;
    final bodyStyle = tokens.typography.body;
    final captionStyle = tokens.typography.caption;

    double itemWidth(UiMenuItem item) {
      var width = rowPadding + textWidth(item.label, bodyStyle);
      if (item.leading != null) width += 16 + tokens.spacing.x2;
      if (item.loading) {
        width += tokens.spacing.x3 + 14;
      } else if (item.shortcut != null) {
        width +=
            tokens.spacing.x3 + textWidth(item.shortcut!.label, captionStyle);
      }
      return width;
    }

    double nodeWidth(UiMenuNode node) => switch (node) {
          UiMenuItem() => itemWidth(node),
          UiMenuSubmenu() => rowPadding +
              textWidth(node.label, bodyStyle) +
              (node.leading == null ? 0 : 16 + tokens.spacing.x2) +
              tokens.spacing.x3 +
              16,
          UiMenuSeparator() => 0,
          UiMenuGroup() => math.max(
              node.label == null
                  ? 0
                  : rowPadding + textWidth(node.label!, captionStyle),
              node.items.fold<double>(
                0,
                (width, item) => math.max(width, itemWidth(item)),
              ),
            ),
        };

    final contentWidth = widget.items.fold<double>(
      0,
      (width, node) => math.max(width, nodeWidth(node)),
    );
    return math.min(
      widget.maxWidth,
      math.max(widget.minWidth, contentWidth + surfaceInset * 2),
    );
  }

  void _close({bool notify = true}) {
    final entry = _entry;
    _entry = null;
    _overlay = null;
    _stopListeningToAncestorScrollables();
    _focusIndex = null;
    _dragSelecting = false;
    entry?.remove();
    if (notify && mounted) setState(() {});
  }

  void _listenToAncestorScrollables() {
    _stopListeningToAncestorScrollables();
    context.visitAncestorElements((element) {
      if (element case StatefulElement(state: final ScrollableState state)) {
        final position = state.position;
        if (!_anchorScrollOffsets.containsKey(position)) {
          _anchorScrollOffsets[position] = position.pixels;
          position.addListener(_handleAnchorScroll);
        }
      }
      return true;
    });
  }

  void _stopListeningToAncestorScrollables() {
    for (final position in _anchorScrollOffsets.keys) {
      position.removeListener(_handleAnchorScroll);
    }
    _anchorScrollOffsets.clear();
  }

  void _handleAnchorScroll() {
    if (!mounted || _overlay == null || _entry == null) return;
    for (final position in _anchorScrollOffsets.keys) {
      final previous = _anchorScrollOffsets[position]!;
      final delta = position.pixels - previous;
      _anchorScrollOffsets[position] = position.pixels;
      switch (position.axisDirection) {
        case AxisDirection.down:
          _overlayTop -= delta;
        case AxisDirection.up:
          _overlayTop += delta;
        case AxisDirection.right:
          _overlayLeft -= delta;
        case AxisDirection.left:
          _overlayLeft += delta;
      }
    }
    _entry?.markNeedsBuild();
  }

  void _beginDragSelection() {
    if (_entry == null) _open();
    if (_entry == null) return;
    _dragSelecting = true;
  }

  int? _itemAt(Offset globalPosition) {
    for (var index = 0; index < _itemKeys.length; index++) {
      final renderObject = _itemKeys[index].currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (bounds.contains(globalPosition)) return index;
    }
    return null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_dragSelecting || event.pointer != _activePointer) return;
    final index = _itemAt(event.position);
    if (_focusIndex == index) return;
    _focusIndex = index;
    _entry?.markNeedsBuild();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    if (!_dragSelecting) return;
    _dragSelecting = false;
    final index = _itemAt(event.position);
    final items = _flatItems();
    if (index != null && index < items.length) {
      _activate(items[index]);
    } else {
      _entry?.markNeedsBuild();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _dragSelecting = false;
    _entry?.markNeedsBuild();
  }

  Future<void> _activate(UiMenuItem item) async {
    if (!item.enabled || item.loading) return;
    // Run the action first, then close. Closing first risks unmounting
    // context the action depended on; doing it after keeps hooks like
    // `Navigator.of(context).pop(...)` intact.
    await item.onPressed?.call();
    if (widget.closeOnSelect) _close();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final items = _flatItems();
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusIndex = ((_focusIndex ?? -1) + 1) % items.length;
      _entry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusIndex = ((_focusIndex ?? 0) - 1 + items.length) % items.length;
      _entry?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      final i = _focusIndex;
      if (i != null && i >= 0 && i < items.length) {
        _activate(items[i]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildOverlay(BuildContext context) {
    final tokens = UiThemeTokens.of(this.context);
    final c = tokens.colors;
    var rowIndex = -1;

    Widget buildNode(UiMenuNode node) {
      switch (node) {
        case UiMenuSeparator():
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: UiDivider(),
          );
        case UiMenuGroup():
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (node.label != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.x2,
                    vertical: tokens.spacing.x3 / 2,
                  ),
                  child: UiText(
                    node.label!,
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                  ),
                ),
              for (var index = 0; index < node.items.length; index++) ...[
                if (index > 0) SizedBox(height: tokens.spacing.x1),
                _MenuRow(
                  key: _itemKeys[rowIndex + 1],
                  item: node.items[index],
                  focused: (++rowIndex) == _focusIndex,
                  onActivate: _activate,
                ),
              ],
            ],
          );
        case UiMenuItem():
          return _MenuRow(
            key: _itemKeys[rowIndex + 1],
            item: node,
            focused: (++rowIndex) == _focusIndex,
            onActivate: _activate,
          );
        case UiMenuSubmenu():
          return _SubmenuRow(submenu: node);
      }
    }

    return Stack(
      children: [
        Positioned(
          left: _overlayLeft,
          top: _overlayTop,
          child: UiAnchoredOverlayTapRegion(
            groupId: _tapRegionGroup,
            enabled: widget.dismissOnTapOutside,
            onDismiss: _close,
            child: FocusScope(
              node: _focusScope,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: _ScaleFade(
                // When opening upward, anchor the scale animation to the
                // bottom-left so the reveal grows *toward* the trigger.
                origin: _openAbove ? Alignment.bottomLeft : Alignment.topLeft,
                child: UiBox(
                  background: c.popover,
                  border: Border.all(color: c.border),
                  borderRadius: tokens.radius.lgAll,
                  boxShadow: tokens.shadows.md,
                  padding: EdgeInsets.all(tokens.spacing.x2 / 1.5),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: _menuWidth,
                      maxWidth: _menuWidth,
                      maxHeight: _menuMaxHeight,
                    ),
                    child: Builder(builder: (context) {
                      final children = <Widget>[];
                      for (final node in widget.items) {
                        if (children.isNotEmpty) {
                          children.add(SizedBox(height: tokens.spacing.x1));
                        }
                        children.add(buildNode(node));
                      }
                      final content = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      );
                      return _contentFits
                          ? content
                          : SingleChildScrollView(child: content);
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = _entry != null;
    return TapRegion(
      groupId: _tapRegionGroup,
      child: KeyedSubtree(
        key: _targetKey,
        child: Listener(
          onPointerDown: widget.openOnLongPress
              ? (event) => _activePointer = event.pointer
              : null,
          onPointerMove: widget.openOnLongPress ? _handlePointerMove : null,
          onPointerUp: widget.openOnLongPress ? _handlePointerUp : null,
          onPointerCancel: widget.openOnLongPress ? _handlePointerCancel : null,
          child: UiPressable(
            onPressed: _toggle,
            onLongPress: widget.openOnLongPress ? _beginDragSelection : null,
            minTapSize: 0,
            semanticsLabel: UiLocalizations.of(context).menu,
            builder: (context, state, _) {
              if (!open || _triggerWidth == null) return widget.trigger;
              return ConstrainedBox(
                constraints: BoxConstraints(minWidth: _triggerWidth!),
                child: widget.trigger,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.item,
    required this.focused,
    required this.onActivate,
  });

  final UiMenuItem item;
  final bool focused;
  final Future<void> Function(UiMenuItem) onActivate;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final fg = item.enabled
        ? (item.destructive ? c.destructive : c.popoverForeground)
        : c.mutedForeground;

    // Screen-reader announcement: destructive items explicitly name
    // themselves as destructive; loading items report `busy`. The inner
    // UiPressable's Semantics(button: true) is still applied so hit
    // targeting and ActivateIntent continue to fire.
    final hint = <String>[
      if (item.destructive) 'destructive action',
      if (item.loading) 'busy',
      if (!item.enabled) 'disabled',
    ].join(', ');

    return Semantics(
      button: true,
      enabled: item.enabled && !item.loading,
      label: item.label,
      hint: hint.isEmpty ? null : hint,
      excludeSemantics: true,
      child: UiPressable(
        enabled: item.enabled && !item.loading,
        onPressed: () => onActivate(item),
        minTapSize: 0,
        excludeFromSemantics: true,
        builder: (context, state, _) {
          final hover = state.hovered || state.pressed || focused;
          final destructiveBg = c.destructive.withValues(
            alpha: state.pressed ? 0.2 : 0.14,
          );
          return UiBox(
            background: hover
                ? (item.destructive ? destructiveBg : c.accent)
                : const Color(0x00000000),
            borderRadius: tokens.radius.smAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x2,
              vertical: tokens.spacing.x3 / 2,
            ),
            child: Row(
              children: [
                if (item.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: fg, size: 16),
                    child: item.leading!,
                  ),
                  SizedBox(width: tokens.spacing.x2),
                ],
                Expanded(
                  child: UiText(
                    item.label,
                    variant: UiTextVariant.body,
                    style: TextStyle(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.loading)
                  UiSpinner(
                    size: 14,
                    strokeWidth: 2.8,
                    color: fg,
                  )
                else if (item.shortcut != null) ...[
                  SizedBox(width: tokens.spacing.x3),
                  UiText(
                    item.shortcut!.label,
                    variant: UiTextVariant.caption,
                    style: item.destructive
                        ? TextStyle(
                            color: c.destructive.withValues(alpha: 0.85),
                          )
                        : null,
                    tone: item.destructive
                        ? UiTextTone.primary
                        : UiTextTone.muted,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubmenuRow extends StatefulWidget {
  const _SubmenuRow({required this.submenu});
  final UiMenuSubmenu submenu;

  @override
  State<_SubmenuRow> createState() => _SubmenuRowState();
}

class _SubmenuRowState extends State<_SubmenuRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final nestedItems = widget.submenu.items.whereType<UiMenuItem>().toList();

    return UiPressable(
      onPressed:
          widget.submenu.enabled ? () => setState(() => _open = !_open) : null,
      minTapSize: 0,
      builder: (context, state, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiBox(
            background: state.hovered ? c.accent : const Color(0x00000000),
            borderRadius: tokens.radius.xsAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x2,
              vertical: tokens.spacing.x3 / 2,
            ),
            child: Row(
              children: [
                if (widget.submenu.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: c.popoverForeground, size: 16),
                    child: widget.submenu.leading!,
                  ),
                  SizedBox(width: tokens.spacing.x2),
                ],
                Expanded(
                  child: UiText(
                    widget.submenu.label,
                    variant: UiTextVariant.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _open
                      ? LucideIcons.chevronDown
                      : UiDirectionalIcons.chevronForward(context),
                  size: 16,
                  color: c.mutedForeground,
                ),
              ],
            ),
          ),
          if (_open)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.spacing.x4,
                top: tokens.spacing.x1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < nestedItems.length; index++) ...[
                    if (index > 0) SizedBox(height: tokens.spacing.x1),
                    _MenuRow(
                      item: nestedItems[index],
                      focused: false,
                      onActivate: (item) async {
                        await item.onPressed?.call();
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaleFade extends StatefulWidget {
  const _ScaleFade({
    required this.child,
    this.origin = Alignment.topLeft,
  });
  final Widget child;

  /// Anchor point for the scale transform. When the menu opens below
  /// the trigger this is `topLeft` so the surface grows downward; when
  /// it opens above, pass `bottomLeft` so the growth direction tracks
  /// the trigger.
  final Alignment origin;

  @override
  State<_ScaleFade> createState() => _ScaleFadeState();
}

class _ScaleFadeState extends State<_ScaleFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = UiThemeTokens.motionOf(context);
    _c.duration = motion.fast;
    if (_started) return;
    _started = true;
    if (motion.fast == Duration.zero) {
      _c.value = 1.0;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Isolate the menu surface in its own layer — the scale/opacity
    // animation would otherwise invalidate the page content below
    // every frame.
    final motion = UiThemeTokens.motionOf(context);
    final curved = CurvedAnimation(parent: _c, curve: motion.standardCurve);
    return UiFadeScaleTransition(
      animation: curved,
      beginScale: 0.96,
      alignment: widget.origin,
      repaintBoundary: true,
      child: widget.child,
    );
  }
}
