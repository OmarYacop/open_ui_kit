import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/intl/intl.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
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
/// The [trigger] widget is made tappable; on tap (and optionally long
/// press) an overlay with the [items] renders below. Keyboard users can
/// move up/down through the rows and activate them with Enter/Space.
class UiDropdownMenu extends StatefulWidget {
  const UiDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
    this.minWidth = 220,
    this.maxWidth = 320,
    this.openOnLongPress = false,
    this.closeOnSelect = true,
  });

  final Widget trigger;
  final List<UiMenuNode> items;
  final double minWidth;
  final double maxWidth;
  final bool openOnLongPress;
  final bool closeOnSelect;

  @override
  State<UiDropdownMenu> createState() => _UiDropdownMenuState();
}

class _UiDropdownMenuState extends State<UiDropdownMenu> {
  final GlobalKey _targetKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final FocusScopeNode _focusScope = FocusScopeNode(debugLabel: 'UiMenu');
  OverlayEntry? _entry;
  int? _focusIndex;
  // Placement state — set by `_resolveOverlayPlacement` right before
  // inserting the overlay entry. Mirrors the same idea as `UiSelect`:
  // if there's more room above the trigger than below, flip the menu.
  bool _openAbove = false;
  double _menuMaxHeight = 360;
  double? _triggerWidth;
  Rect? _targetGlobalRect;

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

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _focusIndex = 0;
    _resolveOverlayPlacement(overlay);
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: overlay.context,
    );
    _entry = OverlayEntry(
      builder: (overlayContext) =>
          capturedThemes.wrap(_buildOverlay(overlayContext)),
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
    // Rough height estimate — menus mix items, separators, and group
    // captions so an exact measurement is impractical without a dry
    // layout pass. 40pt per node is close enough for the ceiling we
    // clamp to, and the inner scroll view handles overflow either way.
    final estimated = widget.items.length * 40.0 + 16.0;
    final ceiling = math.min(360.0, estimated);
    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: estimated,
      maxHeight: ceiling,
      crampedAvailableHeight: 120,
      allowOverflowWhenCramped: true,
    );
    if (geometry == null) return;

    _targetGlobalRect = geometry.targetGlobalRect;
    _triggerWidth = geometry.triggerWidth;
    _openAbove = geometry.openAbove;
    _menuMaxHeight = geometry.maxHeight;
  }

  void _close({bool notify = true}) {
    final entry = _entry;
    _entry = null;
    _focusIndex = null;
    entry?.remove();
    if (notify && mounted) setState(() {});
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
                    horizontal: tokens.spacing.x3,
                    vertical: tokens.spacing.x1,
                  ),
                  child: UiText(
                    node.label!,
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                  ),
                ),
              for (final item in node.items)
                Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: tokens.spacing.x1 / 2),
                  child: _MenuRow(
                    item: item,
                    focused: (++rowIndex) == _focusIndex,
                    onActivate: _activate,
                  ),
                ),
            ],
          );
        case UiMenuItem():
          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.x1 / 2),
            child: _MenuRow(
              item: node,
              focused: (++rowIndex) == _focusIndex,
              onActivate: _activate,
            ),
          );
        case UiMenuSubmenu():
          return Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.x1 / 2),
            child: _SubmenuRow(submenu: node),
          );
      }
    }

    final verticalOffset = tokens.spacing.x1;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handleOverlayPointerDown,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _openAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _openAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(0, _openAbove ? -verticalOffset : verticalOffset),
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
                borderRadius: tokens.radius.mdAll,
                boxShadow: tokens.shadows.md,
                padding: EdgeInsets.all(tokens.spacing.x2),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.minWidth,
                    maxWidth: widget.maxWidth,
                    maxHeight: _menuMaxHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final n in widget.items) buildNode(n)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    final targetRect = _targetGlobalRect;
    if (targetRect == null || targetRect.contains(event.position)) {
      _close();
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final open = _entry != null;
    return CompositedTransformTarget(
      key: _targetKey,
      link: _link,
      child: UiPressable(
        onPressed: _toggle,
        onLongPress: widget.openOnLongPress ? _toggle : null,
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
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
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
            borderRadius: tokens.radius.mdAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x3,
              vertical: tokens.spacing.x2,
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
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: _InlineSpinner(color: fg),
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

    return UiPressable(
      onPressed:
          widget.submenu.enabled ? () => setState(() => _open = !_open) : null,
      minTapSize: 0,
      builder: (context, state, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiBox(
            background: state.hovered ? c.accent : const Color(0x00000000),
            borderRadius: tokens.radius.mdAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x3,
              vertical: tokens.spacing.x2,
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
                  _open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: c.mutedForeground,
                ),
              ],
            ),
          ),
          if (_open)
            Padding(
              padding: EdgeInsets.only(
                left: tokens.spacing.x4,
                top: tokens.spacing.x1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in widget.submenu.items)
                    if (n is UiMenuItem)
                      _MenuRow(
                        item: n,
                        focused: false,
                        onActivate: (item) async {
                          await item.onPressed?.call();
                        },
                      ),
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
  final AlignmentGeometry origin;

  @override
  State<_ScaleFade> createState() => _ScaleFadeState();
}

class _ScaleFadeState extends State<_ScaleFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  )..forward();

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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: widget.origin,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _InlineSpinner extends StatefulWidget {
  const _InlineSpinner({required this.color});
  final Color color;

  @override
  State<_InlineSpinner> createState() => _InlineSpinnerState();
}

class _InlineSpinnerState extends State<_InlineSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.rotate(
        angle: _c.value * 6.28318,
        child: CustomPaint(
          painter: _SpinnerPainter(widget.color),
          size: const Size.square(14),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(1), -1.2, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) => old.color != color;
}
