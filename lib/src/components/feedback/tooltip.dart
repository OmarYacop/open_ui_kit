import 'dart:async';

import 'package:flutter/widgets.dart';

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
  OverlayEntry? _entry;
  Timer? _dismissTimer;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _hide();
    super.dispose();
  }

  void _show() {
    if (_entry != null || widget.message.trim().isEmpty) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final tokens = UiThemeTokens.of(context);
    final direction = Directionality.of(context);

    _dismissTimer?.cancel();
    _entry = OverlayEntry(
      builder: (context) => Directionality(
        textDirection: direction,
        child: _TooltipOverlay(
          anchor: rect,
          message: widget.message,
          side: widget.side,
          gap: tokens.spacing.x2,
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hideSoon() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(widget.dismissDelay, _hide);
  }

  void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;

    if (widget.showOnHover) {
      content = MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hideSoon(),
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

    return content;
  }
}

class _TooltipOverlay extends StatelessWidget {
  const _TooltipOverlay({
    required this.anchor,
    required this.message,
    required this.side,
    required this.gap,
  });

  final Rect anchor;
  final String message;
  final UiTooltipSide side;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _TooltipLayoutDelegate(
            anchor: anchor,
            side: side,
            gap: gap,
          ),
          child: _TooltipBubble(message: message),
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

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  const _TooltipLayoutDelegate({
    required this.anchor,
    required this.side,
    required this.gap,
  });

  final Rect anchor;
  final UiTooltipSide side;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final preferred = switch (side) {
      UiTooltipSide.top => Offset(
          anchor.center.dx - childSize.width / 2,
          anchor.top - childSize.height - gap,
        ),
      UiTooltipSide.bottom => Offset(
          anchor.center.dx - childSize.width / 2,
          anchor.bottom + gap,
        ),
      UiTooltipSide.left => Offset(
          anchor.left - childSize.width - gap,
          anchor.center.dy - childSize.height / 2,
        ),
      UiTooltipSide.right => Offset(
          anchor.right + gap,
          anchor.center.dy - childSize.height / 2,
        ),
    };

    return Offset(
      preferred.dx.clamp(gap, size.width - childSize.width - gap),
      preferred.dy.clamp(gap, size.height - childSize.height - gap),
    );
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor ||
        side != oldDelegate.side ||
        gap != oldDelegate.gap;
  }
}
