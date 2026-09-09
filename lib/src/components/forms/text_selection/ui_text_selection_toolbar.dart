import 'package:flutter/widgets.dart';

import '../../../foundation/intl/ui_localizations.dart';
import '../../../foundation/primitives/ui_pressable.dart';
import '../../../foundation/theme/ui_theme_extensions.dart';

/// Widgets-layer port of Flutter's Material text selection toolbar: the
/// floating pill with text actions that Android users expect after a long
/// press. iOS uses [SystemContextMenu]; this covers every platform where the
/// system menu is unavailable without pulling Material into the kit.
class UiTextSelectionToolbar extends StatelessWidget {
  const UiTextSelectionToolbar({
    super.key,
    required this.anchorAbove,
    required this.anchorBelow,
    required this.buttonItems,
  });

  /// Builds the toolbar for [editableTextState]'s current selection.
  UiTextSelectionToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  }) : anchorAbove = editableTextState.contextMenuAnchors.primaryAnchor,
       anchorBelow =
           editableTextState.contextMenuAnchors.secondaryAnchor ??
           editableTextState.contextMenuAnchors.primaryAnchor,
       buttonItems = editableTextState.contextMenuButtonItems;

  final Offset anchorAbove;
  final Offset anchorBelow;
  final List<ContextMenuButtonItem> buttonItems;

  // Metrics match Flutter's Material toolbar (eyeballed by the framework
  // against a Pixel running API 34).
  static const double toolbarHeight = 44;
  static const double _contentDistanceAbove = 8;
  static const double _contentDistanceBelow = 22 - 2; // handle size - 2
  static const double _screenPadding = 8;
  static const double _endPadding = 14.5;
  static const double _middlePadding = 9.5;

  /// Label for [item], preferring an explicit label over the localized
  /// default for its type.
  static String labelFor(BuildContext context, ContextMenuButtonItem item) =>
      item.label ?? UiLocalizations.of(context).textSelectionAction(item.type);

  @override
  Widget build(BuildContext context) {
    if (buttonItems.isEmpty) return const SizedBox.shrink();
    final anchorAbovePadded =
        anchorAbove - const Offset(0, _contentDistanceAbove);
    final anchorBelowPadded =
        anchorBelow + const Offset(0, _contentDistanceBelow);
    final paddingAbove = MediaQuery.paddingOf(context).top + _screenPadding;
    final availableHeight =
        anchorAbovePadded.dy - _contentDistanceAbove - paddingAbove;
    final fitsAbove = toolbarHeight <= availableHeight;
    final localAdjustment = Offset(_screenPadding, paddingAbove);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _screenPadding,
        paddingAbove,
        _screenPadding,
        _screenPadding,
      ),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: anchorAbovePadded - localAdjustment,
          anchorBelow: anchorBelowPadded - localAdjustment,
          fitsAbove: fitsAbove,
        ),
        child: _UiTextSelectionToolbarSurface(
          children: [
            for (var i = 0; i < buttonItems.length; i++)
              _UiTextSelectionToolbarButton(
                label: labelFor(context, buttonItems[i]),
                onPressed: buttonItems[i].onPressed,
                padding: EdgeInsetsDirectional.only(
                  start: i == 0 ? _endPadding : _middlePadding,
                  end: i == buttonItems.length - 1
                      ? _endPadding
                      : _middlePadding,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UiTextSelectionToolbarSurface extends StatelessWidget {
  const _UiTextSelectionToolbarSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.card,
        borderRadius: const BorderRadius.all(
          Radius.circular(UiTextSelectionToolbar.toolbarHeight / 2),
        ),
        boxShadow: tokens.shadows.sm,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(UiTextSelectionToolbar.toolbarHeight / 2),
        ),
        child: SizedBox(
          height: UiTextSelectionToolbar.toolbarHeight,
          // Actions that do not fit scroll horizontally rather than wrapping
          // into a second row, keeping the single-row native silhouette.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _UiTextSelectionToolbarButton extends StatelessWidget {
  const _UiTextSelectionToolbarButton({
    required this.label,
    required this.onPressed,
    required this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: onPressed,
      minTapSize: UiTextSelectionToolbar.toolbarHeight,
      child: Padding(
        padding: padding,
        child: Text(
          label,
          style: tokens.typography.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: tokens.colors.textPrimary,
          ),
        ),
      ),
      builder: (context, state, child) => ColoredBox(
        color: state.pressed || state.hovered
            ? tokens.colors.surfaceMuted
            : const Color(0x00000000),
        child: SizedBox(
          height: UiTextSelectionToolbar.toolbarHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}
