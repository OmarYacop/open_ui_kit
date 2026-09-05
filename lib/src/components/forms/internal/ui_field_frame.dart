import 'package:flutter/widgets.dart';

import '../../../foundation/intl/ui_localizations.dart';
import '../../../foundation/primitives/ui_text.dart';
import '../../../foundation/theme/ui_theme_extensions.dart';

/// Internal composition shared by field controls. The child owns input and focus.
class UiFieldFrame extends StatelessWidget {
  const UiFieldFrame({
    super.key,
    required this.child,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.labelSpacing,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });
  final Widget child;
  final String? label;
  final String? helper;
  final String? errorText;
  final bool enabled;
  final double? labelSpacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final error = errorText;
    final hasError = error != null && error.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (label != null) ...[
          UiText(
            label!,
            variant: UiTextVariant.label,
            tone: enabled ? UiTextTone.primary : UiTextTone.muted,
          ),
          SizedBox(height: labelSpacing ?? tokens.spacing.x1),
        ],
        child,
        if (hasError) ...[
          SizedBox(height: tokens.spacing.x1),
          Semantics(
            liveRegion: true,
            container: true,
            label: '${UiLocalizations.of(context).alertError}: $error',
            child: ExcludeSemantics(
              child: UiText(
                error,
                variant: UiTextVariant.caption,
                tone: UiTextTone.danger,
              ),
            ),
          ),
        ] else if (helper != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            helper!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
          ),
        ],
      ],
    );
  }
}
