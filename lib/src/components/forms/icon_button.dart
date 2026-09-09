import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_action_surface_owner.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/theme/ui_intent.dart';
import '../forms/button.dart' show UiSize;

/// Below this visual size, a pressed button grows its surface instead of
/// shrinking its content (see [UiIconButton]'s press treatment) — small
/// enough that a shrink is barely visible, and a thumb covering the control
/// benefits from seeing it get bigger rather than smaller underneath.
const double kUiPressGrowThreshold = 44;

/// How far a small pressed surface grows past [kUiPressGrowThreshold],
/// as a scale factor. Content inside is counter-scaled by `1 / this` so it
/// stays visually fixed size while only the surface grows around it.
const double kUiPressGrowScale = 1.14;

/// Icon-only button primitive.
///
/// Use this for compact toolbar actions, card menus, close buttons, and other
/// controls where the visible label is an icon. [semanticsLabel] is required so
/// the control remains accessible.
///
/// At every [UiSize] this button's visual footprint (28/44/44) sits at or
/// below [kUiPressGrowThreshold], so pressing it smoothly grows the surface rather
/// than shrinking the content — a fixed-size icon shrinking by a few
/// percent is nearly imperceptible, but a thumb covering a small circular
/// target benefits from feeling it grow underneath, the way iOS's own
/// small round controls (e.g. keyboard keys) do. [UiButton], whose surface
/// scales with its label and stays comfortably above the threshold, keeps
/// the standard whole-surface press shrink instead.
class UiIconButton extends StatelessWidget {
  const UiIconButton({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.onPressed,
    this.intent = UiIntent.ghost,
    this.size = UiSize.md,
    this.visualExtent,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius,
    this.borderWidth = 1,
    this.surfaceMargin = EdgeInsets.zero,
    this.focusNode,
    this.autofocus = false,
  }) : assert(visualExtent == null || visualExtent > 0);

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final UiIntent intent;
  final UiSize size;

  /// Overrides the square surface extent for controls sized by their parent,
  /// such as a chat composer's outer actions. The icon still follows [size]
  /// and the touch target remains at least 44 logical pixels.
  final double? visualExtent;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double borderWidth;

  /// Space around the painted surface inside the unchanged touch target.
  /// Useful for compact actions embedded in an input or another surface.
  final EdgeInsetsGeometry surfaceMargin;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final radius = borderRadius ?? tokens.radius.mdAll;
    // Icon-only chrome has stable geometry across text preferences. Content
    // text still scales normally; the independent touch target remains >=44px.
    final visualSize = visualExtent ?? _visualSize(size);
    final iconSize = _iconSize(size);

    return UiPressable(
      onPressed: onPressed,
      onPressChanged:
          UiActionSurfaceOwner.owns(
            context,
            backgroundColor ??
                UiIntentPalette.rest(intent, tokens.colors).background,
          )
          ? UiActionSurfaceOwner.maybeOf(context)?.onPressChanged
          : null,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      minTapSize: math.max(44, visualSize),
      builder: (context, state, _) {
        final palette = UiIntentPalette.rest(intent, tokens.colors);
        final fg = foregroundColor ?? palette.foreground;
        final bg = backgroundColor ?? palette.background;
        final owned = UiActionSurfaceOwner.owns(context, bg);
        final border = borderColor ?? palette.border;
        final isTransparent = bg.a == 0;
        final effectiveBg = state.pressed
            ? (isTransparent
                  ? tokens.colors.accent.withValues(alpha: 0.60)
                  : _shift(bg, -0.03))
            : state.hovered
            ? (isTransparent
                  ? tokens.colors.accent.withValues(alpha: 0.35)
                  : _shift(bg, -0.015))
            : bg;

        // Press treatment follows the authored surface extent, independent
        // of accessibility text scaling.
        final grows = visualSize <= kUiPressGrowThreshold;
        final motion = UiThemeTokens.motionOf(context);
        final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        final surfaceScale = state.pressed && !reduced
            ? (grows ? kUiPressGrowScale : 0.96)
            : 1.0;
        // Retarget from the current displayed scale on release/cancel/repress.
        // Growing the surface must not grow the icon with it — only the
        // background behind the thumb should read as "bigger", so the icon
        // is counter-scaled by the same factor in the opposite direction.
        // Both Transforms are paint-only (RenderTransform keeps the
        // child's layout size), so the grown surface can paint outside
        // this button's laid-out bounds without shifting sibling layout.

        // A tight toolbar slot controls the hit area, not the painted surface.
        return Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Padding(
            padding: surfaceMargin,
            child: UiFocusRing(
              visible: state.focused,
              borderRadius: radius,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1, end: surfaceScale),
                duration: state.pressed ? motion.fast : motion.standard,
                curve: motion.standardCurve,
                builder: (context, scale, _) => Transform.scale(
                  scale: scale,
                  child: UiBox(
                    width: visualSize,
                    height: visualSize,
                    background: owned ? const Color(0x00000000) : effectiveBg,
                    border: owned || border == null
                        ? null
                        : Border.all(
                            color: border,
                            // The surface grows on press; the stroke remains the
                            // configured logical width throughout the handoff.
                            width: borderWidth / scale,
                          ),
                    borderRadius: radius,
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: grows ? 1 / scale : 1.0,
                      child: IconTheme.merge(
                        data: IconThemeData(
                          color: fg,
                          size: iconSize,
                          applyTextScaling: false,
                        ),
                        child: icon,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static double _visualSize(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 28;
      case UiSize.md:
        return 44;
      case UiSize.lg:
        return 44;
    }
  }

  static double _iconSize(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 17;
      case UiSize.md:
        return 22;
      case UiSize.lg:
        return 22;
    }
  }

  static Color _shift(Color base, double amount) {
    if (base.a == 0) return base;
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}
