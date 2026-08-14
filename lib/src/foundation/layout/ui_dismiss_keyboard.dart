import 'package:flutter/widgets.dart';

/// Dismisses the current keyboard focus when the user taps outside a focused
/// control.
///
/// Place this around a page or a self-contained form surface. The translucent
/// hit-test behavior keeps otherwise empty space interactive without changing
/// the child's layout or semantics.
class UiDismissKeyboard extends StatelessWidget {
  const UiDismissKeyboard({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
