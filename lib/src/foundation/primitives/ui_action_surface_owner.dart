import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Internal composition scope: an enclosing animated surface owns neutral
/// button chrome. The button keeps its content, sizing and semantics.
class UiActionSurfaceOwner extends InheritedWidget {
  const UiActionSurfaceOwner({
    super.key,
    required super.child,
    this.onPressChanged,
  });

  /// Lets a shared outer surface paint feedback for its contained control.
  final ValueChanged<bool>? onPressChanged;

  static UiActionSurfaceOwner? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiActionSurfaceOwner>();

  static bool owns(BuildContext context, Color background) {
    final neutral =
        background.a == 0 ||
        math.max(background.r, math.max(background.g, background.b)) -
                math.min(background.r, math.min(background.g, background.b)) <
            .04;
    return neutral &&
        context.dependOnInheritedWidgetOfExactType<UiActionSurfaceOwner>() !=
            null;
  }

  @override
  bool updateShouldNotify(UiActionSurfaceOwner oldWidget) =>
      onPressChanged != oldWidget.onPressChanged;
}
