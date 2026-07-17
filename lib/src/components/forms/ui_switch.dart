import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

class UiSwitch extends StatelessWidget {
  const UiSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.enabled = true,
    this.loading = false,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;
  final bool loading;
  final FocusNode? focusNode;
  final bool autofocus;

  bool get _interactive => enabled && onChanged != null && !loading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiPressable(
      enabled: _interactive,
      onPressed: () => onChanged?.call(!value),
      focusNode: focusNode,
      autofocus: autofocus,
      excludeFromSemantics: true,
      minTapSize: 44,
      builder: (context, state, _) {
        final trackColor = value
            ? c.primary
            : state.hovered || state.pressed
                ? c.accent
                : c.input;

        final knobColor = value ? c.primaryForeground : c.surface;

        return Semantics(
          toggled: value,
          enabled: _interactive,
          label: label ?? 'switch',
          hint: loading
              ? 'loading'
              : !_interactive
                  ? 'disabled'
                  : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiFocusRing(
                visible: state.focused,
                borderRadius: tokens.radius.pillAll,
                child: AnimatedContainer(
                  duration: tokens.motion.fast,
                  curve: tokens.motion.standardCurve,
                  width: 36,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: tokens.radius.pillAll,
                    border: Border.all(color: value ? c.primary : c.input),
                  ),
                  child: Align(
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: UiBox(
                      width: 16,
                      height: 16,
                      background: loading ? c.mutedForeground : knobColor,
                      borderRadius: tokens.radius.pillAll,
                    ),
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
