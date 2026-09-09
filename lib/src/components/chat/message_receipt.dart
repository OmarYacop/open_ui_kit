import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_focus_ring.dart';

/// Presentation state only. The application derives delivery from its transport.
enum UiMessageDeliveryStatus { sending, sent, delivered, read, failed }

/// A compact timestamp and accessible delivery receipt, with optional recovery.
///
/// Place outside a bubble by default. When embedded in a colored bubble, pass
/// its foreground via [foregroundColor] and [readColor]. Labels are caller
/// overridable for localization. A retry action only appears for failed sends.
class UiMessageReceipt extends StatelessWidget {
  const UiMessageReceipt({
    super.key,
    this.timestamp,
    this.status,
    this.statusLabel,
    this.showStatusLabel = false,
    this.editedLabel,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.foregroundColor,
    this.readColor,
  });

  final String? timestamp;
  final UiMessageDeliveryStatus? status;
  final String? statusLabel;
  final bool showStatusLabel;
  final String? editedLabel;
  final VoidCallback? onRetry;
  final String retryLabel;
  final Color? foregroundColor;
  final Color? readColor;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final failed = status == UiMessageDeliveryStatus.failed;
    final label = status == null
        ? null
        : statusLabel ??
              switch (status!) {
                UiMessageDeliveryStatus.sending => 'Sending',
                UiMessageDeliveryStatus.sent => 'Sent',
                UiMessageDeliveryStatus.delivered => 'Delivered',
                UiMessageDeliveryStatus.read => 'Read',
                UiMessageDeliveryStatus.failed => 'Failed to send',
              };
    final color = foregroundColor ?? tokens.colors.textMuted;
    final statusColor = failed
        ? tokens.colors.danger
        : status == UiMessageDeliveryStatus.read
        ? readColor ?? tokens.colors.primary
        : color;
    final icon = switch (status) {
      UiMessageDeliveryStatus.sending => LucideIcons.clock,
      UiMessageDeliveryStatus.sent => LucideIcons.check,
      UiMessageDeliveryStatus.delivered ||
      UiMessageDeliveryStatus.read => LucideIcons.checkCheck,
      UiMessageDeliveryStatus.failed => LucideIcons.circleAlert,
      null => null,
    };
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.x2,
      runSpacing: tokens.spacing.x1,
      children: [
        if (timestamp != null || editedLabel != null)
          UiText(
            [editedLabel, timestamp].whereType<String>().join(' · '),
            variant: UiTextVariant.caption,
            style: TextStyle(color: color),
          ),
        if (icon != null)
          Semantics(
            label: label,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: statusColor),
                  if (showStatusLabel || (failed && onRetry == null)) ...[
                    SizedBox(width: tokens.spacing.x1),
                    Flexible(
                      child: UiText(
                        label!,
                        variant: UiTextVariant.caption,
                        style: TextStyle(color: statusColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (failed && onRetry != null)
          UiPressable(
            onPressed: onRetry,
            semanticsLabel: retryLabel,
            minTapSize: 32,
            builder: (_, state, child) => UiFocusRing(
              visible: state.focused,
              child: Opacity(opacity: state.pressed ? .65 : 1, child: child),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.rotateCcw, size: 13, color: statusColor),
                  SizedBox(width: tokens.spacing.x1),
                  UiText(
                    retryLabel,
                    variant: UiTextVariant.caption,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
