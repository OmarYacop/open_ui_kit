import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// Paints a soft, theme-aware clearance shadow around a component.
///
/// Unlike the elevation shadows in `tokens.shadows`, this effect separates a
/// compact component from visually busy content without implying elevation.
/// It is the shared treatment used by [UiRefreshIndicator].
class UiComponentShadow extends StatelessWidget {
  const UiComponentShadow({
    super.key,
    required this.child,
    this.color,
    this.blurRadius,
    this.spreadRadius,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  }) : assert(
         shape != BoxShape.circle || borderRadius == null,
         'A circular shadow cannot have a border radius.',
       );

  /// The shadow color. Defaults to the current theme background.
  final Color? color;

  /// Defaults to `tokens.spacing.x3`.
  final double? blurRadius;

  /// Defaults to `tokens.spacing.x1`.
  final double? spreadRadius;

  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
        boxShadow: [
          BoxShadow(
            color: color ?? tokens.colors.background.withValues(alpha: 0.96),
            blurRadius: blurRadius ?? tokens.spacing.x3,
            spreadRadius: spreadRadius ?? tokens.spacing.x1,
          ),
        ],
      ),
      child: child,
    );
  }
}
