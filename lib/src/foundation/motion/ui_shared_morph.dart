import 'package:flutter/widgets.dart';

enum UiSharedMorphFlightStyle { destination, crossFade }

abstract final class UiSharedMorphMotion {
  /// Balanced iOS-style spatial timing: a controlled launch, decisive travel,
  /// and a short settle without the long ease-out tail.
  static const Curve curve = Cubic(0.38, 0.05, 0.22, 0.95);

  /// Content starts changing with the gesture and remains legible throughout
  /// the spatial morph instead of inheriting its acceleration profile.
  static const Curve contentCurve = Curves.linear;

  /// Depth should register early while the shared surface is still moving.
  static const Curve effectCurve = Cubic(0.20, 0.60, 0.30, 1);
}

/// A stable identity for content that should travel between two routes.
///
/// The shared element uses the Navigator's route timeline, preserves its
/// original layout with Hero's placeholder, supports interactive back
/// gestures, and curves its geometry to stay synchronized with Open UI
/// container transforms.
class UiSharedMorph extends StatelessWidget {
  const UiSharedMorph({
    super.key,
    required this.tag,
    required this.child,
    this.curve = UiSharedMorphMotion.curve,
    this.flightShuttleBuilder,
    this.flightStyle = UiSharedMorphFlightStyle.destination,
    this.placeholderBuilder,
    this.transitionOnUserGestures = true,
  });

  final Object tag;
  final Widget child;
  final Curve curve;
  final HeroFlightShuttleBuilder? flightShuttleBuilder;
  final UiSharedMorphFlightStyle flightStyle;
  final HeroPlaceholderBuilder? placeholderBuilder;
  final bool transitionOnUserGestures;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: transitionOnUserGestures,
      createRectTween: (begin, end) => _UiCurvedRectTween(
        begin: begin,
        end: end,
        curve: curve,
      ),
      flightShuttleBuilder: flightShuttleBuilder ?? _buildFlight,
      placeholderBuilder: placeholderBuilder,
      child: child,
    );
  }

  Widget _buildFlight(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = (fromHeroContext.widget as Hero).child;
    final to = (toHeroContext.widget as Hero).child;
    if (flightStyle == UiSharedMorphFlightStyle.destination) {
      return direction == HeroFlightDirection.push ? to : from;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final routeProgress = curve.transform(
          animation.value.clamp(0.0, 1.0),
        );
        final destinationOpacity = direction == HeroFlightDirection.push
            ? routeProgress
            : 1 - routeProgress;
        return Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.centerLeft,
          children: [
            Opacity(opacity: 1 - destinationOpacity, child: from),
            Opacity(opacity: destinationOpacity, child: to),
          ],
        );
      },
    );
  }
}

class _UiCurvedRectTween extends RectTween {
  _UiCurvedRectTween({
    required super.begin,
    required super.end,
    required this.curve,
  });

  final Curve curve;

  @override
  Rect lerp(double t) => Rect.lerp(begin!, end!, curve.transform(t))!;
}
