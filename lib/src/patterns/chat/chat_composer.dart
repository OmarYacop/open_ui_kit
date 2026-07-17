import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../components/forms/button.dart';
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
    this.leading,
    this.maxLines = 6,
  });

  final ValueChanged<String> onSend;
  final TextEditingController? controller;
  final String hint;
  final bool disabled;
  final bool loading;
  final Widget? leading;
  final int maxLines;

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
      widget.controller?.addListener(_update);
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
      background: c.surface,
      border: Border(top: BorderSide(color: c.border, width: 1)),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x3,
        vertical: tokens.spacing.x2,
      ),
      child: Row(
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
                  hint: widget.hint,
                  enabled: !widget.disabled,
                  maxLines: widget.maxLines,
                  minLines: _visualLines,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                );
              },
            ),
          ),
          SizedBox(width: tokens.spacing.x2),
          UiButton(
            label: 'Send',
            intent: UiIntent.primary,
            loading: widget.loading,
            onPressed: widget.disabled || !_canSend ? null : _submit,
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
