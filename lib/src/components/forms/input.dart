import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiSize, UiButtonMetrics;
import 'text_selection/ui_text_selection_controls.dart';

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
    this.borderRadius,
    this.minHeight,
    this.textDirection,
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
  final BorderRadius? borderRadius;
  final double? minHeight;
  final TextDirection? textDirection;

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

  // EditableText defaults showSelectionHandles to false; TextField (Material)
  // and CupertinoTextField both compute it per selection change instead of
  // hardcoding true, so a long-press shows handles but pressing Home in an
  // otherwise-empty field doesn't. Mirrored here to match that behavior.
  bool _showSelectionHandles = false;

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled => false;

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

  // Ported from Material's `_TextFieldState._shouldShowSelectionHandles` so
  // UiInput's handle visibility matches TextField/CupertinoTextField: shown
  // on long-press or stylus handwriting, or once there's text to select;
  // withheld for keyboard-driven selection, read-only collapsed selections,
  // and disabled fields.
  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if (!_selectionGestureBuilder.shouldShowSelectionToolbar ||
        !_selectionGestureBuilder.shouldShowSelectionHandles) {
      return false;
    }
    if (cause == SelectionChangedCause.keyboard) return false;
    if (widget.readOnly && _controller.selection.isCollapsed) return false;
    if (!widget.enabled) return false;
    if (cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.stylusHandwriting) {
      return true;
    }
    return _controller.text.isNotEmpty;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final willShow = _shouldShowSelectionHandles(cause);
    if (willShow != _showSelectionHandles) {
      setState(() => _showSelectionHandles = willShow);
    }
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

    // Match shadcn/native behavior: read-only inputs can still receive focus
    // for selection and copying. Only disabled inputs suppress focus chrome.
    final canFocus = !disabled;
    final ringActive = _focused && canFocus;
    final embedded = widget.variant == UiInputVariant.embedded;
    // The original one-pixel border carries the solid focus color. A separate
    // wider, translucent ring sits outside it, producing the layered shadcn
    // treatment without changing layout.
    final borderColor = hasError
        ? c.destructive
        : ringActive
            ? c.ring
            : c.input;
    final borderRadius = widget.borderRadius ?? tokens.radius.mdAll;
    final focusTransition = UiMotionSpec.resolveCustom(
      context,
      duration: const Duration(milliseconds: 150),
      curve: const Cubic(0.4, 0, 0.2, 1),
    );
    final ringColor = hasError
        ? c.destructive.withValues(
            alpha: tokens.brightness == Brightness.dark ? .4 : .2,
          )
        : c.ring.withValues(alpha: .5);

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
      keyboardType: widget.keyboardType ??
          (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
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
      textDirection: widget.textDirection,
      // Selection stays available for read-only rows so users can copy
      // displayed text. Disabled rows lock interaction entirely.
      enableInteractiveSelection: !disabled,
      selectionControls: uiAdaptiveTextSelectionControls,
      showSelectionHandles: _showSelectionHandles,
      onSelectionChanged: _handleSelectionChanged,
      contextMenuBuilder: (_, editableTextState) =>
          SystemContextMenu.isSupportedByField(editableTextState)
              ? SystemContextMenu.editableText(
                  editableTextState: editableTextState,
                )
              : _UiTextSelectionMenu(editableTextState: editableTextState),
      // Gesture handling is owned by the surrounding
      // TextSelectionGestureDetectorBuilder. Leaving this false lets
      // RenderEditable consume its basic gestures too, which prevents the
      // platform selection toolbar from being presented reliably.
      rendererIgnoresPointer: true,
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
            visible: !embedded && ringActive,
            borderRadius: borderRadius,
            color: ringColor,
            width: 3,
            offset: 3,
            animate: true,
            duration: focusTransition.duration,
            curve: focusTransition.curve,
            child: AnimatedContainer(
              duration: focusTransition.duration,
              curve: focusTransition.curve,
              constraints: BoxConstraints(
                minHeight:
                    widget.minHeight ?? UiButtonMetrics.minHeight(widget.size),
              ),
              decoration: BoxDecoration(
                color: embedded ? const Color(0x00000000) : bg,
                border: embedded
                    ? null
                    : Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                borderRadius: borderRadius,
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
                            child: Directionality(
                              textDirection: widget.textDirection ??
                                  Directionality.of(context),
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
}

class _UiTextSelectionMenu extends StatelessWidget {
  const _UiTextSelectionMenu({required this.editableTextState});

  final EditableTextState editableTextState;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final buttons = editableTextState.contextMenuButtonItems;
    if (buttons.isEmpty) return const SizedBox.shrink();

    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: editableTextState.contextMenuAnchors.primaryAnchor,
        anchorBelow: editableTextState.contextMenuAnchors.secondaryAnchor ??
            editableTextState.contextMenuAnchors.primaryAnchor,
        fitsAbove: true,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.card,
          border: Border.all(color: tokens.colors.border),
          borderRadius: tokens.radius.mdAll,
          boxShadow: tokens.shadows.md,
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.x1),
          child: Wrap(
            spacing: tokens.spacing.x1,
            children: [
              for (final button in buttons)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: button.onPressed,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.x3,
                      vertical: tokens.spacing.x2,
                    ),
                    child: UiText(
                      button.label ?? button.type.name,
                      variant: UiTextVariant.label,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
