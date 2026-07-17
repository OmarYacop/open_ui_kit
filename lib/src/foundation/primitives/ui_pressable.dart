import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Interaction states surfaced by [UiPressable].
@immutable
class UiPressableState {
  const UiPressableState({
    this.hovered = false,
    this.focused = false,
    this.pressed = false,
    this.disabled = false,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;
  final bool disabled;

  UiPressableState copyWith({
    bool? hovered,
    bool? focused,
    bool? pressed,
    bool? disabled,
  }) {
    return UiPressableState(
      hovered: hovered ?? this.hovered,
      focused: focused ?? this.focused,
      pressed: pressed ?? this.pressed,
      disabled: disabled ?? this.disabled,
    );
  }
}

typedef UiPressableBuilder = Widget Function(
  BuildContext context,
  UiPressableState state,
  Widget? child,
);

/// Low-level pressable primitive.
///
/// Wraps hover/focus/press tracking, semantics, and tap targets into a
/// single builder-based widget. Components like [UiButton] compose this;
/// avoid using [GestureDetector] directly.
class UiPressable extends StatefulWidget {
  const UiPressable({
    super.key,
    required this.builder,
    this.child,
    this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.mouseCursor,
    this.behavior = HitTestBehavior.opaque,
    this.excludeFromSemantics = false,
    this.semanticsLabel,
    this.semanticsButton = true,
    this.minTapSize = 44,
    this.enabled = true,
  });

  final UiPressableBuilder builder;
  final Widget? child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor? mouseCursor;
  final HitTestBehavior behavior;
  final bool excludeFromSemantics;
  final String? semanticsLabel;
  final bool semanticsButton;
  final double minTapSize;
  final bool enabled;

  @override
  State<UiPressable> createState() => _UiPressableState();
}

class _UiPressableState extends State<UiPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _isInteractive =>
      widget.enabled &&
      (widget.onPressed != null || widget.onLongPress != null);

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _setHovered(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  void _setFocused(bool v) {
    if (_focused != v) setState(() => _focused = v);
  }

  static const _activateShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    final disabled = !_isInteractive;
    final state = UiPressableState(
      hovered: _hovered && !disabled,
      focused: _focused,
      pressed: _pressed && !disabled,
      disabled: disabled,
    );

    Widget content = widget.builder(context, state, widget.child);

    if (widget.minTapSize > 0) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minTapSize,
          minHeight: widget.minTapSize,
        ),
        child: content,
      );
    }

    final cursor = widget.mouseCursor ??
        (disabled ? SystemMouseCursors.basic : SystemMouseCursors.click);

    content = MouseRegion(
      cursor: cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: content,
    );

    content = Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: !disabled,
      onFocusChange: _setFocused,
      child: content,
    );

    if (!disabled) {
      content = Shortcuts(
        shortcuts: _activateShortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: content,
        ),
      );
    }

    content = GestureDetector(
      behavior: widget.behavior,
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      onLongPress: disabled ? null : widget.onLongPress,
      excludeFromSemantics: true,
      child: content,
    );

    if (!widget.excludeFromSemantics) {
      content = Semantics(
        container: true,
        button: widget.semanticsButton,
        enabled: !disabled,
        label: widget.semanticsLabel,
        onTap: disabled ? null : widget.onPressed,
        onLongPress: disabled ? null : widget.onLongPress,
        child: content,
      );
    }

    return content;
  }
}
