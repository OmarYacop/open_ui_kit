import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_progress.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/theme/ui_intent.dart';
import '../../foundation/tokens/ui_color_tokens.dart';
import '../../foundation/tokens/ui_spacing_tokens.dart';

// Deprecated import path retained for source compatibility through 0.x.
//
// Dart does not support deprecating an export directive without also marking
// the declaration deprecated at its canonical location. Keep this re-export
// until 1.0.0, then remove it as documented in CHANGELOG.md and
// doc/deprecation_policy.md. New code should import foundation.dart.
export '../../foundation/theme/ui_intent.dart';

/// Component sizing scale.
enum UiSize { sm, md, lg }

class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    required this.border,
    this.opacity = 1.0,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final double opacity;
}

/// Token-driven labeled action button.
///
/// Use this for commands with visible text such as "Save", "Cancel", and
/// "Create invoice". For icon-only commands, prefer [UiIconButton] so the
/// fixed hit target, icon sizing, and semantics stay consistent.
///
/// Button intent has one important package convention:
///
/// - Omitted [intent] / [UiIntent.defaultIntent] renders as
///   [UiIntent.primary].
/// - Use [UiIntent.neutral] for secondary or cancel actions.
/// - Neutral, secondary, and destructive styles include their normal outline by
///   default. Pass [showBorder] as `false` only when the button is placed inside
///   an already framed or elevated surface and the extra outline would be
///   visually noisy.
///
/// ```dart
/// UiButton(
///   label: 'Cancel',
///   intent: UiIntent.neutral,
///   showBorder: false, // embedded in an already bordered drawer/footer
///   onPressed: onCancel,
/// )
/// ```
class UiButton extends StatelessWidget {
  const UiButton({
    super.key,
    required this.label,
    this.onPressed,
    this.intent = UiIntent.defaultIntent,
    this.size = UiSize.md,
    this.leading,
    this.trailing,
    this.loading = false,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticsLabel,
    this.boxShadow,
    this.showBorder = true,
  });

  /// Visible button text.
  final String label;

  /// Called when the button is activated. `null` disables the button.
  final VoidCallback? onPressed;

  /// Visual role of the button. Defaults to the primary call-to-action.
  final UiIntent intent;

  /// Button height, padding, text, and icon scale.
  final UiSize size;

  /// Optional icon or small widget shown before [label].
  final Widget? leading;

  /// Optional icon or small widget shown after [label].
  final Widget? trailing;

  /// Replaces the label content with a spinner and disables activation.
  final bool loading;

  /// Whether the button should fill the available horizontal space.
  final bool expand;

  /// Optional focus node for externally managed focus.
  final FocusNode? focusNode;

  /// Whether this button should request focus when first built.
  final bool autofocus;

  /// Spoken label. Defaults to [label].
  final String? semanticsLabel;

  /// Optional custom shadow for floating action surfaces.
  final List<BoxShadow>? boxShadow;

  /// Whether to paint the resolved variant outline.
  ///
  /// Defaults to `true`. Keep the default for standalone neutral and secondary
  /// buttons. Set to `false` for floating/embedded secondary buttons that live
  /// inside a drawer, sheet, or card that already supplies its own border.
  final bool showBorder;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final padding = _paddingFor(size, tokens.spacing);
    final minHeight = _minHeightFor(size);
    final radius = tokens.radius.mdAll;
    final textStyle = _textStyleFor(size, tokens);

    final button = UiPressable(
      enabled: _enabled,
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel ?? label,
      minTapSize: 44,
      builder: (context, state, _) {
        final style = _resolveStyle(tokens.colors, intent, state);
        final scale = state.pressed ? 0.97 : 1.0;

        return UiFocusRing(
          visible: state.focused,
          borderRadius: radius,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: style.opacity,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: UiBox(
                  background: style.background,
                  borderRadius: radius,
                  border: showBorder && style.border != null
                      ? Border.all(color: style.border!, width: 1)
                      : null,
                  boxShadow: boxShadow,
                  padding: padding,
                  alignment: expand ? Alignment.center : null,
                  width: expand ? double.infinity : null,
                  child: _content(context, style.foreground, textStyle, state),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (expand) return button;

    // A loose parent (for example, a stretching form column, or a tall
    // loosely-constrained container) must not turn a compact button into a
    // full-width or full-height surface and tap target. The outer Align
    // accepts the parent's constraint while laying out the pressable loosely
    // on both axes.
    return Align(
      alignment: Alignment.center,
      widthFactor: 1,
      heightFactor: 1,
      child: button,
    );
  }

  Widget _content(
    BuildContext context,
    Color fg,
    TextStyle textStyle,
    UiPressableState state,
  ) {
    final tokens = UiThemeTokens.of(context);
    final gap = SizedBox(width: _gapFor(size, tokens.spacing));

    if (loading) {
      final iconSize = _iconSizeFor(size);
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: UiSpinner(
          size: iconSize,
          strokeWidth: iconSize * 0.2,
          color: fg,
        ),
      );
    }

    final decoration = intent == UiIntent.link
        ? (state.hovered || state.pressed
            ? TextDecoration.underline
            : TextDecoration.none)
        : null;

    final children = <Widget>[
      if (leading != null) ...[
        IconTheme.merge(
          data: IconThemeData(color: fg, size: _iconSizeFor(size)),
          child: leading!,
        ),
        gap,
      ],
      Flexible(
        child: UiText(
          label,
          variant: _textVariantFor(size),
          style: textStyle.copyWith(color: fg, decoration: decoration),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      if (trailing != null) ...[
        gap,
        IconTheme.merge(
          data: IconThemeData(color: fg, size: _iconSizeFor(size)),
          child: trailing!,
        ),
      ],
    ];

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  static EdgeInsets _paddingFor(UiSize size, UiSpacingTokens spacing) {
    switch (size) {
      case UiSize.sm:
        return EdgeInsets.symmetric(horizontal: spacing.x3);
      case UiSize.md:
        return EdgeInsets.symmetric(horizontal: spacing.x4);
      case UiSize.lg:
        return EdgeInsets.symmetric(horizontal: spacing.x6);
    }
  }

  static double _minHeightFor(UiSize size) => UiButtonMetrics.minHeight(size);

  static double _iconSizeFor(UiSize size) => UiButtonMetrics.iconSize(size);

  static double _gapFor(UiSize size, UiSpacingTokens spacing) =>
      UiButtonMetrics.gap(size, spacing);

  static UiTextVariant _textVariantFor(UiSize size) =>
      UiButtonMetrics.textVariant(size);

  static TextStyle _textStyleFor(UiSize size, UiThemeTokens t) =>
      UiButtonMetrics.textStyle(size, t);

  static _ButtonStyle _resolveStyle(
    UiColorTokens c,
    UiIntent intent,
    UiPressableState state,
  ) {
    // Button-local alias: an unspecified button intent acts as the
    // primary call-to-action. Callers who want the pre-PR-A neutral
    // look must opt in via UiIntent.neutral.
    if (intent == UiIntent.defaultIntent) {
      intent = UiIntent.primary;
    }
    final isDarkTheme = c.background.computeLuminance() < 0.2;
    final palette = UiIntentPalette.rest(intent, c);
    _ButtonStyle base = _ButtonStyle(
      background: palette.background,
      foreground: palette.foreground,
      border: palette.border,
    );

    if (state.disabled) {
      return _ButtonStyle(
        background: base.background,
        foreground: base.foreground,
        border: base.border,
        opacity: 0.5,
      );
    }

    // Transparent intents (ghost/link) use an opacity step for press
    // feedback since darkening a fully-transparent color is a no-op.
    final isTransparent = base.background.a == 0;

    // Destructive: the base is a semi-transparent red wash, so press /
    // hover ramp the alpha of that wash rather than HSL-darkening a
    // translucent colour (which produces muddy results). Alpha steps
    // are picked per-theme so the wash stays readable on both light
    // and dark surfaces.
    if (intent == UiIntent.destructive || intent == UiIntent.danger) {
      final pressedAlpha = isDarkTheme ? 0.32 : 0.20;
      final hoveredAlpha = isDarkTheme ? 0.24 : 0.14;
      if (state.pressed) {
        return _ButtonStyle(
          background: c.danger.withValues(alpha: pressedAlpha),
          foreground: base.foreground,
          border: base.border,
        );
      }
      if (state.hovered) {
        return _ButtonStyle(
          background: c.danger.withValues(alpha: hoveredAlpha),
          foreground: base.foreground,
          border: base.border,
        );
      }
      return base;
    }

    if (state.pressed) {
      return _ButtonStyle(
        background: isTransparent
            ? c.accent.withValues(alpha: 0.6)
            : _shift(base.background, -0.08),
        foreground: base.foreground,
        border: base.border,
        opacity: isTransparent && intent == UiIntent.link ? 0.7 : 1.0,
      );
    }
    if (state.hovered) {
      return _ButtonStyle(
        background: isTransparent
            ? c.accent.withValues(alpha: 0.35)
            : _shift(base.background, -0.04),
        foreground: base.foreground,
        border: base.border,
      );
    }
    return base;
  }

  /// Darken ([amount] < 0) or lighten ([amount] > 0) a color by [amount]
  /// in [0,1]. Transparent colors are returned unchanged.
  static Color _shift(Color base, double amount) {
    if (base.a == 0) return base;
    final hsl = HSLColor.fromColor(base);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/// Shared sizing ratios used by [UiButton] and any other
/// trigger-shaped surface (selects, menu triggers, etc.).
///
/// Padding and border radius stay component-specific — shadcn uses
/// `h-9 px-4` on buttons but `h-9 px-3 rounded-md(-2px)` on selects,
/// so those two knobs are deliberately NOT exposed here. Height, icon
/// size, gap, and text metrics are the parts that should stay locked
/// together so a select and a button on the same row line up on the
/// same baseline at every [UiSize].
class UiButtonMetrics {
  UiButtonMetrics._();

  static double minHeight(UiSize size) {
    // Visual control height. Interactive widgets keep larger tap targets with
    // UiPressable.minTapSize instead of inflating the painted control.
    switch (size) {
      case UiSize.sm:
        return 32;
      case UiSize.md:
        return 36;
      case UiSize.lg:
        return 40;
    }
  }

  static double iconSize(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return 14;
      case UiSize.md:
        return 16;
      case UiSize.lg:
        return 18;
    }
  }

  static double gap(UiSize size, UiSpacingTokens spacing) {
    switch (size) {
      case UiSize.sm:
        return spacing.x1;
      case UiSize.md:
        return spacing.x2;
      case UiSize.lg:
        return spacing.x3;
    }
  }

  static UiTextVariant textVariant(UiSize size) {
    switch (size) {
      case UiSize.sm:
        return UiTextVariant.caption;
      case UiSize.md:
        return UiTextVariant.label;
      case UiSize.lg:
        return UiTextVariant.bodyLg;
    }
  }

  static TextStyle textStyle(UiSize size, UiThemeTokens t) {
    // Shadcn keeps all sizes in the same medium-weight sans; only the
    // sm variant drops to caption/xs. lg stays at label size — what
    // makes it feel "large" is the horizontal padding, not a bigger
    // font.
    switch (size) {
      case UiSize.sm:
        return t.typography.caption.copyWith(fontWeight: FontWeight.w500);
      case UiSize.md:
        return t.typography.label;
      case UiSize.lg:
        return t.typography.label.copyWith(fontWeight: FontWeight.w600);
    }
  }
}
