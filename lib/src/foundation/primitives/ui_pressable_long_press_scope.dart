import 'package:flutter/widgets.dart';

/// Internal gesture composition for a button that opens a held-pointer menu.
/// The actual pressable owns the recognizer and its disabled/semantic state;
/// the menu only supplies the held-pointer behavior.
class UiPressableLongPressScope extends InheritedWidget {
  const UiPressableLongPressScope({
    super.key,
    required super.child,
    required this.onStart,
    required this.onMoveUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.onSemanticLongPress,
  });

  final GestureLongPressStartCallback? onStart;
  final GestureLongPressMoveUpdateCallback? onMoveUpdate;
  final GestureLongPressEndCallback? onEnd;
  final VoidCallback? onCancel;
  final VoidCallback? onSemanticLongPress;

  static UiPressableLongPressScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiPressableLongPressScope>();

  @override
  bool updateShouldNotify(UiPressableLongPressScope oldWidget) =>
      onStart != oldWidget.onStart ||
      onMoveUpdate != oldWidget.onMoveUpdate ||
      onEnd != oldWidget.onEnd ||
      onCancel != oldWidget.onCancel ||
      onSemanticLongPress != oldWidget.onSemanticLongPress;
}
