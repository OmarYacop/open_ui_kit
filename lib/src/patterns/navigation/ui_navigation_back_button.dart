import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

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
            borderRadius: tokens.radius.mdAll,
            boxShadow: tokens.shadows.md,
            padding: EdgeInsets.all(tokens.spacing.x2),
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
                            vertical: tokens.spacing.x1 / 2),
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
                              borderRadius: tokens.radius.mdAll,
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.spacing.x3,
                                vertical: tokens.spacing.x2,
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
          return UiBox(
            background: state.pressed
                ? c.surfaceMuted.withValues(alpha: 0.9)
                : const Color(0x00000000),
            borderRadius: tokens.radius.smAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x2,
              vertical: tokens.spacing.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.chevronLeft,
                  size: 18,
                  color: c.textPrimary,
                ),
                SizedBox(width: tokens.spacing.x1),
                UiText(
                  widget.label,
                  variant: UiTextVariant.subheading,
                  style: TextStyle(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
