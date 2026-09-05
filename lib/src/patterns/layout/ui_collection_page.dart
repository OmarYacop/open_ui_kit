import 'package:flutter/widgets.dart';

import '../../components/feedback/async_states.dart';
import '../../components/feedback/refresher.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_page_layout.dart';
import 'ui_page_scaffold.dart';
import 'ui_safe_viewport.dart';

typedef UiCollectionItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

/// Builds a header when [item] starts a new collection section.
/// Return `null` when the item continues the current section.
typedef UiCollectionSectionBuilder<T> = Widget? Function(
  BuildContext context,
  T item,
  int index,
);

enum UiCollectionLayout { list, grid, adaptiveGrid }

/// Semantic collection page pattern.
///
/// Use this for screens whose primary job is to render a loaded collection with
/// common async states. The caller owns data/state; the kit owns page chrome,
/// empty/loading/error placement, list/grid spacing, and responsive collection
/// layout.
class UiCollectionPage<T> extends StatelessWidget {
  const UiCollectionPage({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.filters,
    this.secondary,
    this.bottomBar,
    this.loading = false,
    this.error = false,
    this.loadingTitle,
    this.emptyTitle,
    this.emptyDescription,
    this.emptyActions = const <Widget>[],
    this.errorTitle,
    this.errorDescription,
    this.errorActions = const <Widget>[],
    this.layout = UiCollectionLayout.list,
    this.padding,
    this.itemSpacing,
    this.sectionBuilder,
    this.sectionSpacing,
    this.gridMaxCrossAxisExtent = 420,
    this.gridColumnCount = 2,
    this.gridMainAxisSpacing,
    this.gridCrossAxisSpacing,
    this.gridChildAspectRatio = 1,
    this.gridMainAxisExtent,
    this.physics,
    this.onRefresh,
    this.refreshController,
    this.refreshIndicatorBuilder,
    this.safeViewportMode = UiSafeViewportMode.all,
    this.breakpoints = UiBreakpoints.standard,
  }) : assert(gridColumnCount > 0, 'gridColumnCount must be positive');

  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? filters;
  final Widget? secondary;
  final Widget? bottomBar;

  final bool loading;
  final bool error;
  final String? loadingTitle;
  final String? emptyTitle;
  final String? emptyDescription;
  final List<Widget> emptyActions;
  final String? errorTitle;
  final String? errorDescription;
  final List<Widget> errorActions;

  final UiCollectionLayout layout;
  final EdgeInsets? padding;
  final double? itemSpacing;
  final UiCollectionSectionBuilder<T>? sectionBuilder;
  final double? sectionSpacing;
  final double gridMaxCrossAxisExtent;
  final int gridColumnCount;
  final double? gridMainAxisSpacing;
  final double? gridCrossAxisSpacing;
  final double gridChildAspectRatio;

  /// Optional fixed height for grid rows. When set, this takes precedence over
  /// [gridChildAspectRatio].
  final double? gridMainAxisExtent;
  final ScrollPhysics? physics;

  /// Optional pull-to-refresh callback for the loaded collection.
  ///
  /// When supplied, [UiPageLayout] delegates refresh ownership to its
  /// [UiPageScaffold], keeping feedback above page chrome and allowing refresh
  /// even when content is shorter than the viewport.
  final Future<void> Function()? onRefresh;
  final UiRefresherController? refreshController;
  final UiRefreshIndicatorBuilder? refreshIndicatorBuilder;

  /// Safe-area policy for the generated collection page.
  ///
  /// Defaults to [UiSafeViewportMode.all].
  final UiSafeViewportMode safeViewportMode;
  final UiBreakpoints breakpoints;

  @override
  Widget build(BuildContext context) {
    return UiPageLayout(
      title: title,
      subtitle: subtitle,
      leading: leading,
      actions: actions,
      filters: filters,
      secondary: secondary,
      bottomBar: bottomBar,
      safeViewportMode: safeViewportMode,
      breakpoints: breakpoints,
      onRefresh: onRefresh,
      refreshController: refreshController,
      refreshIndicatorBuilder: refreshIndicatorBuilder,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return UiLoadingState(mode: UiAsyncStateMode.page, title: loadingTitle);
    }

    if (error) {
      return UiErrorState(
        mode: UiAsyncStateMode.page,
        title: errorTitle,
        description: errorDescription,
        actions: errorActions,
      );
    }

    if (items.isEmpty) {
      return UiEmptyState(
        mode: UiAsyncStateMode.page,
        title: emptyTitle,
        description: emptyDescription,
        actions: emptyActions,
      );
    }

    final collection = LayoutBuilder(
      builder: (context, constraints) {
        final resolvedLayout = _resolveLayout(constraints.maxWidth);
        final buildSection = sectionBuilder;
        if (buildSection != null) {
          final tokens = UiThemeTokens.of(context);
          final resolvedPadding = _withBodyInsets(
            context,
            padding ?? EdgeInsets.all(tokens.spacing.x4),
          );
          return CustomScrollView(
            physics: physics,
            slivers: [
              SliverPadding(
                padding: resolvedPadding,
                sliver: UiSliverCollection<T>(
                  items: items,
                  itemBuilder: itemBuilder,
                  sectionBuilder: buildSection,
                  layout: resolvedLayout,
                  itemSpacing: itemSpacing,
                  sectionSpacing: sectionSpacing,
                  gridColumnCount: gridColumnCount,
                  breakpoints: breakpoints,
                ),
              ),
            ],
          );
        }
        switch (resolvedLayout) {
          case UiCollectionLayout.list:
            return _CollectionList<T>(
              items: items,
              itemBuilder: itemBuilder,
              padding: padding,
              itemSpacing: itemSpacing,
              physics: physics,
            );
          case UiCollectionLayout.grid:
          case UiCollectionLayout.adaptiveGrid:
            return _CollectionGrid<T>(
              items: items,
              itemBuilder: itemBuilder,
              padding: padding,
              maxCrossAxisExtent: gridMaxCrossAxisExtent,
              mainAxisSpacing: gridMainAxisSpacing,
              crossAxisSpacing: gridCrossAxisSpacing,
              childAspectRatio: gridChildAspectRatio,
              mainAxisExtent: gridMainAxisExtent,
              physics: physics,
            );
        }
      },
    );

    return collection;
  }

  UiCollectionLayout _resolveLayout(double width) {
    if (layout != UiCollectionLayout.adaptiveGrid) return layout;
    return breakpoints.resolve(width) == UiFormFactor.phone
        ? UiCollectionLayout.list
        : UiCollectionLayout.grid;
  }
}

/// Section-aware sliver collection with adaptive one/two-column rows.
///
/// Section headers always span the available width. Items following a header
/// are packed into the same row until the next section boundary. This avoids
/// bespoke `SliverList`/`Row` grouping in feature code while retaining lazy
/// row construction and full-width headers.
class UiSliverCollection<T> extends StatelessWidget {
  const UiSliverCollection({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.sectionBuilder,
    this.layout = UiCollectionLayout.list,
    this.itemSpacing,
    this.sectionSpacing,
    this.gridColumnCount = 2,
    this.breakpoints = UiBreakpoints.standard,
  }) : assert(gridColumnCount > 0, 'gridColumnCount must be positive');

  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;
  final UiCollectionSectionBuilder<T>? sectionBuilder;
  final UiCollectionLayout layout;
  final double? itemSpacing;
  final double? sectionSpacing;
  final int gridColumnCount;
  final UiBreakpoints breakpoints;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tokens = UiThemeTokens.of(context);
        final gap = itemSpacing ?? tokens.spacing.x2;
        final headerGap = sectionSpacing ?? tokens.spacing.x2;
        final resolvedLayout = layout == UiCollectionLayout.adaptiveGrid
            ? breakpoints.resolve(constraints.crossAxisExtent) ==
                      UiFormFactor.phone
                  ? UiCollectionLayout.list
                  : UiCollectionLayout.grid
            : layout;
        final columnCount = resolvedLayout == UiCollectionLayout.list
            ? 1
            : gridColumnCount;
        final headers = List<Widget?>.generate(
          items.length,
          (index) => sectionBuilder?.call(context, items[index], index),
          growable: false,
        );
        final blocks = _collectionBlocks(headers, columnCount);

        return SliverList.builder(
          itemCount: blocks.length,
          itemBuilder: (context, blockIndex) {
            final block = blocks[blockIndex];
            return Padding(
              padding: EdgeInsets.only(
                bottom: blockIndex == blocks.length - 1 ? 0 : gap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (block.header != null) ...[
                    block.header!,
                    SizedBox(height: headerGap),
                  ],
                  _CollectionRow<T>(
                    indices: block.indices,
                    items: items,
                    itemBuilder: itemBuilder,
                    gap: gap,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CollectionRow<T> extends StatelessWidget {
  const _CollectionRow({
    required this.indices,
    required this.items,
    required this.itemBuilder,
    required this.gap,
  });

  final List<int> indices;
  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (indices.length == 1) {
      final index = indices.single;
      return itemBuilder(context, items[index], index);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var position = 0; position < indices.length; position++) ...[
          if (position > 0) SizedBox(width: gap),
          Expanded(
            child: itemBuilder(
              context,
              items[indices[position]],
              indices[position],
            ),
          ),
        ],
      ],
    );
  }
}

List<_CollectionBlock> _collectionBlocks(
  List<Widget?> headers,
  int columnCount,
) {
  final blocks = <_CollectionBlock>[];
  var index = 0;
  while (index < headers.length) {
    final row = <int>[index];
    var next = index + 1;
    while (row.length < columnCount &&
        next < headers.length &&
        headers[next] == null) {
      row.add(next);
      next++;
    }
    blocks.add(_CollectionBlock(header: headers[index], indices: row));
    index = next;
  }
  return blocks;
}

class _CollectionBlock {
  const _CollectionBlock({required this.header, required this.indices});

  final Widget? header;
  final List<int> indices;
}

class _CollectionList<T> extends StatelessWidget {
  const _CollectionList({
    required this.items,
    required this.itemBuilder,
    required this.padding,
    required this.itemSpacing,
    required this.physics,
  });

  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;
  final EdgeInsets? padding;
  final double? itemSpacing;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final gap = itemSpacing ?? tokens.spacing.x3;
    final resolvedPadding = _withBodyInsets(
      context,
      padding ?? EdgeInsets.all(tokens.spacing.x4),
    );

    return ListView.separated(
      padding: resolvedPadding,
      physics: physics,
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: gap),
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index], index);
      },
    );
  }
}

class _CollectionGrid<T> extends StatelessWidget {
  const _CollectionGrid({
    required this.items,
    required this.itemBuilder,
    required this.padding,
    required this.maxCrossAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.childAspectRatio,
    required this.mainAxisExtent,
    required this.physics,
  });

  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;
  final EdgeInsets? padding;
  final double maxCrossAxisExtent;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final double childAspectRatio;
  final double? mainAxisExtent;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final gap = tokens.spacing.x3;
    final resolvedPadding = _withBodyInsets(
      context,
      padding ?? EdgeInsets.all(tokens.spacing.x4),
    );

    return GridView.builder(
      padding: resolvedPadding,
      physics: physics,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing ?? gap,
        crossAxisSpacing: crossAxisSpacing ?? gap,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index], index);
      },
    );
  }
}

EdgeInsets _withBodyInsets(BuildContext context, EdgeInsets padding) {
  final insets = UiPageBodyInsets.of(context);
  return EdgeInsets.fromLTRB(
    padding.left + insets.left,
    padding.top + insets.top,
    padding.right + insets.right,
    padding.bottom + insets.bottom,
  );
}
