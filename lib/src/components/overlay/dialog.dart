import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart';

/// Modal dialog surface.
class UiDialog extends StatelessWidget {
  const UiDialog({
    super.key,
    this.title,
    this.description,
    this.content,
    this.actions = const [],
  });

  final String? title;
  final String? description;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: UiBox(
          background: c.card,
          border: Border.all(color: c.border),
          borderRadius: tokens.radius.xlAll,
          padding: EdgeInsets.all(tokens.spacing.x6),
          boxShadow: tokens.shadows.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) UiText(title!, variant: UiTextVariant.heading),
              if (description != null) ...[
                SizedBox(height: tokens.spacing.x2),
                UiText(
                  description!,
                  variant: UiTextVariant.body,
                  tone: UiTextTone.muted,
                ),
              ],
              if (content != null) ...[
                SizedBox(height: tokens.spacing.x4),
                content!,
              ],
              if (actions.isNotEmpty) ...[
                SizedBox(height: tokens.spacing.x6),
                Row(
                  key: const ValueKey('ui-dialog-actions'),
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) SizedBox(width: tokens.spacing.x3),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Imperative helpers for showing a [UiDialog].
class UiDialogScope {
  UiDialogScope._();

  /// Shows [builder] inside a dismissible overlay. Resolves with whatever
  /// is passed to `Navigator.maybePop` from within the dialog, or `null`
  /// if the scrim was tapped.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool useRootNavigator = true,
  }) {
    final tokens = UiThemeTokens.of(context);
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    return navigator.push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierDismissible: barrierDismissible,
        barrierColor: const Color(0x00000000),
        transitionDuration: tokens.motion.standard,
        reverseTransitionDuration: tokens.motion.standard,
        pageBuilder: (ctx, animation, __) => _DialogHost(
          animation: animation,
          barrierColor: _dialogBarrierColor(tokens),
          child: InheritedTheme.captureAll(
            context,
            Builder(builder: builder),
          ),
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  /// Two-button confirmation prompt.
  ///
  /// Returns `true` if the user pressed the confirm action, `false` if
  /// they pressed the cancel action, and `null` if the dialog was
  /// dismissed (backdrop tap, back gesture, or any other
  /// `Navigator.pop` without a value). Callers that only care about
  /// confirmation can treat `null` like `false`, but treating them
  /// separately lets you distinguish "user said no" from "user never
  /// decided".
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? description,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    UiIntent confirmIntent = UiIntent.primary,
  }) {
    return show<bool>(
      context,
      builder: (ctx) => UiDialog(
        title: title,
        description: description,
        actions: [
          UiButton(
            label: cancelLabel,
            intent: UiIntent.ghost,
            onPressed: () => Navigator.of(ctx).maybePop(false),
          ),
          UiButton(
            label: confirmLabel,
            intent: confirmIntent,
            onPressed: () => Navigator.of(ctx).maybePop(true),
          ),
        ],
      ),
    );
  }
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({
    required this.animation,
    required this.barrierColor,
    required this.child,
  });

  final Animation<double> animation;
  final Color barrierColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = UiThemeTokens.of(context).motion;
    final curved = CurvedAnimation(
      parent: animation,
      curve: motion.standardCurve,
      reverseCurve: motion.standardCurve.flipped,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        _DialogBackdrop(animation: curved, color: barrierColor),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: UiFadeScaleTransition(
              animation: curved,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogBackdrop extends StatelessWidget {
  const _DialogBackdrop({
    required this.animation,
    required this.color,
  });

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Keep the blur filter static so its shader doesn't rebuild every
    // frame. Animate the scrim+blur layer via opacity instead — the
    // route animation fades the whole subtree in/out, the compositor
    // can skip it entirely at opacity 0.
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

Color _dialogBarrierColor(UiThemeTokens tokens) {
  return tokens.colors.overlay.withValues(
    alpha: tokens.brightness == Brightness.dark ? 0.38 : 0.30,
  );
}
