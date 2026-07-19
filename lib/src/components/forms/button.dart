import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/tokens/ui_color_tokens.dart';
import '../../foundation/tokens/ui_spacing_tokens.dart';

/// Visual intent for interactive components.
///
/// Neutral surfaces stay calm; brand colors surface on [UiIntent.primary]
/// / [UiIntent.secondary] / [UiIntent.destructive].
///
/// ### Button-specific semantics
///
/// For [UiButton], [UiIntent.defaultIntent] is treated as an alias of
/// [UiIntent.primary] — i.e. an unspecified button intent renders as
/// the primary call-to-action. To opt into the previous neutral /
/// outlined button look, use the explicit [UiIntent.neutral] variant.
///
/// This alias is button-local. [UiBadge] and [UiToast] still resolve
/// [UiIntent.defaultIntent] to a neutral surface — their "default" is
/// calm on purpose.
enum UiIntent {
  defaultIntent,

  /// Explicit neutral/outlined variant. Mirrors the button's pre-PR-A
  /// default look (surface fill + border, muted foreground). Use this
  /// when you want a low-emphasis button that visually recedes next to
  /// a primary action, or as the "Cancel" partner to a primary confirm.
  neutral,
  primary,
  secondary,
  destructive,
  danger,
  ghost,
  link,
}

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

/// Variant-driven button built on [UiPressable] + [UiBox] + [UiText].
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
  });

  final String label;
  final VoidCallback? onPressed;
  final UiIntent intent;
  final UiSize size;
  final Widget? leading;
  final Widget? trailing;
  final bool loading;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticsLabel;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final padding = _paddingFor(size, tokens.spacing);
    final minHeight = _minHeightFor(size);
    final radius = tokens.radius.mdAll;
    final textStyle = _textStyleFor(size, tokens);

    return UiPressable(
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
                  border: style.border != null
                      ? Border.all(color: style.border!, width: 1)
                      : null,
                  padding: padding,
                  alignment: Alignment.center,
                  width: expand ? double.infinity : null,
                  child: _content(context, style.foreground, textStyle, state),
                ),
              ),
            ),
          ),
        );
      },
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
        child: _Spinner(color: fg),
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

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: _controller.value * 6.2831853,
          child: CustomPaint(
            painter: _SpinnerPainter(widget.color),
            size: const Size.square(14),
          ),
        );
      },
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(1), -1.2, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter old) => old.color != color;
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

/// Rest-state colour trio shared between [UiButton] and other
/// intent-driven surfaces (notably [UiBadge]). Hover/press/disabled
/// ramps stay component-specific — they are behavioural, not purely
/// visual.
@immutable
class UiIntentPalette {
  const UiIntentPalette({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;

  /// Rest-state colours for [intent] against [c].
  ///
  /// Both [UiButton] and [UiBadge] read from this so adding a new
  /// intent — or tuning an existing one (e.g. the destructive tint
  /// alpha) — only happens in one place.
  static UiIntentPalette rest(UiIntent intent, UiColorTokens c) {
    final isDarkTheme = c.background.computeLuminance() < 0.2;
    switch (intent) {
      case UiIntent.primary:
        return UiIntentPalette(
          background: c.primary,
          foreground: c.onPrimary,
        );
      case UiIntent.secondary:
        return UiIntentPalette(
          background: c.secondary,
          foreground: c.onSecondary,
          border: c.border,
        );
      case UiIntent.destructive:
      case UiIntent.danger:
        return UiIntentPalette(
          background: c.danger.withValues(alpha: isDarkTheme ? 0.18 : 0.10),
          foreground: c.danger,
        );
      case UiIntent.ghost:
        return UiIntentPalette(
          background: const Color(0x00000000),
          foreground: c.accentForeground,
        );
      case UiIntent.link:
        return UiIntentPalette(
          background: const Color(0x00000000),
          foreground: c.primary,
        );
      case UiIntent.neutral:
      case UiIntent.defaultIntent:
        // Shared neutral/outlined palette.
        //
        // - For UiButton, `defaultIntent` is aliased to primary before
        //   this resolver runs, so this branch is reached only via
        //   `UiIntent.neutral` (explicit opt-in to the outlined look).
        // - For UiBadge / UiToast, `defaultIntent` still lands here so
        //   their calm neutral default is preserved.
        if (isDarkTheme) {
          return UiIntentPalette(
            background: c.surface.withValues(alpha: 0.62),
            foreground: Color.lerp(c.mutedForeground, c.foreground, 0.55)!,
            border: c.borderStrong.withValues(alpha: 0.9),
          );
        }
        return UiIntentPalette(
          background: c.surface,
          foreground: c.foreground,
          border: c.border,
        );
    }
  }
}
