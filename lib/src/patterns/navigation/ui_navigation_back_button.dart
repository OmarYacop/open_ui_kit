import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../components/forms/button.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../components/forms/icon_button.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../components/menu/ui_menu_anchor.dart';
import '../../components/menu/ui_dropdown_menu.dart';
import 'ui_navigation_scope.dart';
import 'ui_navigator_history.dart';
import 'ui_route_entry.dart';

@immutable
class UiNavigationBackHistoryItem {
  const UiNavigationBackHistoryItem({
    required this.title,
    this.subtitle,
    this.value,
  });

  final String title;
  final String? subtitle;
  final Object? value;
}

@immutable
class UiNavigationBackPopTarget {
  const UiNavigationBackPopTarget(this.count, {this.route})
    : assert(count > 0, 'count must be greater than zero');

  final int count;

  /// Stable destination for observer-generated history.
  final Route<dynamic>? route;
}

/// iOS-style back affordance: a chevron, with [label] kept for
/// accessibility and the title of the long-press history menu
/// even when it isn't painted. Set [showLabel] to restore the previous
/// chevron-plus-title look for apps that still want it.
///
/// The long-press history menu works out of the box: with no explicit
/// [history], the button lists the routes behind the current page from the
/// enclosing [UiNavigationControllerScope] or [UiNavigatorHistoryScope]
/// (which [UiApp] installs), and picking an entry pops back to it. That is
/// the same behaviour [UiSliverNavigationBar] provides, so custom chrome
/// such as [UiChatHeader] can drop this button into its leading slot and
/// stay part of the stack without any extra wiring.
class UiNavigationBackButton extends StatefulWidget {
  const UiNavigationBackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showLabel = false,
    this.history,
    this.onHistorySelected,
  });

  final String label;
  final VoidCallback onPressed;

  /// Whether [label] is painted next to the chevron. Defaults to `false`
  /// (iOS-style chevron-only), leaving more room for the title and
  /// trailing actions. [label] still drives the semantics announcement and
  /// the history menu title either way; it never creates a destination.
  final bool showLabel;

  /// Entries behind the current page, newest first, for the long-press
  /// menu. `null` (the default) resolves them with [historyOf]; pass an
  /// empty list to opt out of the menu entirely.
  final List<UiNavigationBackHistoryItem>? history;

  /// Called when a history entry is picked. `null` (the default) pops back
  /// to that entry with [popToHistoryItem], falling back to [onPressed] for
  /// entries the kit cannot navigate to itself.
  final ValueChanged<UiNavigationBackHistoryItem>? onHistorySelected;

  /// The routes behind the page enclosing [context], newest first — the
  /// shape the long-press menu wants. Prefers a [UiNavigationController]
  /// runtime, then [UiApp]'s plain-`Navigator` history observer; empty when
  /// neither is present or nothing is behind the current route.
  static List<UiNavigationBackHistoryItem> historyOf(BuildContext context) {
    final runtime = UiNavigationControllerScope.maybeOf(context);
    if (runtime != null) return runtime.controller.historyItems();
    return UiNavigatorHistoryScope.maybeOf(context)
            ?.historyItems(currentRoute: ModalRoute.of(context)) ??
        const <UiNavigationBackHistoryItem>[];
  }

  /// Pops back to the page [item] describes. A [UiRouteEntry] value pops the
  /// enclosing [UiNavigationController]; a [UiNavigationBackPopTarget] pops
  /// the enclosing [Navigator] one `maybePop` at a time, so every page's
  /// `PopScope` still gets a say, and stops as soon as a guarded page
  /// refuses. Any other value invokes [orElse] instead.
  static Future<void> popToHistoryItem(
    BuildContext context,
    UiNavigationBackHistoryItem item, {
    VoidCallback? orElse,
  }) async {
    final value = item.value;
    final controller = UiNavigationControllerScope.maybeOf(context)?.controller;
    if (controller != null && value is UiRouteEntry) {
      controller.popTo(value);
      return;
    }
    if (value is UiNavigationBackPopTarget) {
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) return;
      final destination = value.route;
      if (destination == null) {
        await _popNavigatorTimes(navigator, value.count);
        return;
      }
      if (!destination.isActive || destination.navigator != navigator) return;
      await _popNavigatorTo(navigator, destination);
      return;
    }
    orElse?.call();
  }

  @override
  State<UiNavigationBackButton> createState() => _UiNavigationBackButtonState();
}

Future<void> _popNavigatorTo(
  NavigatorState navigator,
  Route<dynamic> target,
) async {
  while (navigator.mounted && target.isActive && !target.isCurrent) {
    // maybePop reports success even when a PopScope vetoes the pop, so
    // stop as soon as the top of the stack fails to change.
    Route<dynamic>? top;
    navigator.popUntil((route) {
      top = route;
      return true;
    });
    if (!await navigator.maybePop() || top?.isCurrent == true) return;
  }
}

Future<void> _popNavigatorTimes(NavigatorState navigator, int count) async {
  for (var i = 0; i < count; i++) {
    if (!await navigator.maybePop()) return;
  }
}

class _UiNavigationBackButtonState extends State<UiNavigationBackButton> {
  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final history = widget.history ?? UiNavigationBackButton.historyOf(context);
    return UiMenuAnchor(
      title: widget.label,
      openOnLongPress: history.isNotEmpty,
      onTriggerPressed: widget.onPressed,
      items: [
        for (final item in history)
          UiMenuItem(
            label: item.title,
            subtitle: item.subtitle,
            onPressed: () {
              final custom = widget.onHistorySelected;
              if (custom != null) {
                custom(item);
                return;
              }
              unawaited(
                UiNavigationBackButton.popToHistoryItem(
                  context,
                  item,
                  orElse: widget.onPressed,
                ),
              );
            },
          ),
      ],
      triggerBuilder: (context, activate) {
        // Chevron stroke mass sits toward its point; a small directional
        // correction balances the painted glyph rather than its font box.
        final icon = Transform.translate(
          offset: Offset(
            Directionality.of(context) == TextDirection.rtl ? 1 : -1,
            0,
          ),
          child: Icon(
            UiDirectionalIcons.chevronBack(context),
            size: 32,
            applyTextScaling: false,
          ),
        );
        if (widget.showLabel) {
          return UiPressable(
            semanticsLabel: widget.label,
            minTapSize: 44,
            onPressed: activate,
            builder: (context, state, child) => UiFocusRing(
              visible: state.focused,
              borderRadius: tokens.radius.pillAll,
              child: UiBox(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x2),
                background: state.pressed
                    ? tokens.colors.surfaceMuted
                    : tokens.colors.surface,
                borderRadius: tokens.radius.pillAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    SizedBox(width: tokens.spacing.x1),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: tokens.typography.subheading.copyWith(
                          color: tokens.colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return UiIconButton(
          icon: icon,
          semanticsLabel: widget.label,
          size: UiSize.md,
          borderRadius: tokens.radius.pillAll,
          backgroundColor: tokens.colors.surface.withValues(
            alpha: tokens.menu.surfaceOpacity,
          ),
          borderColor: tokens.colors.textPrimary.withValues(
            alpha: tokens.menu.borderOpacity,
          ),
          borderWidth: tokens.menu.borderWidth,
          foregroundColor: tokens.colors.textPrimary,
          onPressed: activate,
        );
      },
    );
  }
}
