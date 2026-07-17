import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

class UiCheckbox extends StatelessWidget {
  const UiCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? helper;
  final String? errorText;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    return UiPressable(
      enabled: _interactive,
      onPressed: () => onChanged?.call(!value),
      focusNode: focusNode,
      autofocus: autofocus,
      excludeFromSemantics: true,
      minTapSize: 40,
      builder: (context, state, _) {
        final borderColor = hasError
            ? c.destructive
            : state.focused
                ? c.ring
                : c.input;
        final boxColor = value
            ? c.primary
            : state.hovered || state.pressed
                ? c.accent
                : c.surface;
        final checkColor =
            value ? c.primaryForeground : const Color(0x00000000);

        return Semantics(
          checked: value,
          enabled: _interactive,
          inMutuallyExclusiveGroup: false,
          label: label ?? 'checkbox',
          hint: !_interactive ? 'disabled' : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UiFocusRing(
                    visible: state.focused && !hasError,
                    borderRadius: tokens.radius.smAll,
                    child: UiBox(
                      width: 16,
                      height: 16,
                      background: boxColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: tokens.radius.smAll,
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.check,
                        size: 12,
                        color: checkColor,
                      ),
                    ),
                  ),
                  if (label != null) ...[
                    SizedBox(width: tokens.spacing.x2),
                    Flexible(
                      child: UiText(
                        label!,
                        variant: UiTextVariant.body,
                        tone: _interactive
                            ? UiTextTone.primary
                            : UiTextTone.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (helper != null && !hasError) ...[
                SizedBox(height: tokens.spacing.x1),
                UiText(
                  helper!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                ),
              ],
              if (hasError) ...[
                SizedBox(height: tokens.spacing.x1),
                UiText(
                  errorText!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.danger,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
