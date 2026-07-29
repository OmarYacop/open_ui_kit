import 'package:flutter/cupertino.dart' show cupertinoTextSelectionControls;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, materialTextSelectionControls;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_text.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiSize, UiButtonMetrics;

typedef UiInputValidator = String? Function(String value);

enum UiInputVariant {
  standard,

  /// Removes the input's own surface, border, and focus ring so a parent
  /// control can own the complete visual container.
  embedded,
}

/// Text input component.
///
/// Exposes the usual controller/value knobs plus label/hint/error slots so
/// forms can opt into structured layouts without reimplementing them.
class UiInput extends StatefulWidget {
  const UiInput({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.size = UiSize.lg,
    this.leading,
    this.trailing,
    this.variant = UiInputVariant.standard,
  }) : assert(
          controller == null || initialValue == null,
          'Provide controller OR initialValue, not both.',
        );

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final UiInputValidator? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final UiSize size;
  final Widget? leading;
  final Widget? trailing;
  final UiInputVariant variant;

  @override
  State<UiInput> createState() => UiInputState();
}

class UiInputState extends State<UiInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  String? _internalError;
  bool _focused = false;

  // A bare EditableText has no tap-to-focus / open-keyboard / caret-positioning
  // gestures (those live in TextField). Without this the field appears to focus
  // but shows no cursor and can't be typed into. Wiring a
  // TextSelectionGestureDetectorBuilder (keyed to the EditableText) restores the
  // full TextField gesture behaviour: tap to focus + place caret, double-tap /
  // long-press to select, drag to extend.
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  late final TextSelectionGestureDetectorBuilder _selectionGestureBuilder;

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool get selectionEnabled => widget.enabled;

  TextEditingController get _controller =>
      widget.controller ??
      (_ownController ??=
          TextEditingController(text: widget.initialValue ?? ''));

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  String? get errorText => widget.errorText ?? _internalError;

  bool _lastEmpty = true;

  @override
  void initState() {
    super.initState();
    _selectionGestureBuilder =
        TextSelectionGestureDetectorBuilder(delegate: this);
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
    _lastEmpty = _controller.text.isEmpty;
  }

  @override
  void didUpdateWidget(covariant UiInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      final previousController = oldWidget.controller ?? _ownController;
      previousController?.removeListener(_handleTextChange);
      if (oldWidget.controller == null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _controller.addListener(_handleTextChange);
      _lastEmpty = _controller.text.isEmpty;
    }

    if (oldWidget.focusNode != widget.focusNode) {
      final previousFocusNode = oldWidget.focusNode ?? _ownFocusNode;
      previousFocusNode?.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) {
        _ownFocusNode?.dispose();
        _ownFocusNode = null;
      }
      _focusNode.addListener(_handleFocusChange);
      _focused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final empty = _controller.text.isEmpty;
    if (empty != _lastEmpty) {
      setState(() => _lastEmpty = empty);
    }
  }

  void _handleFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  /// Runs [UiInput.validator] and returns whether the value is valid.
  bool validate() {
    final v = widget.validator;
    if (v == null) return true;
    final err = v(_controller.text);
    setState(() => _internalError = err);
    return err == null;
  }

  void _onChanged(String value) {
    if (_internalError != null) {
      setState(() => _internalError = null);
    }
    widget.onChanged?.call(value);
  }

  Widget _buildTappable({required bool disabled, required Widget child}) {
    if (disabled) return child;
    return _selectionGestureBuilder.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final error = errorText;
    final hasError = error != null && error.isNotEmpty;
    final disabled = !widget.enabled;
    final padding = _paddingFor(widget.size, tokens, widget.maxLines);

    // Focus ring is suppressed when the field cannot accept input, so
    // disabled/read-only rows stay visually quiet.
    final canFocus = !disabled && !widget.readOnly;
    final ringActive = _focused && canFocus;
    final embedded = widget.variant == UiInputVariant.embedded;
    // Keep the resting border stable and add a low-opacity one-pixel focus
    // ring. This preserves shadcn-style focus visibility without producing a
    // high-contrast double outline in light or dark mode.
    final borderColor = hasError ? c.destructive : c.input;

    final bg = disabled ? c.muted : c.surface;
    final textColor = disabled ? c.mutedForeground : c.foreground;
    final inputFormatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(widget.maxLength),
    ];

    final effectiveReadOnly = widget.readOnly || disabled;
    final field = EditableText(
      key: _editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      style: tokens.typography.body.copyWith(color: textColor),
      cursorColor: c.primary,
      backgroundCursorColor: c.input,
      selectionColor: c.primary.withValues(alpha: 0.18),
      keyboardType: widget.keyboardType ?? TextInputType.text,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscureText,
      readOnly: effectiveReadOnly,
      // Hide the blinking caret on disabled fields; read-only with
      // selection still benefits from a caret so users know where
      // a selection anchor sits.
      showCursor: !disabled,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      inputFormatters: inputFormatters,
      onChanged: _onChanged,
      onSubmitted: widget.onSubmitted,
      // Selection stays available for read-only rows so users can copy
      // displayed text. Disabled rows lock interaction entirely.
      enableInteractiveSelection: !disabled,
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
      selectionControls: _selectionControlsForPlatform(defaultTargetPlatform),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          embedded ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          UiText(
            widget.label!,
            variant: UiTextVariant.label,
            tone: disabled ? UiTextTone.muted : UiTextTone.primary,
          ),
          SizedBox(height: tokens.spacing.x1),
        ],
        _buildTappable(
          disabled: disabled,
          child: UiFocusRing(
            visible: !embedded && ringActive && !hasError,
            borderRadius: tokens.radius.mdAll,
            color: c.ring.withValues(alpha: 0.32),
            width: 1,
            offset: 1,
            child: AnimatedContainer(
              duration: tokens.motion.fast,
              curve: tokens.motion.standardCurve,
              constraints: BoxConstraints(
                minHeight: UiButtonMetrics.minHeight(widget.size),
              ),
              decoration: BoxDecoration(
                color: embedded ? const Color(0x00000000) : bg,
                border: embedded
                    ? null
                    : Border.all(
                        color: borderColor,
                        width: hasError ? 1.5 : 1,
                      ),
                borderRadius: tokens.radius.mdAll,
              ),
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.leading != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(color: c.textMuted, size: 16),
                      child: widget.leading!,
                    ),
                    SizedBox(width: tokens.spacing.x2),
                  ],
                  Expanded(
                    child: Stack(
                      children: [
                        if (_controller.text.isEmpty && widget.hint != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: UiText(
                                  widget.hint!,
                                  variant: UiTextVariant.body,
                                  tone: UiTextTone.muted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        field,
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    SizedBox(width: tokens.spacing.x2),
                    IconTheme.merge(
                      data: IconThemeData(color: c.textMuted, size: 16),
                      child: widget.trailing!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: tokens.spacing.x1),
          Semantics(
            // Error text is published as a polite live region so screen
            // readers announce validation changes when they flip from
            // null → set without the user moving focus.
            liveRegion: true,
            label: 'Error: $error',
            child: UiText(
              error,
              variant: UiTextVariant.caption,
              tone: UiTextTone.danger,
            ),
          ),
        ] else if (widget.helper != null) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            widget.helper!,
            variant: UiTextVariant.caption,
            tone: UiTextTone.muted,
          ),
        ],
      ],
    );
  }

  static EdgeInsets _paddingFor(UiSize size, UiThemeTokens t, int? maxLines) {
    final horizontal = size == UiSize.lg ? t.spacing.x4 : t.spacing.x3;
    // Single-line height is owned by the minHeight constraint (matching
    // UiSelect/UiButton); multiline gets vertical breathing room.
    final vertical = (maxLines == 1) ? 0.0 : t.spacing.x2;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  static TextSelectionControls _selectionControlsForPlatform(
    TargetPlatform platform,
  ) {
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertinoTextSelectionControls;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return materialTextSelectionControls;
    }
  }
}
