import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_formatted_text_controller.dart';

class UiFormatAction {
  const UiFormatAction({
    required this.ruleId,
    required this.label,
    required this.shortLabel,
  });

  final String ruleId;
  final String label;
  final String shortLabel;

  static const defaults = [
    UiFormatAction(ruleId: 'bold', label: 'Bold', shortLabel: 'B'),
    UiFormatAction(ruleId: 'italic', label: 'Italic', shortLabel: 'I'),
    UiFormatAction(
      ruleId: 'strikethrough',
      label: 'Strikethrough',
      shortLabel: 'S',
    ),
    UiFormatAction(ruleId: 'code', label: 'Code', shortLabel: '</>'),
    UiFormatAction(ruleId: 'underline', label: 'Underline', shortLabel: 'U'),
    UiFormatAction(ruleId: 'highlight', label: 'Highlight', shortLabel: 'H'),
  ];
}

/// Horizontally scrolling formatting actions sized for native touch targets.
class UiFormatToolbar extends StatelessWidget {
  const UiFormatToolbar({
    super.key,
    required this.controller,
    this.actions = UiFormatAction.defaults,
    this.onFormatApplied,
    this.padding,
    this.semanticsLabel = 'Text formatting',
  });

  final UiFormattedTextController controller;
  final List<UiFormatAction> actions;
  final ValueChanged<String>? onFormatApplied;
  final EdgeInsetsGeometry? padding;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.symmetric(horizontal: tokens.spacing.x1),
        child: Row(
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              _FormatButton(
                action: actions[index],
                onPressed: () {
                  if (controller.toggle(actions[index].ruleId)) {
                    onFormatApplied?.call(actions[index].ruleId);
                  }
                },
              ),
              if (index != actions.length - 1)
                SizedBox(width: tokens.spacing.x1),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({required this.action, required this.onPressed});

  final UiFormatAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return UiPressable(
      onPressed: onPressed,
      semanticsLabel: action.label,
      minTapSize: 48,
      builder: (context, state, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: state.pressed ? tokens.colors.muted : const Color(0x00000000),
          borderRadius: tokens.radius.mdAll,
        ),
        child: child,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          child: UiText(
            action.shortLabel,
            variant: UiTextVariant.label,
            style: switch (action.ruleId) {
              'bold' => const TextStyle(fontWeight: FontWeight.w700),
              'italic' => const TextStyle(fontStyle: FontStyle.italic),
              'strikethrough' => const TextStyle(
                decoration: TextDecoration.lineThrough,
              ),
              'underline' => const TextStyle(
                decoration: TextDecoration.underline,
              ),
              _ => null,
            },
          ),
        ),
      ),
    );
  }
}
