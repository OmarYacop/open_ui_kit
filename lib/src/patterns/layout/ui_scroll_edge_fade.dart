import 'package:flutter/widgets.dart';

/// Paints inexpensive surface-color fades over the vertical edges of [child].
///
/// This is the standard Open UI treatment for scrollable content moving below
/// floating chrome. It avoids live backdrop sampling while preserving depth
/// and readable chrome boundaries.
class UiScrollEdgeFade extends StatelessWidget {
  const UiScrollEdgeFade({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.extent = 48,
    this.topExtent,
    this.bottomExtent,
    this.horizontalInset = 0,
    this.maxOpacity = 0.72,
    this.showTop = true,
    this.showBottom = true,
    this.paintOverChild = true,
  })  : assert(extent >= 0),
        assert(maxOpacity >= 0 && maxOpacity <= 1);

  final Widget child;
  final Color backgroundColor;
  final double extent;
  final double? topExtent;
  final double? bottomExtent;
  final double horizontalInset;
  final double maxOpacity;
  final bool showTop;
  final bool showBottom;
  final bool paintOverChild;

  @override
  Widget build(BuildContext context) {
    final edgeColor = backgroundColor.withValues(alpha: maxOpacity);
    final transparentEdgeColor = backgroundColor.withValues(alpha: 0);
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final view = View.of(context);
    final leftSafeBleed = view.padding.left / view.devicePixelRatio;
    final rightSafeBleed = view.padding.right / view.devicePixelRatio;
    final startBleed =
        direction == TextDirection.ltr ? leftSafeBleed : rightSafeBleed;
    final endBleed =
        direction == TextDirection.ltr ? rightSafeBleed : leftSafeBleed;

    final fades = <Widget>[
      if (showTop)
        PositionedDirectional(
          start: horizontalInset - startBleed,
          end: horizontalInset - endBleed,
          top: 0,
          height: topExtent ?? extent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [edgeColor, transparentEdgeColor],
                ),
              ),
            ),
          ),
        ),
      if (showBottom)
        PositionedDirectional(
          start: horizontalInset - startBleed,
          end: horizontalInset - endBleed,
          bottom: 0,
          height: bottomExtent ?? extent,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [edgeColor, transparentEdgeColor],
                ),
              ),
            ),
          ),
        ),
    ];

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (!paintOverChild) ...fades,
        child,
        if (paintOverChild) ...fades,
      ],
    );
  }
}
