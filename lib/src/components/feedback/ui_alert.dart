import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Intent model for the inline [UiAlert] banner.
///
/// Mirrors shadcn's `Alert` variants (`default`, `destructive`) and
/// adds three common ones (`warning`, `success`, `info`) that apps
/// routinely reach for. Colours stay token-driven — the intent picks
/// which token family drives the tint + border.
enum UiAlertIntent {
  /// Neutral tone — muted surface + border.
  defaultIntent,

  /// Red-tinted tone for errors / destructive context.
  destructive,

  /// Amber-tinted tone for soft warnings.
  warning,

  /// Green-tinted tone for success confirmations.
  success,

  /// Neutral tone with an accent stroke — useful for informational
  /// callouts that aren't warnings or successes.
  info,
}

/// Inline alert banner.
///
/// Shadcn-aligned: a full-width card with an optional leading icon, a
/// title, and a description. Intent drives colour — `destructive`
/// renders red-on-red, `success` renders green-on-green, etc.
///
/// Use [UiAlertDialog] for *modal* alerts that force a decision. Use
/// [UiAlert] for inline notices that live in page content.
class UiAlert extends StatelessWidget {
  const UiAlert({
    super.key,
    this.title,
    this.description,
    this.leading,
    this.actions = const <Widget>[],
    this.intent = UiAlertIntent.defaultIntent,
  });

  /// Short banner headline. Rendered bold above the description.
  final String? title;

  /// Secondary copy below the title.
  final String? description;

  /// Optional leading glyph — typically an icon. Tinted to match intent.
  final Widget? leading;

  /// Optional trailing actions row (e.g. "Dismiss" / "Retry" buttons).
  final List<Widget> actions;

  final UiAlertIntent intent;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    final (bg, fg, borderColor) = switch (intent) {
      UiAlertIntent.destructive => (
          c.danger.withValues(alpha: 0.08),
          c.danger,
          c.danger.withValues(alpha: 0.35),
        ),
      UiAlertIntent.warning => (
          c.warning.withValues(alpha: 0.10),
          c.warning,
          c.warning.withValues(alpha: 0.35),
        ),
      UiAlertIntent.success => (
          c.success.withValues(alpha: 0.10),
          c.success,
          c.success.withValues(alpha: 0.35),
        ),
      UiAlertIntent.info => (c.surfaceMuted, c.textPrimary, c.border),
      UiAlertIntent.defaultIntent => (
          c.surfaceMuted,
          c.textPrimary,
          c.border,
        ),
    };

    // Title colour: tinted for coloured intents, neutral otherwise.
    final titleColor = switch (intent) {
      UiAlertIntent.destructive ||
      UiAlertIntent.warning ||
      UiAlertIntent.success =>
        fg,
      _ => c.textPrimary,
    };

    return Semantics(
      container: true,
      liveRegion: intent == UiAlertIntent.destructive ||
          intent == UiAlertIntent.warning,
      label: _semanticsLabel(),
      child: UiBox(
        background: bg,
        border: Border.all(color: borderColor),
        borderRadius: tokens.radius.lgAll,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.x4,
          vertical: tokens.spacing.x3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: fg, size: 18),
                child: leading!,
              ),
              SizedBox(width: tokens.spacing.x3),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    UiText(
                      title!,
                      variant: UiTextVariant.label,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (title != null && description != null)
                    SizedBox(height: tokens.spacing.x1),
                  if (description != null)
                    UiText(
                      description!,
                      variant: UiTextVariant.bodySm,
                      style: TextStyle(
                        color: intent == UiAlertIntent.defaultIntent ||
                                intent == UiAlertIntent.info
                            ? c.textMuted
                            : fg,
                      ),
                    ),
                  if (actions.isNotEmpty) ...[
                    SizedBox(height: tokens.spacing.x2),
                    Wrap(
                      spacing: tokens.spacing.x2,
                      runSpacing: tokens.spacing.x2,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _semanticsLabel() {
    if (title == null && description == null) return null;
    final prefix = switch (intent) {
      UiAlertIntent.destructive => 'Error: ',
      UiAlertIntent.warning => 'Warning: ',
      UiAlertIntent.success => 'Success: ',
      UiAlertIntent.info => 'Info: ',
      UiAlertIntent.defaultIntent => '',
    };
    final parts = [
      if (title != null) title!,
      if (description != null) description!,
    ];
    return '$prefix${parts.join(' — ')}';
  }
}
