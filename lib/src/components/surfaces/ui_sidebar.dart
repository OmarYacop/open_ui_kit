import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Shared node contract for sidebar children.
sealed class UiSidebarNode {
  const UiSidebarNode();
}

/// Clickable sidebar row.
class UiSidebarItem extends UiSidebarNode {
  const UiSidebarItem({
    required this.label,
    required this.onPressed,
    this.icon,
    this.active = false,
    this.badge,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final bool active;

  /// Optional trailing chip (badge count, shortcut label, etc.).
  final Widget? badge;
}

/// Labelled cluster of items; renders an optional caption above rows.
class UiSidebarGroup extends UiSidebarNode {
  const UiSidebarGroup({this.label, required this.items});
  final String? label;
  final List<UiSidebarItem> items;
}

/// Static section with an optional header + arbitrary body widget.
class UiSidebarSection extends UiSidebarNode {
  const UiSidebarSection({this.title, required this.child});
  final String? title;
  final Widget child;
}

/// Horizontal separator between groups/sections.
class UiSidebarSeparator extends UiSidebarNode {
  const UiSidebarSeparator();
}

/// Persistent navigation surface for tablet/desktop layouts.
///
/// Supports two modes:
/// - **expanded** (default): icon + label per row.
/// - **rail** (`collapsed: true`): icon-only, label suppressed.
class UiSidebar extends StatelessWidget {
  const UiSidebar({
    super.key,
    required this.items,
    this.header,
    this.footer,
    this.collapsed = false,
    this.width = 240,
    this.railWidth = 72,
    this.backgroundColor,
  });

  final List<UiSidebarNode> items;
  final Widget? header;
  final Widget? footer;
  final bool collapsed;
  final double width;
  final double railWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return AnimatedContainer(
      duration: tokens.motion.standard,
      curve: tokens.motion.standardCurve,
      width: collapsed ? railWidth : width,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) header!,
          if (header != null) const UiDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.x2,
                vertical: tokens.spacing.x2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in items) _buildNode(context, n),
                ],
              ),
            ),
          ),
          if (footer != null) const UiDivider(),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Widget _buildNode(BuildContext context, UiSidebarNode node) {
    final tokens = UiThemeTokens.of(context);
    switch (node) {
      case UiSidebarItem():
        return _SidebarItemRow(item: node, collapsed: collapsed);
      case UiSidebarGroup():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!collapsed && node.label != null)
              Padding(
                padding: EdgeInsets.only(
                  left: tokens.spacing.x2,
                  top: tokens.spacing.x2,
                  bottom: tokens.spacing.x1,
                ),
                child: UiText(
                  node.label!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                ),
              ),
            for (final item in node.items)
              _SidebarItemRow(item: item, collapsed: collapsed),
          ],
        );
      case UiSidebarSection():
        if (collapsed) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (node.title != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: tokens.spacing.x2,
                    bottom: tokens.spacing.x1,
                  ),
                  child: UiText(
                    node.title!,
                    variant: UiTextVariant.caption,
                    tone: UiTextTone.muted,
                  ),
                ),
              node.child,
            ],
          ),
        );
      case UiSidebarSeparator():
        return Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.x2),
          child: const UiDivider(),
        );
    }
  }
}

class _SidebarItemRow extends StatelessWidget {
  const _SidebarItemRow({required this.item, required this.collapsed});

  final UiSidebarItem item;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    const iconSize = 18.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.x1 / 2),
      child: UiPressable(
        onPressed: item.onPressed,
        minTapSize: 0,
        semanticsLabel: item.label,
        builder: (context, state, _) {
          final background = item.active
              ? c.surfaceMuted
              : state.hovered || state.pressed
                  ? c.surfaceMuted.withValues(alpha: 0.5)
                  : const Color(0x00000000);
          final fg = c.textPrimary;
          return UiFocusRing(
            visible: state.focused,
            borderRadius: tokens.radius.mdAll,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = tokens.spacing.x3 * 2;
                final gap = tokens.spacing.x3;
                final minLabelWidth = tokens.spacing.x4;
                final availableLabelWidth =
                    constraints.maxWidth - horizontalPadding - iconSize - gap;
                final showLabel =
                    !collapsed || availableLabelWidth > minLabelWidth;
                final iconWidget =
                    item.icon ?? _SidebarFallbackIcon(item.label);

                return UiBox(
                  background: background,
                  borderRadius: tokens.radius.mdAll,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.x3,
                    vertical: tokens.spacing.x2,
                  ),
                  child: Row(
                    mainAxisAlignment: showLabel
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(color: fg, size: iconSize),
                        child: iconWidget,
                      ),
                      if (showLabel) ...[
                        SizedBox(width: tokens.spacing.x3),
                        Expanded(
                          child: UiText(
                            item.label,
                            variant: UiTextVariant.body,
                            style: TextStyle(
                              fontWeight: item.active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: fg,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.badge != null) ...[
                          SizedBox(width: tokens.spacing.x2),
                          item.badge!,
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SidebarFallbackIcon extends StatelessWidget {
  const _SidebarFallbackIcon(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final trimmed = label.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return UiBox(
      background: tokens.colors.surfaceMuted,
      borderRadius: tokens.radius.smAll,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: UiText(
        initial.toUpperCase(),
        variant: UiTextVariant.caption,
        style: TextStyle(
          color: tokens.colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }
}
