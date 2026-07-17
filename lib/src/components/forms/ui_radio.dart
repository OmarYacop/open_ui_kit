import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

class UiRadio<T> extends StatelessWidget {
  const UiRadio({
    super.key,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? label;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  bool get selected => groupValue == value;
  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      enabled: _interactive,
      onPressed: () => onChanged?.call(value),
      focusNode: focusNode,
      autofocus: autofocus,
      excludeFromSemantics: true,
      minTapSize: 40,
      builder: (context, state, _) {
        final borderColor = state.focused ? c.ring : c.input;
        final fill = selected ? c.primary : c.surface;

        return Semantics(
          checked: selected,
          enabled: _interactive,
          inMutuallyExclusiveGroup: true,
          label: label ?? 'radio option',
          hint: !_interactive ? 'disabled' : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiFocusRing(
                visible: state.focused,
                borderRadius: tokens.radius.pillAll,
                child: UiBox(
                  width: 16,
                  height: 16,
                  background: fill,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: tokens.radius.pillAll,
                  alignment: Alignment.center,
                  child: UiBox(
                    width: 6,
                    height: 6,
                    background: selected
                        ? c.primaryForeground
                        : const Color(0x00000000),
                    borderRadius: tokens.radius.pillAll,
                  ),
                ),
              ),
              if (label != null) ...[
                SizedBox(width: tokens.spacing.x2),
                UiText(
                  label!,
                  variant: UiTextVariant.body,
                  tone: _interactive ? UiTextTone.primary : UiTextTone.muted,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
