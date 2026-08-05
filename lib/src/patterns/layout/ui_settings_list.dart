import 'package:flutter/widgets.dart';

import '../../components/data_display/card.dart';
import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_divider.dart';
import '../../foundation/primitives/ui_pressable.dart';
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
    final gap = spacing ?? UiThemeTokens.spacingOf(context).x5;
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
    this.key,
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

  final Key? key;

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
    final formFactor = uiFormFactorOf(context);

    bool visuallySelected(UiSettingsItem item) =>
        _selected(item) &&
        (item.showSelectedOnPhone || formFactor != UiFormFactor.phone);

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
              group.title!,
              variant: UiTextVariant.label,
              tone: UiTextTone.muted,
            ),
          ),
        ],
        UiCard(
          variant: UiCardVariant.standard,
          padding: EdgeInsets.zero,
          borderRadius: tokens.radius.lgAll,
          child: ClipRRect(
            borderRadius: tokens.radius.lgAll,
            child: Column(
              children: [
                for (var i = 0; i < group.items.length; i += 1) ...[
                  if (i > 0)
                    if (visuallySelected(group.items[i - 1]) ||
                        visuallySelected(group.items[i]))
                      ColoredBox(
                        key: ValueKey('ui-settings-selected-separator-$i'),
                        color: tokens.colors.surfaceMuted,
                        child: const SizedBox(height: 1),
                      )
                    else
                      UiDivider(
                        indent: tokens.spacing.x4 + 36 + tokens.spacing.x3,
                      ),
                  _SettingsItemRow(
                    key: group.items[i].key,
                    item: group.items[i],
                    selected: _selected(group.items[i]),
                    onPressed: _onPressed(group.items[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    super.key,
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

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.x4,
          vertical: tokens.spacing.x3,
        ),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                      UiDirectionalIcons.chevronForward(context),
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
      ),
    );

    if (onPressed == null) return content;

    return UiPressable(
      onPressed: onPressed,
      minTapSize: 0,
      builder: (context, state, _) => UiBox(
        background: effectiveSelected || state.pressed || state.hovered
            ? tokens.colors.surfaceMuted
            : const Color(0x00000000),
        child: content,
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
