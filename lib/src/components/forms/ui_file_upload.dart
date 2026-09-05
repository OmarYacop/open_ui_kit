import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// File-selection / dropzone display control.
///
/// open_ui_kit deliberately ships no file-picking dependency, so
/// [UiFileUpload] never touches the platform file system itself — it is
/// purely presentational and callback-driven. Wire [onTap] to the host app's
/// own picker (e.g. the `file_picker` package) and feed the result back in
/// via [fileName]/[fileSizeLabel]; [onClear] lets the host discard the
/// current selection. There is no real OS drag-and-drop here either — the
/// dashed border and upload icon only make the control *read* as a
/// dropzone, with [onTap] as the sole interaction.
///
/// Mirrors [UiCheckbox]/[UiInput]'s label/helper/errorText slots: validation
/// (file size, type, …) is the host's responsibility, surfaced here only as
/// [errorText].
class UiFileUpload extends StatelessWidget {
  const UiFileUpload({
    super.key,
    this.onTap,
    this.fileName,
    this.fileSizeLabel,
    this.onClear,
    this.label,
    this.helper,
    this.errorText,
    this.enabled = true,
    this.loading = false,
    this.accept,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  /// Invoked when the dropzone is tapped. Wire this to the host app's own
  /// file picker — [UiFileUpload] never opens one itself. A null value
  /// disables the control.
  final VoidCallback? onTap;

  /// Name of the currently selected file, pre-resolved by the host.
  final String? fileName;

  /// Pre-formatted file size (e.g. "2.4 MB"). This component does no byte
  /// formatting itself.
  final String? fileSizeLabel;

  /// Invoked when the remove affordance on a selected file is pressed.
  /// Only shown once [fileName] is set.
  final VoidCallback? onClear;
  final String? label;
  final String? helper;
  final String? errorText;
  final bool enabled;

  /// Whether an upload is in flight. Disables interaction and switches the
  /// dropzone to a subdued, busy tone.
  final bool loading;

  /// Human-readable hint of accepted files (e.g. "PNG, JPG up to 5MB"),
  /// shown inside the empty dropzone beneath the primary label.
  final String? accept;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Overrides the generated Semantics label describing the current state.
  final String? semanticLabel;

  bool get _hasFile => fileName != null && fileName!.isNotEmpty;

  bool get _interactive => enabled && !loading && onTap != null;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final stateLabel = _hasFile
        ? '$fileName${fileSizeLabel != null ? ', $fileSizeLabel' : ''} selected'
        : 'No file chosen';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          UiText(
            label!,
            variant: UiTextVariant.label,
            tone: enabled ? UiTextTone.primary : UiTextTone.muted,
          ),
          SizedBox(height: tokens.spacing.x1),
        ],
        Semantics(
          button: true,
          enabled: _interactive,
          label: semanticLabel ?? stateLabel,
          hint: loading
              ? 'loading'
              : !_interactive
              ? 'disabled'
              : null,
          onTap: _interactive ? onTap : null,
          child: UiPressable(
            enabled: _interactive,
            onPressed: onTap,
            focusNode: focusNode,
            autofocus: autofocus,
            minTapSize: 0,
            excludeFromSemantics: true,
            builder: (context, state, _) {
              final borderColor = hasError
                  ? c.destructive
                  : state.focused
                  ? c.ring
                  : c.input;
              final background = !enabled || loading
                  ? c.muted
                  : _hasFile
                  ? c.surface
                  : c.muted;

              final body = Padding(
                padding: EdgeInsets.all(tokens.spacing.x4),
                child: _hasFile
                    ? _SelectedFile(
                        fileName: fileName!,
                        fileSizeLabel: fileSizeLabel,
                        onClear: (enabled && !loading) ? onClear : null,
                      )
                    : _EmptyDropzone(accept: accept, loading: loading),
              );

              return UiFocusRing(
                visible: state.focused && !hasError,
                borderRadius: tokens.radius.mdAll,
                child: _hasFile
                    ? UiBox(
                        background: background,
                        border: Border.all(color: borderColor, width: 1),
                        borderRadius: tokens.radius.mdAll,
                        child: body,
                      )
                    : _DashedBorderBox(
                        color: borderColor,
                        background: background,
                        borderRadius: tokens.radius.md,
                        child: body,
                      ),
              );
            },
          ),
        ),
        if (hasError) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            errorText!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.danger,
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

class _EmptyDropzone extends StatelessWidget {
  const _EmptyDropzone({required this.accept, required this.loading});

  final String? accept;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.upload,
          size: 20,
          color: loading ? c.mutedForeground : c.textMuted,
        ),
        SizedBox(height: tokens.spacing.x2),
        UiText(
          loading ? 'Uploading…' : 'Tap to choose a file',
          variant: UiTextVariant.label,
          tone: loading ? UiTextTone.muted : UiTextTone.primary,
        ),
        if (accept != null && !loading) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            accept!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _SelectedFile extends StatelessWidget {
  const _SelectedFile({
    required this.fileName,
    required this.fileSizeLabel,
    required this.onClear,
  });

  final String fileName;
  final String? fileSizeLabel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(LucideIcons.file, size: 18, color: c.textMuted),
        SizedBox(width: tokens.spacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              UiText(
                fileName,
                variant: UiTextVariant.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (fileSizeLabel != null)
                UiText(
                  fileSizeLabel!,
                  variant: UiTextVariant.caption,
                  tone: UiTextTone.muted,
                ),
            ],
          ),
        ),
        if (onClear != null) ...[
          SizedBox(width: tokens.spacing.x2),
          UiPressable(
            onPressed: onClear,
            minTapSize: 32,
            semanticsLabel: 'Remove $fileName',
            builder: (context, state, _) {
              final iconColor = state.hovered || state.pressed
                  ? c.foreground
                  : c.textMuted;
              return Icon(LucideIcons.x, size: 16, color: iconColor);
            },
          ),
        ],
      ],
    );
  }
}

/// Minimal, file-local dashed rounded-rect border.
///
/// open_ui_kit has no shared dashed-border primitive; kept private here
/// rather than promoted to a reusable primitive for a single caller.
class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    required this.color,
    required this.background,
    required this.borderRadius,
  });

  final Widget child;
  final Color color;
  final Color background;
  final Radius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      // Painted in the foreground: the child below fills the box edge to
      // edge with an opaque background, so a background painter would be
      // fully hidden by it.
      foregroundPainter: _DashedRRectPainter(
        color: color,
        radius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(borderRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(color: background),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final Radius radius;

  static const double strokeWidth = 1.5;
  static const double dashWidth = 5;
  static const double dashGap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height).deflate(strokeWidth / 2),
      radius,
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
