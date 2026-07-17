import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../surfaces/ui_drawer.dart';

/// Selectable destination rendered by [UiNavigationDrawer].
class UiNavigationDrawerDestination {
  const UiNavigationDrawerDestination({
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.badge,
  });

  final String label;
  final Widget? icon;
  final bool selected;
  final VoidCallback onPressed;
  final Widget? badge;
}

/// Non-selectable command rendered by [UiNavigationDrawer].
class UiNavigationDrawerAction {
  const UiNavigationDrawerAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
  });

  final String label;
  final Widget? icon;
  final VoidCallback onPressed;
  final Widget? badge;
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
    this.footerActions = const <UiNavigationDrawerAction>[],
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
  final List<UiNavigationDrawerAction> footerActions;
  final List<UiNavigationDrawerDestination> footerDestinations;
  final UiDrawerSide side;
  final UiDrawerVariant variant;
  final double width;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final hasFooter = footerActions.isNotEmpty || footerDestinations.isNotEmpty;

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
                badge: action.badge,
                onPressed: action.onPressed,
              ),
            for (final destination in destinations)
              _NavigationDrawerRow(
                label: destination.label,
                icon: destination.icon,
                badge: destination.badge,
                selected: destination.selected,
                onPressed: destination.onPressed,
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
                  for (final action in footerActions)
                    _NavigationDrawerRow(
                      label: action.label,
                      icon: action.icon,
                      badge: action.badge,
                      onPressed: action.onPressed,
                    ),
                  for (final destination in footerDestinations)
                    _NavigationDrawerRow(
                      label: destination.label,
                      icon: destination.icon,
                      badge: destination.badge,
                      selected: destination.selected,
                      onPressed: destination.onPressed,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

class _NavigationDrawerRow extends StatelessWidget {
  const _NavigationDrawerRow({
    required this.label,
    required this.onPressed,
    this.icon,
    this.badge,
    this.selected = false,
  });

  final String label;
  final Widget? icon;
  final Widget? badge;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.x1 / 2),
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
            borderRadius: tokens.radius.mdAll,
            child: UiBox(
              background: background,
              borderRadius: tokens.radius.mdAll,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.x3,
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
