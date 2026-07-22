import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../surfaces/ui_drawer.dart';
import 'ui_navigation_badge.dart';

/// Selectable destination rendered by [UiNavigationDrawer].
class UiNavigationDrawerDestination {
  const UiNavigationDrawerDestination({
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.badge,
    this.badgeCount,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? badge;
  final int? badgeCount;
}

/// Non-selectable command rendered by [UiNavigationDrawer].
class UiNavigationDrawerAction {
  const UiNavigationDrawerAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.badgeCount,
  });

  final String label;
  final Widget? icon;
  final VoidCallback onPressed;
  final Widget? badge;
  final int? badgeCount;
}

/// Navigation-specific drawer composition with the same region model as
/// [UiNavigationRail]: primary destinations in the body and persistent
/// actions/destinations in the footer.
class UiNavigationDrawer extends StatelessWidget {
  const UiNavigationDrawer({
    super.key,
    required this.title,
    required this.destinations,
    this.description,
    this.headerLeading,
    this.headerAction,
    this.actions = const <UiNavigationDrawerAction>[],
    this.footerActions = const <Object>[],
    this.footerDestinations = const <UiNavigationDrawerDestination>[],
    this.side = UiDrawerSide.start,
    this.variant = UiDrawerVariant.standard,
    this.width = 320,
    this.semanticsLabel,
  });

  final String title;
  final String? description;
  final Widget? headerLeading;
  final Widget? headerAction;
  final List<UiNavigationDrawerAction> actions;
  final List<UiNavigationDrawerDestination> destinations;

  /// Widgets or drawer item configs rendered in the persistent footer area.
  ///
  /// Supported entries are:
  /// - [Widget], rendered directly for custom controls.
  /// - [UiNavigationDrawerAction], rendered with navigation drawer row chrome.
  /// - [UiNavigationDrawerDestination], rendered like [footerDestinations].
  final List<Object> footerActions;

  final List<UiNavigationDrawerDestination> footerDestinations;
  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final double width;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final hasFooter = footerActions.isNotEmpty || footerDestinations.isNotEmpty;
    final itemRadius = UiDrawer.concentricContentBorderRadiusOf(
      context,
      side: side,
      variant: variant,
      inset: UiThemeTokens.of(context).spacing.x2,
    );

    return UiDrawer(
      side: side,
      variant: variant,
      width: width,
      semanticsLabel: semanticsLabel,
      header: UiDrawerHeader(
        title: title,
        description: description,
        leading: headerLeading,
        action: headerAction,
      ),
      body: UiDrawerSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions)
              _NavigationDrawerRow(
                label: action.label,
                icon: action.icon,
                badge: action.badge ?? _badgeFor(action.badgeCount),
                onPressed: action.onPressed,
                borderRadius: itemRadius,
              ),
            for (final destination in destinations)
              _NavigationDrawerRow(
                label: destination.label,
                icon: destination.icon,
                badge: destination.badge ?? _badgeFor(destination.badgeCount),
                selected: destination.selected,
                onPressed: destination.onPressed,
                borderRadius: itemRadius,
              ),
          ],
        ),
      ),
      footer: hasFooter
          ? UiDrawerFooter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in footerActions)
                    _footerItemFor(item, itemRadius),
                  for (final destination in footerDestinations)
                    _NavigationDrawerRow(
                      label: destination.label,
                      icon: destination.icon,
                      badge: destination.badge ??
                          _badgeFor(destination.badgeCount),
                      selected: destination.selected,
                      onPressed: destination.onPressed,
                      borderRadius: itemRadius,
                    ),
                ],
              ),
            )
          : null,
    );
  }

  Widget? _badgeFor(int? count) =>
      count == null || count <= 0 ? null : UiNavigationCountBadge(count: count);

  Widget _footerItemFor(Object item, BorderRadius borderRadius) {
    return switch (item) {
      UiNavigationDrawerAction action => _NavigationDrawerRow(
          label: action.label,
          icon: action.icon,
          badge: action.badge ?? _badgeFor(action.badgeCount),
          onPressed: action.onPressed,
          borderRadius: borderRadius,
        ),
      UiNavigationDrawerDestination destination => _NavigationDrawerRow(
          label: destination.label,
          icon: destination.icon,
          badge: destination.badge ?? _badgeFor(destination.badgeCount),
          selected: destination.selected,
          onPressed: destination.onPressed,
          borderRadius: borderRadius,
        ),
      Widget widget => widget,
      _ => throw ArgumentError.value(
          item,
          'footerActions',
          'Expected a Widget, UiNavigationDrawerAction, or '
              'UiNavigationDrawerDestination.',
        ),
    };
  }
}

class _NavigationDrawerRow extends StatelessWidget {
  const _NavigationDrawerRow({
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.selected = false,
    required this.borderRadius,
  });

  final String label;
  final Widget? icon;
  final Widget? badge;
  final bool selected;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.x1),
      child: UiPressable(
        onPressed: onPressed,
        semanticsLabel: label,
        minTapSize: 44,
        builder: (context, state, _) {
          final background = selected
              ? colors.surfaceMuted
              : state.hovered || state.pressed
                  ? colors.surfaceMuted.withValues(alpha: 0.5)
                  : const Color(0x00000000);

          return UiFocusRing(
            visible: state.focused,
            borderRadius: borderRadius,
            child: UiBox(
              background: background,
              borderRadius: borderRadius,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.x4,
                vertical: tokens.spacing.x2,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    SizedBox.square(
                      dimension: 22,
                      child: Center(
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 19,
                            color: colors.textPrimary,
                          ),
                          child: icon!,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.x3),
                  ],
                  Expanded(
                    child: UiText(
                      label,
                      variant: UiTextVariant.body,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    SizedBox(width: tokens.spacing.x2),
                    badge!,
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
