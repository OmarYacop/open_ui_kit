import 'package:flutter/widgets.dart';

/// A typed route definition.
///
/// [TArgs] describes the argument shape expected by the route (pass
/// `void` for argument-less routes). [TResult] describes the value the
/// route resolves with when it pops. A controller built on
/// [UiRouteSpec]s enforces these types at runtime, producing useful
/// assertion failures when a screen is pushed with mismatched args.
@immutable
class UiRouteSpec<TArgs, TResult> {
  const UiRouteSpec({
    required this.id,
    required this.builder,
    this.title,
    this.titleBuilder,
  });

  /// Unique route identifier.
  final String id;

  /// Human-readable title for the history menu. Defaults to [id].
  final String? title;

  /// Optional dynamic title resolver used for history/back labels.
  ///
  /// When provided, controllers call this with route args and store the
  /// resolved result on the corresponding [UiRouteEntry]. This allows
  /// history labels to reflect per-entry values (e.g. "Collection 3")
  /// instead of a single static [title] for every push of this route.
  final String Function(TArgs args)? titleBuilder;

  /// Content builder. The second argument is the typed payload passed
  /// to `UiNavigationController.push`.
  final Widget Function(BuildContext context, TArgs args) builder;

  String? resolveTitle(Object? args) {
    final dynamicBuilder = titleBuilder;
    if (dynamicBuilder != null && args != null) {
      return dynamicBuilder(args as TArgs);
    }
    return title;
  }

  @override
  String toString() => 'UiRouteSpec<$TArgs,$TResult>($id)';
}
