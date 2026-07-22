import 'package:flutter/widgets.dart';

import '../../foundation/icons/ui_directional_icons.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

@immutable
class UiNavigationBackHistoryItem {
  const UiNavigationBackHistoryItem({
    required this.title,
    this.subtitle,
    this.value,
  });

  final String title;
  final String? subtitle;
  final Object? value;
}

@immutable
class UiNavigationBackPopTarget {
  const UiNavigationBackPopTarget(this.count)
      : assert(count > 0, 'count must be greater than zero');

  final int count;
}

class UiNavigationBackButton extends StatefulWidget {
  const UiNavigationBackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.history = const <UiNavigationBackHistoryItem>[],
    this.onHistorySelected,
  });

  final String label;
  final VoidCallback onPressed;
  final List<UiNavigationBackHistoryItem> history;
  final ValueChanged<UiNavigationBackHistoryItem>? onHistorySelected;

  @override
  State<UiNavigationBackButton> createState() => _UiNavigationBackButtonState();
}

class _UiNavigationBackButtonState extends State<UiNavigationBackButton> {
  final LayerLink _menuLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _removeMenu();
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: overlay.context,
    );
    _menuEntry = OverlayEntry(
      builder: (overlayContext) =>
          capturedThemes.wrap(_buildMenuOverlay(overlayContext)),
    );
    overlay.insert(_menuEntry!);
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  Widget _buildMenuOverlay(BuildContext context) {
    final tokens = UiThemeTokens.of(this.context);
    final c = tokens.colors;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeMenu,
          ),
        ),
        CompositedTransformFollower(
          link: _menuLink,
          // Anchor the flyout to the trigger's reading-start edge so
          // the history menu opens under the back glyph in both LTR
          // and RTL.
          targetAnchor: AlignmentDirectional.bottomStart.resolve(
            Directionality.of(context),
          ),
          followerAnchor: AlignmentDirectional.topStart.resolve(
            Directionality.of(context),
          ),
          offset: Offset(0, tokens.spacing.x2),
          child: UiBox(
            background: c.popover,
            border: Border.all(color: c.border),
            borderRadius: tokens.radius.smAll,
            boxShadow: tokens.shadows.md,
            padding: EdgeInsets.all(tokens.spacing.x1),
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in widget.history)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.spacing.x1 / 4,
                        ),
                        child: UiPressable(
                          onPressed: () {
                            _removeMenu();
                            final onHistorySelected = widget.onHistorySelected;
                            if (onHistorySelected != null) {
                              onHistorySelected(item);
                            } else {
                              widget.onPressed();
                            }
                          },
                          minTapSize: 0,
                          builder: (context, state, _) {
                            final highlight =
                                state.hovered || state.pressed || state.focused;
                            return UiBox(
                              background: highlight
                                  ? c.surfaceMuted
                                  : const Color(0x00000000),
                              borderRadius: tokens.radius.xsAll,
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacing.x2,
                                vertical: tokens.spacing.x1,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  UiText(
                                    item.title,
                                    variant: UiTextVariant.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.subtitle != null)
                                    UiText(
                                      item.subtitle!,
                                      variant: UiTextVariant.caption,
                                      tone: UiTextTone.muted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return CompositedTransformTarget(
      link: _menuLink,
      child: UiPressable(
        onPressed: widget.onPressed,
        onLongPress: widget.history.isEmpty ? null : _toggleMenu,
        semanticsLabel: widget.label,
        minTapSize: 0,
        builder: (context, state, _) {
          final foreground = state.pressed
              ? c.textPrimary.withValues(alpha: 0.55)
              : state.hovered || state.focused
                  ? c.textPrimary.withValues(alpha: 0.78)
                  : c.textPrimary;

          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: foreground),
            duration: tokens.motion.fast,
            curve: tokens.motion.standardCurve,
            builder: (context, color, _) {
              final resolvedColor = color ?? foreground;
              return UiBox(
                background: const Color(0x00000000),
                borderRadius: tokens.radius.smAll,
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      UiDirectionalIcons.chevronBack(context),
                      size: 17,
                      color: resolvedColor,
                    ),
                    SizedBox(width: tokens.spacing.x1 / 2),
                    Flexible(
                      child: UiText(
                        widget.label,
                        variant: UiTextVariant.body,
                        style: TextStyle(color: resolvedColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
