import 'package:flutter/material.dart';

import '../../components/data_display/card.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Grouped settings/action list pattern.
///
/// This is the Open UI Kit equivalent of a common app settings screen: labelled
/// groups, tappable rows, selected state for split-view layouts, optional
/// footers, and trailing metadata or controls.
class UiSettingsList extends StatelessWidget {
  const UiSettingsList({
    super.key,
    required this.groups,
    this.selectedItemId,
    this.onItemSelected,
    this.spacing,
  });

  final List<UiSettingsGroup> groups;
  final String? selectedItemId;
  final ValueChanged<String>? onItemSelected;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? UiThemeTokens.of(context).spacing.x5;
    final children = <Widget>[];

    for (var i = 0; i < groups.length; i += 1) {
      if (i > 0) children.add(SizedBox(height: gap));
      children.add(
        _SettingsGroupView(
          group: groups[i],
          selectedItemId: selectedItemId,
          onItemSelected: onItemSelected,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

@immutable
class UiSettingsGroup {
  const UiSettingsGroup({
    required this.items,
    this.title,
    this.footer,
  });

  final String? title;
  final String? footer;
  final List<UiSettingsItem> items;
}

@immutable
class UiSettingsItem {
  const UiSettingsItem({
    required this.label,
    this.id,
    this.description,
    this.leading,
    this.selected,
    this.showSelectedOnPhone = false,
    this.trailing,
    this.trailingLabel,
    this.actions = const <Widget>[],
    this.onPressed,
  });

  /// Stable selection id. When omitted, the item is not selected by
  /// [UiSettingsList.selectedItemId], but can still use [selected].
  final String? id;
  final String label;
  final String? description;
  final Widget? leading;
  final bool? selected;
  final bool showSelectedOnPhone;
  final Widget? trailing;
  final String? trailingLabel;
  final List<Widget> actions;
  final VoidCallback? onPressed;
}

class _SettingsGroupView extends StatelessWidget {
  const _SettingsGroupView({
    required this.group,
    required this.selectedItemId,
    required this.onItemSelected,
  });

  final UiSettingsGroup group;
  final String? selectedItemId;
  final ValueChanged<String>? onItemSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.title != null) ...[
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: tokens.spacing.x2,
              bottom: tokens.spacing.x2,
            ),
            child: UiText(
              group.title!.toUpperCase(),
              variant: UiTextVariant.caption,
              tone: UiTextTone.muted,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        for (var i = 0; i < group.items.length; i += 1) ...[
          if (i > 0) SizedBox(height: tokens.spacing.x2),
          _SettingsItemRow(
            item: group.items[i],
            selected: _selected(group.items[i]),
            onPressed: _onPressed(group.items[i]),
          ),
        ],
        if (group.footer != null) ...[
          SizedBox(height: tokens.spacing.x2),
          Padding(
            padding: EdgeInsetsDirectional.only(start: tokens.spacing.x2),
            child: UiText(
              group.footer!,
              variant: UiTextVariant.caption,
              tone: UiTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }

  bool _selected(UiSettingsItem item) {
    return item.selected ?? (item.id != null && item.id == selectedItemId);
  }

  VoidCallback? _onPressed(UiSettingsItem item) {
    if (item.onPressed != null) return item.onPressed;
    if (item.id == null || onItemSelected == null) return null;
    return () => onItemSelected!(item.id!);
  }
}

class _SettingsItemRow extends StatelessWidget {
  const _SettingsItemRow({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final UiSettingsItem item;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final formFactor = uiFormFactorOf(context);
    final effectiveSelected = selected &&
        (item.showSelectedOnPhone || formFactor != UiFormFactor.phone);

    return UiCard(
      variant:
          effectiveSelected ? UiCardVariant.standard : UiCardVariant.outlined,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x4,
        vertical: tokens.spacing.x3,
      ),
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: item.description == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (item.leading != null) ...[
                UiBox(
                  width: 36,
                  height: 36,
                  background: effectiveSelected
                      ? tokens.colors.primary
                      : tokens.colors.surfaceMuted,
                  borderRadius: tokens.radius.mdAll,
                  alignment: Alignment.center,
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: effectiveSelected
                          ? tokens.colors.onPrimary
                          : tokens.colors.textPrimary,
                      size: 20,
                    ),
                    child: item.leading!,
                  ),
                ),
                SizedBox(width: tokens.spacing.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      item.label,
                      variant: item.description == null
                          ? UiTextVariant.label
                          : UiTextVariant.subheading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null) ...[
                      SizedBox(height: tokens.spacing.x1),
                      UiText(
                        item.description!,
                        variant: UiTextVariant.bodySm,
                        tone: UiTextTone.muted,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.trailingLabel != null) ...[
                SizedBox(width: tokens.spacing.x2),
                UiText(
                  item.trailingLabel!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                ),
              ],
              SizedBox(width: tokens.spacing.x2),
              item.trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: tokens.colors.textMuted,
                  ),
            ],
          ),
          if (item.actions.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.x4),
            ..._spacedActions(tokens.spacing.x3),
          ],
        ],
      ),
    );
  }

  List<Widget> _spacedActions(double gap) {
    final children = <Widget>[];
    for (var i = 0; i < item.actions.length; i += 1) {
      if (i > 0) children.add(SizedBox(height: gap));
      children.add(item.actions[i]);
    }
    return children;
  }
}
