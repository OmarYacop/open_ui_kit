import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/theme/ui_intent.dart';
import '../forms/icon_button.dart';

@immutable
class UiMessageUtilityAction {
  const UiMessageUtilityAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.intent = UiIntent.ghost,
    this.enabled = true,
  });

  final Object id;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final UiIntent intent;
  final bool enabled;
}

/// A compact, keyboard-dock-friendly command surface for selected messages.
///
/// The strip owns its internal rhythm and bottom breathing room. Callers only
/// supply truthful actions and place it inside their existing keyboard dock.
class UiMessageUtilityStrip extends StatelessWidget {
  const UiMessageUtilityStrip({
    super.key,
    required this.selectionLabel,
    required this.closeLabel,
    required this.onClose,
    required this.actions,
    this.bottomMargin,
  });

  final String selectionLabel;
  final String closeLabel;
  final VoidCallback onClose;
  final List<UiMessageUtilityAction> actions;
  final double? bottomMargin;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return UiBox(
      margin: EdgeInsets.only(
        left: tokens.spacing.x3,
        right: tokens.spacing.x3,
        bottom: bottomMargin ?? tokens.spacing.x3,
      ),
      background: tokens.colors.surface,
      border: Border.all(color: tokens.colors.border),
      borderRadius: tokens.radius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: tokens.spacing.x4,
              end: tokens.spacing.x2,
              top: tokens.spacing.x2,
              bottom: tokens.spacing.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: UiText(
                    selectionLabel,
                    variant: UiTextVariant.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                UiIconButton(
                  icon: const Icon(LucideIcons.x),
                  semanticsLabel: closeLabel,
                  onPressed: onClose,
                  borderRadius: tokens.radius.mdAll,
                ),
              ],
            ),
          ),
          UiBox(height: 1, background: tokens.colors.border),
          Padding(
            padding: EdgeInsets.all(tokens.spacing.x2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = actions.length.clamp(1, 4);
                final gap = tokens.spacing.x1;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var index = 0; index < actions.length; index++)
                      SizedBox(
                        width: itemWidth,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(actions[index].id),
                          tween: Tween(begin: reduceMotion ? 1 : .88, end: 1),
                          duration: reduceMotion
                              ? Duration.zero
                              : Duration(milliseconds: 180 + (index * 28)),
                          curve: Curves.easeOutQuart,
                          builder: (context, progress, child) => Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, (1 - progress) * 8),
                              child: child,
                            ),
                          ),
                          child: _UtilityAction(action: actions[index]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityAction extends StatelessWidget {
  const _UtilityAction({required this.action});

  final UiMessageUtilityAction action;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final palette = UiIntentPalette.rest(action.intent, tokens.colors);
    final interactiveBackground = palette.background.a == 0
        ? tokens.colors.surfaceMuted
        : palette.background;

    return UiPressable(
      enabled: action.enabled,
      onPressed: action.enabled ? action.onPressed : null,
      semanticsLabel: action.label,
      minTapSize: 48,
      builder: (context, state, _) => AnimatedOpacity(
        opacity: action.enabled ? 1 : .42,
        duration: tokens.motion.fast,
        child: AnimatedScale(
          scale: state.pressed ? .95 : 1,
          duration: tokens.motion.fast,
          curve: Curves.easeOutCubic,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: tokens.motion.fast,
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 58),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.x1,
                vertical: tokens.spacing.x2,
              ),
              decoration: BoxDecoration(
                color: state.hovered || state.pressed
                    ? interactiveBackground
                    : const Color(0x00000000),
                borderRadius: tokens.radius.mdAll,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(action.icon, size: 20, color: palette.foreground),
                  SizedBox(height: tokens.spacing.x1),
                  UiText(
                    action.label,
                    variant: UiTextVariant.caption,
                    style: TextStyle(
                      color: palette.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
