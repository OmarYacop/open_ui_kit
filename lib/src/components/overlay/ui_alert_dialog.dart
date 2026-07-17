import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart';

/// Intent for the confirm action in a [UiAlertDialog].
///
/// Controls the styling of the confirm button only — the cancel
/// button always renders as a ghost button. Matches shadcn's
/// `AlertDialog` pattern where the "Action" surface is restyled based
/// on severity (neutral vs. destructive).
enum UiAlertDialogIntent {
  /// Neutral confirm (default).
  defaultIntent,

  /// Red "Delete"-style confirm. Use for data-loss operations.
  destructive,

  /// Amber "Proceed"-style confirm. Use for recoverable warnings.
  warning,
}

/// A single modal alert — shadcn's `AlertDialog` ported.
///
/// Key differences from [UiDialog] / [UiDialogScope.confirm]:
///
/// - **Not barrier-dismissible by default** — alert dialogs force the
///   user to pick one of the actions. Tapping outside does nothing
///   (override with `barrierDismissible: true` if you need to).
/// - **Structured API** — `title` + `description` + `confirmLabel` +
///   `cancelLabel` + `intent`. No free-form `content` slot.
/// - **Destructive variant** — `intent: UiAlertDialogIntent.destructive`
///   renders the confirm button in `danger` so the severity is
///   obvious before the user taps.
/// - **Semantics** — the dialog is wrapped in an `alertdialog`-shaped
///   `Semantics` node so assistive tech announces it as such.
///
/// For plain information or form dialogs keep using [UiDialog].
class UiAlertDialog extends StatelessWidget {
  const UiAlertDialog({
    super.key,
    required this.title,
    this.description,
    this.confirmLabel = 'Continue',
    this.cancelLabel = 'Cancel',
    this.intent = UiAlertDialogIntent.defaultIntent,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final UiAlertDialogIntent intent;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    final confirmIntent = switch (intent) {
      UiAlertDialogIntent.destructive => UiIntent.destructive,
      UiAlertDialogIntent.warning => UiIntent.primary,
      UiAlertDialogIntent.defaultIntent => UiIntent.primary,
    };

    return Semantics(
      container: true,
      namesRoute: true,
      scopesRoute: true,
      label: 'Alert. $title${description == null ? '' : '. $description'}',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: UiBox(
            background: c.card,
            border: Border.all(color: c.border),
            borderRadius: tokens.radius.lgAll,
            padding: EdgeInsets.all(tokens.spacing.x6),
            boxShadow: tokens.shadows.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiText(title, variant: UiTextVariant.heading),
                if (description != null) ...[
                  SizedBox(height: tokens.spacing.x2),
                  UiText(
                    description!,
                    variant: UiTextVariant.body,
                    tone: UiTextTone.muted,
                  ),
                ],
                SizedBox(height: tokens.spacing.x6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    UiButton(
                      label: cancelLabel,
                      intent: UiIntent.ghost,
                      onPressed: onCancel,
                    ),
                    SizedBox(width: tokens.spacing.x2),
                    UiButton(
                      label: confirmLabel,
                      intent: confirmIntent,
                      onPressed: onConfirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Imperative helpers for presenting [UiAlertDialog].
class UiAlertDialogScope {
  UiAlertDialogScope._();

  /// Present an alert dialog and resolve with:
  /// - `true` → user tapped the confirm action.
  /// - `false` → user tapped the cancel action.
  /// - `null` → the dialog was dismissed via system back / Escape.
  ///
  /// Barrier-dismissal is **off by default** to match shadcn's
  /// `AlertDialog` behaviour. Pass `barrierDismissible: true` only when
  /// the action is trivially reversible.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? description,
    String confirmLabel = 'Continue',
    String cancelLabel = 'Cancel',
    UiAlertDialogIntent intent = UiAlertDialogIntent.defaultIntent,
    bool barrierDismissible = false,
  }) {
    final tokens = UiThemeTokens.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    return navigator.push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: barrierDismissible,
        barrierColor: const Color(0x00000000),
        transitionDuration: tokens.motion.fast,
        reverseTransitionDuration: tokens.motion.fast,
        pageBuilder: (ctx, animation, __) => _AlertDialogHost(
          animation: animation,
          barrierColor: _alertDialogBarrierColor(tokens),
          child: UiAlertDialog(
            title: title,
            description: description,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            intent: intent,
            onConfirm: () => Navigator.of(ctx).maybePop(true),
            onCancel: () => Navigator.of(ctx).maybePop(false),
          ),
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  /// Shorthand for the common delete-confirmation case. Equivalent to
  /// `show(intent: destructive, confirmLabel: 'Delete', ...)`.
  static Future<bool?> destructive(
    BuildContext context, {
    required String title,
    String? description,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
  }) {
    return show(
      context,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      intent: UiAlertDialogIntent.destructive,
    );
  }
}

class _AlertDialogHost extends StatelessWidget {
  const _AlertDialogHost({
    required this.animation,
    required this.barrierColor,
    required this.child,
  });

  final Animation<double> animation;
  final Color barrierColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic.flipped,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        _AlertDialogBackdrop(animation: curved, color: barrierColor),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertDialogBackdrop extends StatelessWidget {
  const _AlertDialogBackdrop({
    required this.animation,
    required this.color,
  });

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Static blur sigma, animated scrim opacity. Avoids rebuilding the
    // ImageFilter every frame during the route transition.
    return IgnorePointer(
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: animation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

Color _alertDialogBarrierColor(UiThemeTokens tokens) {
  return tokens.colors.overlay.withValues(
    alpha: tokens.brightness == Brightness.dark ? 0.38 : 0.30,
  );
}
