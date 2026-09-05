import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../foundation/overlay/ui_anchored_surface.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

enum UiTooltipSide { top, bottom, left, right }

class UiTooltip extends StatefulWidget {
  const UiTooltip({
    super.key,
    required this.message,
    required this.child,
    this.side = UiTooltipSide.right,
    this.showOnHover = true,
    this.showOnLongPress = true,
    this.dismissDelay = const Duration(milliseconds: 900),
  });

  final String message;
  final Widget child;
  final UiTooltipSide side;
  final bool showOnHover;
  final bool showOnLongPress;
  final Duration dismissDelay;

  @override
  State<UiTooltip> createState() => _UiTooltipState();
}

class _UiTooltipState extends State<UiTooltip> {
  final _portal = OverlayPortalController();
  Timer? _dismissTimer;
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _show() {
    _dismissTimer?.cancel();
    if (widget.message.trim().isEmpty || Overlay.maybeOf(context) == null) {
      return;
    }
    _portal.show();
  }

  void _hideSoon() {
    if (_focused || _hovered) return;
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.dismissDelay, _hide);
  }

  void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;

    if (widget.showOnHover) {
      content = MouseRegion(
        onEnter: (_) {
          _hovered = true;
          _show();
        },
        onExit: (_) {
          _hovered = false;
          _hideSoon();
        },
        child: content,
      );
    }

    if (widget.showOnLongPress) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (_) => _show(),
        onLongPressEnd: (_) => _hideSoon(),
        onLongPressCancel: _hideSoon,
        child: content,
      );
    }

    return UiAnchoredSurface(
      controller: _portal,
      side: UiAnchoredSurfaceSide.values[widget.side.index],
      overlayChild: IgnorePointer(
        child: ExcludeSemantics(child: _TooltipBubble(message: widget.message)),
      ),
      child: Semantics(
        tooltip: widget.message,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            _focused = focused;
            if (focused) {
              _show();
            } else {
              _hideSoon();
            }
          },
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape &&
                _portal.isShowing) {
              _hide();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: content,
        ),
      ),
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;

    return UiBox(
      background: colors.popover,
      border: Border.all(color: colors.border),
      borderRadius: tokens.radius.mdAll,
      boxShadow: tokens.shadows.md,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x3,
        vertical: tokens.spacing.x2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: UiText(
          message,
          variant: UiTextVariant.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
