import 'package:flutter/widgets.dart';

import '../../components/feedback/async_states.dart';
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
    this.gridMaxCrossAxisExtent = 420,
    this.gridMainAxisSpacing,
    this.gridCrossAxisSpacing,
    this.gridChildAspectRatio = 1,
    this.physics,
    this.safeViewportMode = UiSafeViewportMode.none,
    this.breakpoints = UiBreakpoints.standard,
  });

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
  final double gridMaxCrossAxisExtent;
  final double? gridMainAxisSpacing;
  final double? gridCrossAxisSpacing;
  final double gridChildAspectRatio;
  final ScrollPhysics? physics;
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return UiLoadingState(
        mode: UiAsyncStateMode.page,
        title: loadingTitle,
      );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedLayout = _resolveLayout(constraints.maxWidth);
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
              physics: physics,
            );
        }
      },
    );
  }

  UiCollectionLayout _resolveLayout(double width) {
    if (layout != UiCollectionLayout.adaptiveGrid) return layout;
    return breakpoints.resolve(width) == UiFormFactor.phone
        ? UiCollectionLayout.list
        : UiCollectionLayout.grid;
  }
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
    final resolvedPadding =
        _withBodyInsets(context, padding ?? EdgeInsets.all(tokens.spacing.x4));

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
    required this.physics,
  });

  final List<T> items;
  final UiCollectionItemBuilder<T> itemBuilder;
  final EdgeInsets? padding;
  final double maxCrossAxisExtent;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final double childAspectRatio;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final gap = tokens.spacing.x3;
    final resolvedPadding =
        _withBodyInsets(context, padding ?? EdgeInsets.all(tokens.spacing.x4));

    return GridView.builder(
      padding: resolvedPadding,
      physics: physics,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing ?? gap,
        crossAxisSpacing: crossAxisSpacing ?? gap,
        childAspectRatio: childAspectRatio,
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
