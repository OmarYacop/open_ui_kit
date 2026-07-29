import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

enum UiMarkerVariant { inline, border, separator }

class UiMarker extends StatelessWidget {
  const UiMarker({
    super.key,
    required this.label,
    this.icon,
    this.variant = UiMarkerVariant.inline,
    this.onPressed,
    this.semanticLabel,
    this.liveRegion = false,
  });

  final String label;
  final Widget? icon;
  final UiMarkerVariant variant;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final content = Row(
      mainAxisSize: variant == UiMarkerVariant.separator
          ? MainAxisSize.max
          : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (variant == UiMarkerVariant.separator)
          Expanded(child: _line(tokens.colors.border)),
        if (variant == UiMarkerVariant.separator)
          SizedBox(width: tokens.spacing.x3),
        if (icon != null) ...[
          ExcludeSemantics(
            child: IconTheme.merge(
              data: IconThemeData(size: 16, color: tokens.colors.textMuted),
              child: icon!,
            ),
          ),
          SizedBox(width: tokens.spacing.x2),
        ],
        Flexible(
          child: UiText(
            label,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
            textAlign: TextAlign.center,
          ),
        ),
        if (variant == UiMarkerVariant.separator)
          SizedBox(width: tokens.spacing.x3),
        if (variant == UiMarkerVariant.separator)
          Expanded(child: _line(tokens.colors.border)),
      ],
    );

    Widget result = UiBox(
      border: variant == UiMarkerVariant.border
          ? Border(bottom: BorderSide(color: tokens.colors.border))
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x3,
        vertical: tokens.spacing.x2,
      ),
      child: content,
    );
    if (onPressed != null) {
      result = UiPressable(
        onPressed: onPressed,
        semanticsLabel: semanticLabel ?? label,
        minTapSize: 44,
        builder: (_, state, child) => Opacity(
          opacity: state.pressed ? .7 : 1,
          child: child!,
        ),
        child: result,
      );
    }
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: onPressed == null ? semanticLabel : null,
      child: result,
    );
  }

  Widget _line(Color color) => UiBox(height: 1, background: color);
}
