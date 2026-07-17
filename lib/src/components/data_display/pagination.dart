import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

class UiPagination extends StatelessWidget {
  const UiPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPageChanged,
    this.maxVisiblePages = 5,
    this.loading = false,
  })  : assert(currentPage >= 1),
        assert(totalPages >= 1),
        assert(maxVisiblePages >= 3);

  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageChanged;
  final int maxVisiblePages;
  final bool loading;

  bool get _interactive => onPageChanged != null && !loading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final strings = UiLocalizations.of(context);
    final pages = _visiblePages();
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    return Wrap(
      spacing: tokens.spacing.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PaginationChip(
          label: strings.previous,
          semanticsLabel: strings.previous,
          enabled: _interactive && canPrev,
          onPressed: () => onPageChanged?.call(currentPage - 1),
        ),
        for (final page in pages)
          _PaginationChip(
            label: '$page',
            semanticsLabel: strings.pageSemanticsLabel(page),
            selected: page == currentPage,
            enabled: _interactive,
            onPressed: () => onPageChanged?.call(page),
          ),
        _PaginationChip(
          label: strings.next,
          semanticsLabel: strings.next,
          enabled: _interactive && canNext,
          onPressed: () => onPageChanged?.call(currentPage + 1),
        ),
        if (loading)
          Padding(
            // Directional so the loading caption sits on the reading-
            // direction "end" of the controls in both LTR and RTL.
            padding: EdgeInsetsDirectional.only(start: tokens.spacing.x1),
            child: UiText(strings.loading, variant: UiTextVariant.caption),
          ),
      ],
    );
  }

  List<int> _visiblePages() {
    if (totalPages <= maxVisiblePages) {
      return List<int>.generate(totalPages, (i) => i + 1);
    }

    final half = maxVisiblePages ~/ 2;
    var start = currentPage - half;
    var end = currentPage + half;

    if (start < 1) {
      start = 1;
      end = maxVisiblePages;
    }
    if (end > totalPages) {
      end = totalPages;
      start = totalPages - maxVisiblePages + 1;
    }

    return List<int>.generate(end - start + 1, (i) => start + i);
  }
}

class _PaginationChip extends StatelessWidget {
  const _PaginationChip({
    required this.label,
    required this.semanticsLabel,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final String semanticsLabel;
  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      enabled: enabled,
      onPressed: onPressed,
      minTapSize: 36,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: true,
      builder: (context, state, _) {
        final background = selected
            ? c.primary
            : state.hovered || state.pressed
                ? c.surfaceMuted
                : c.surface;
        final fg = selected ? c.onPrimary : c.textPrimary;

        return Semantics(
          button: true,
          selected: selected,
          enabled: enabled,
          label: semanticsLabel,
          child: UiBox(
            background: background,
            border: Border.all(color: c.border),
            borderRadius: tokens.radius.mdAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x3,
              vertical: tokens.spacing.x1,
            ),
            child: UiText(
              label,
              variant: UiTextVariant.label,
              style: TextStyle(color: fg),
            ),
          ),
        );
      },
    );
  }
}
