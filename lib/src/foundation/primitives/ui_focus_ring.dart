import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

/// A crisp focus ring drawn around a child when [visible] is true.
///
/// Uses a stroked outline so it matches shadcn's ring treatment without
/// shifting layout or adding a glow.
class UiFocusRing extends StatelessWidget {
  const UiFocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.borderRadius,
    this.color,
    this.width = 2,
    this.offset = 2,
  });

  final bool visible;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? color;
  final double width;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;

    final tokens = UiThemeTokens.of(context);
    final ringColor = color ?? tokens.colors.ring;
    final radius = borderRadius ?? tokens.radius.mdAll;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -offset,
          top: -offset,
          right: -offset,
          bottom: -offset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _inflateRadius(radius, offset),
                border: Border.all(color: ringColor, width: width),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static BorderRadius _inflateRadius(BorderRadius r, double delta) {
    return BorderRadius.only(
      topLeft: _bump(r.topLeft, delta),
      topRight: _bump(r.topRight, delta),
      bottomLeft: _bump(r.bottomLeft, delta),
      bottomRight: _bump(r.bottomRight, delta),
    );
  }

  static Radius _bump(Radius r, double delta) {
    if (r == Radius.zero) return Radius.zero;
    return Radius.elliptical(r.x + delta, r.y + delta);
  }
}
