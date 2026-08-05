import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart';

@immutable
class UiDataColumn {
  const UiDataColumn({
    required this.label,
    this.numeric = false,
    this.flex = 1,
    this.alignment,
  });

  final String label;
  final bool numeric;
  final int flex;
  final AlignmentGeometry? alignment;

  AlignmentGeometry get resolvedAlignment =>
      alignment ??
      (numeric
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart);

  TextAlign get resolvedTextAlign {
    if (alignment == Alignment.center ||
        alignment == AlignmentDirectional.center) {
      return TextAlign.center;
    }
    return numeric ? TextAlign.right : TextAlign.left;
  }
}

@immutable
class UiDataRow {
  const UiDataRow({
    required this.cells,
    this.selected = false,
    this.onTap,
  });

  final List<Widget> cells;
  final bool selected;
  final VoidCallback? onTap;
}

typedef UiDataRowBuilder = UiDataRow Function(BuildContext context, int index);

class UiDataTable extends StatelessWidget {
  const UiDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.loading = false,
    this.errorText,
    this.onRetry,
    this.emptyText = 'No records yet.',
    this.lazyRowThreshold = 50,
    this.maxBodyHeight = 360,
    this.rowExtent = 44,
    this.scrollable = true,
  })  : rowCount = null,
        rowBuilder = null;

  const UiDataTable.lazy({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.rowBuilder,
    this.loading = false,
    this.errorText,
    this.onRetry,
    this.emptyText = 'No records yet.',
    this.maxBodyHeight = 360,
    this.rowExtent = 44,
    this.scrollable = true,
  })  : rows = const [],
        lazyRowThreshold = 0;

  final List<UiDataColumn> columns;
  final List<UiDataRow> rows;
  final int? rowCount;
  final UiDataRowBuilder? rowBuilder;
  final bool loading;
  final String? errorText;
  final VoidCallback? onRetry;
  final String emptyText;
  final int lazyRowThreshold;
  final double maxBodyHeight;
  final double rowExtent;

  /// Whether the table body owns a height-capped vertical scroll view.
  ///
  /// Set this to false when the table lives inside another vertical scrollable
  /// (for example a refreshable page). The body then expands to its rows and
  /// delegates all vertical scrolling gestures to its ancestor.
  final bool scrollable;

  bool get _isLazy => rowBuilder != null;

  int get _effectiveRowCount => _isLazy ? rowCount! : rows.length;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    Widget body;
    if (loading) {
      body = Padding(
        padding: EdgeInsets.all(tokens.spacing.x4),
        child: const UiText('Loading table…', variant: UiTextVariant.body),
      );
    } else if (hasError) {
      body = Padding(
        padding: EdgeInsets.all(tokens.spacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UiText(
              errorText!,
              variant: UiTextVariant.body,
              tone: UiTextTone.danger,
            ),
            if (onRetry != null) ...[
              SizedBox(height: tokens.spacing.x2),
              UiButton(
                label: 'Retry',
                intent: UiIntent.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      );
    } else if (_effectiveRowCount == 0) {
      body = Padding(
        padding: EdgeInsets.all(tokens.spacing.x4),
        child: UiText(
          emptyText,
          variant: UiTextVariant.body,
          tone: UiTextTone.muted,
        ),
      );
    } else if (_isLazy || rows.length > lazyRowThreshold) {
      body = _LazyRowsTableBody(
        columns: columns,
        rows: rows,
        rowCount: _effectiveRowCount,
        rowBuilder: rowBuilder,
        maxBodyHeight: maxBodyHeight,
        rowExtent: rowExtent,
        scrollable: scrollable,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRow(columns: columns),
          for (var i = 0; i < rows.length; i++)
            _DataRow(
              columns: columns,
              row: rows[i],
              showTopBorder: i > 0,
            ),
        ],
      );
    }

    return UiBox(
      background: c.card,
      border: Border.all(color: c.border),
      borderRadius: tokens.radius.lgAll,
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: tokens.radius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

class _LazyRowsTableBody extends StatelessWidget {
  const _LazyRowsTableBody({
    required this.columns,
    required this.rows,
    required this.rowCount,
    required this.rowBuilder,
    required this.maxBodyHeight,
    required this.rowExtent,
    required this.scrollable,
  });

  final List<UiDataColumn> columns;
  final List<UiDataRow> rows;
  final int rowCount;
  final UiDataRowBuilder? rowBuilder;
  final double maxBodyHeight;
  final double rowExtent;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final bodyHeight = math.min(maxBodyHeight, rowCount * rowExtent);
    final rowsList = ListView.builder(
      primary: false,
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemExtent: rowExtent,
      itemCount: rowCount,
      itemBuilder: (context, i) {
        final row = rowBuilder?.call(context, i) ?? rows[i];
        return _DataRow(
          columns: columns,
          row: row,
          showTopBorder: i > 0,
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(columns: columns),
        if (scrollable)
          SizedBox(height: bodyHeight, child: rowsList)
        else
          rowsList,
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns});

  final List<UiDataColumn> columns;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);

    final c = tokens.colors;

    return UiBox(
      background: const Color(0x00000000),
      border: Border(bottom: BorderSide(color: c.border)),
      borderRadius: BorderRadius.only(
        topLeft: tokens.radius.lg,
        topRight: tokens.radius.lg,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x3,
        vertical: tokens.spacing.x3,
      ),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: column.flex,
              child: Align(
                alignment: column.resolvedAlignment,
                child: UiText(
                  column.label,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                  textAlign: column.resolvedTextAlign,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.columns,
    required this.row,
    required this.showTopBorder,
  });

  final List<UiDataColumn> columns;
  final UiDataRow row;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      enabled: row.onTap != null,
      onPressed: row.onTap,
      minTapSize: 0,
      excludeFromSemantics: row.onTap == null,
      builder: (context, state, _) {
        final background = row.selected
            ? c.primary.withValues(alpha: 0.08)
            : state.hovered || state.pressed
                ? c.accent
                : c.card;

        return UiBox(
          background: background,
          border:
              showTopBorder ? Border(top: BorderSide(color: c.border)) : null,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x3,
            vertical: tokens.spacing.x2,
          ),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: columns[i].flex,
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: Align(
                      alignment: columns[i].resolvedAlignment,
                      child: row.cells[i],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
