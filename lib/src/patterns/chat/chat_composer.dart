import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/forms/button.dart';
import '../../components/forms/icon_button.dart';
import '../../components/forms/input.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Chat input row with attachment slot and send action.
class UiChatComposer extends StatefulWidget {
  const UiChatComposer({
    super.key,
    required this.onSend,
    this.controller,
    this.hint = 'Message…',
    this.disabled = false,
    this.loading = false,
    this.header,
    this.leading,
    this.focusNode,
    this.onChanged,
    this.sendLabel = 'Send',
    this.compactSendAction = false,
    this.submitOnKeyboardAction = true,
    this.textInputAction = TextInputAction.send,
    this.maxLines = 6,
    this.floating = false,
  });

  final ValueChanged<String> onSend;
  final TextEditingController? controller;
  final String hint;
  final bool disabled;
  final bool loading;
  final Widget? header;
  final Widget? leading;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String sendLabel;
  final bool compactSendAction;
  final bool submitOnKeyboardAction;
  final TextInputAction textInputAction;
  final int maxLines;

  /// Removes the shared toolbar surface so the input and actions read as
  /// independent floating islands above a page edge fade.
  final bool floating;

  @override
  State<UiChatComposer> createState() => _UiChatComposerState();
}

class _UiChatComposerState extends State<UiChatComposer> {
  TextEditingController? _own;
  bool _canSend = false;
  int _visualLines = 1;
  double _inputWidth = 0;

  TextEditingController get _ctrl =>
      widget.controller ??
      (_own ??= TextEditingController()..addListener(_update));

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller!.addListener(_update);
    } else {
      // Force lazy init so our listener is attached.
      _ctrl;
    }
    _canSend = _ctrl.text.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(covariant UiChatComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_update);
      if (old.controller == null && widget.controller != null) {
        _own?.removeListener(_update);
        _own?.dispose();
        _own = null;
      }
      if (widget.controller != null) {
        widget.controller!.addListener(_update);
      } else {
        _ctrl;
      }
      _canSend = _ctrl.text.trim().isNotEmpty;
      _visualLines = _estimateVisualLines();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_update);
    _own?.removeListener(_update);
    _own?.dispose();
    super.dispose();
  }

  void _update() {
    final can = _ctrl.text.trim().isNotEmpty;
    final lines = _estimateVisualLines();
    if (can != _canSend || lines != _visualLines) {
      setState(() {
        _canSend = can;
        _visualLines = lines;
      });
    }
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;

    return UiBox(
      background: widget.floating ? const Color(0x00000000) : c.surface,
      border: widget.floating
          ? null
          : Border(top: BorderSide(color: c.border, width: 1)),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x3,
        vertical: tokens.spacing.x2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.header != null) ...[
            widget.header!,
            SizedBox(height: tokens.spacing.x2),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                SizedBox(width: tokens.spacing.x2),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth != _inputWidth) {
                      _inputWidth = constraints.maxWidth;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _update();
                      });
                    }
                    return UiInput(
                      controller: _ctrl,
                      focusNode: widget.focusNode,
                      hint: widget.hint,
                      enabled: !widget.disabled,
                      maxLines: widget.maxLines,
                      minLines: _visualLines,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.submitOnKeyboardAction
                          ? (_) => _submit()
                          : null,
                      textInputAction: widget.textInputAction,
                    );
                  },
                ),
              ),
              SizedBox(width: tokens.spacing.x2),
              if (widget.compactSendAction)
                UiIconButton(
                  icon: const Icon(LucideIcons.send),
                  semanticsLabel: widget.sendLabel,
                  intent: UiIntent.primary,
                  borderRadius: tokens.radius.pillAll,
                  onPressed: widget.disabled || widget.loading || !_canSend
                      ? null
                      : _submit,
                )
              else
                UiButton(
                  label: widget.sendLabel,
                  intent: UiIntent.primary,
                  loading: widget.loading,
                  onPressed: widget.disabled || !_canSend ? null : _submit,
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _estimateVisualLines() {
    final text = _ctrl.text;
    if (text.isEmpty) return 1;

    final hardLines = '\n'.allMatches(text).length + 1;
    if (!mounted || _inputWidth <= 0) {
      return hardLines.clamp(1, widget.maxLines);
    }

    final tokens = UiThemeTokens.of(context);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: tokens.typography.body,
      ),
      textDirection: Directionality.of(context),
      maxLines: widget.maxLines,
    )..layout(maxWidth: _inputWidth);

    final wrappedLines = textPainter.computeLineMetrics().length;
    final lines = math.max(hardLines, wrappedLines);
    return lines.clamp(1, widget.maxLines);
  }
}
