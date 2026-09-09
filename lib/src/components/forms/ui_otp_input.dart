import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart';
import 'internal/ui_field_frame.dart';
import 'text_selection/ui_text_selection_toolbar.dart';

/// Characters accepted by [UiOtpInput]. Codes always read left to right.
enum UiOtpInputType { digits, alphanumeric }

/// A single accessible text field rendered as grouped verification-code slots.
///
/// Paste and platform one-time-code autofill use the same editing value as typing.
/// [groupLength] adds a separator after each group; null joins all slots.
/// External controller values are displayed as supplied: callers must keep them
/// within [length] and [type]. Formatters constrain user edits only.
class UiOtpInput extends StatefulWidget {
  const UiOtpInput({
    super.key,
    this.length = 6,
    this.groupLength,
    this.type = UiOtpInputType.digits,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.helper,
    this.errorText,
    this.semanticLabel,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.size = UiSize.lg,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
  }) : assert(length > 0),
       assert(groupLength == null || groupLength > 0),
       assert(controller == null || initialValue == null);

  final int length;
  final int? groupLength;
  final UiOtpInputType type;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? helper;
  final String? errorText;
  final String? semanticLabel;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final UiSize size;
  final ValueChanged<String>? onChanged;

  /// Called when a user edit produces a complete code, including replacements.
  /// Selection changes and programmatic controller updates do not call this.
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onSubmitted;

  @override
  State<UiOtpInput> createState() => _UiOtpInputState();
}

class _UiOtpInputState extends State<UiOtpInput> {
  final _scroll = ScrollController();
  double _slotWidth = 0;
  double _groupGap = 0;
  final _editableKey = GlobalKey<EditableTextState>();
  TextEditingController? _ownedController;
  FocusNode? _ownedFocus;
  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;
  FocusNode get _focus => widget.focusNode ?? _ownedFocus!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue);
    }
    if (widget.focusNode == null) _ownedFocus = FocusNode();
    _controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(UiOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previous = oldWidget.controller ?? _ownedController!;
      previous.removeListener(_refresh);
      final value = previous.value;
      _ownedController?.dispose();
      _ownedController = widget.controller == null
          ? TextEditingController.fromValue(value)
          : null;
      _controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus!).removeListener(_refresh);
      _ownedFocus?.dispose();
      _ownedFocus = widget.focusNode == null ? FocusNode() : null;
      _focus.addListener(_refresh);
    }
    if (!widget.enabled && oldWidget.enabled) _focus.unfocus();
  }

  void _refresh() {
    setState(() {});
    if (!_focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final selection = _controller.selection;
      final extent =
          selection.extentOffset -
          (!selection.isCollapsed &&
                  selection.extentOffset > selection.baseOffset
              ? 1
              : 0);
      final index = (selection.isValid ? extent : _controller.text.length)
          .clamp(0, widget.length - 1);
      final left =
          index * _slotWidth +
          (index ~/ (widget.groupLength ?? widget.length)) * _groupGap;
      final right = left + _slotWidth + 6;
      final viewport = _scroll.position.viewportDimension;
      if (left < _scroll.offset) {
        _scroll.jumpTo(left.clamp(0, _scroll.position.maxScrollExtent));
      } else if (right > _scroll.offset + viewport) {
        _scroll.jumpTo(
          (right - viewport).clamp(0, _scroll.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _ownedController?.dispose();
    _ownedFocus?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    _focus.requestFocus();
    final offset = index.clamp(0, _controller.text.length);
    _controller.selection = offset < _controller.text.length
        ? TextSelection(baseOffset: offset, extentOffset: offset + 1)
        : TextSelection.collapsed(offset: offset);
    _editableKey.currentState?.requestKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final colors = tokens.colors;
    final invalid = widget.errorText?.isNotEmpty ?? false;
    final code = _controller.text.characters.toList();
    final selection = _controller.selection;
    final active = selection.isValid ? selection.start : code.length;
    final style = tokens.typography.body.copyWith(
      color: widget.enabled ? colors.foreground : colors.mutedForeground,
    );
    final slotSize = UiButtonMetrics.minHeight(widget.size);
    _slotWidth = slotSize;
    _groupGap = tokens.spacing.x2 * 3;
    final height =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            (style.height ?? 1.4) +
        tokens.spacing.x4;
    final group = widget.groupLength ?? widget.length;
    final slots = <Widget>[];
    final rings = <Widget>[];
    for (var i = 0; i < widget.length; i++) {
      if (i > 0 && i % group == 0) {
        slots.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x2),
            child: SizedBox(
              width: tokens.spacing.x2,
              child: Center(
                child: Container(height: 1, color: colors.mutedForeground),
              ),
            ),
          ),
        );
      }
      final focused =
          widget.enabled &&
          _focus.hasFocus &&
          (selection.isCollapsed
              ? i == active.clamp(0, widget.length - 1)
              : i >= selection.start && i < selection.end);
      final radius = BorderRadius.horizontal(
        left: i % group == 0 ? tokens.radius.md : Radius.zero,
        right: (i + 1) % group == 0 || i == widget.length - 1
            ? tokens.radius.md
            : Radius.zero,
      );
      if (focused) {
        rings.add(
          Positioned(
            left: i * slotSize + (i ~/ group) * _groupGap,
            top: 0,
            bottom: 0,
            width: slotSize,
            child: IgnorePointer(
              child: UiFocusRing(
                visible: true,
                borderRadius: radius,
                color: (invalid ? colors.destructive : colors.ring).withValues(
                  alpha: .5,
                ),
                width: 3,
                offset: 3,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      }
      slots.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => _select(i) : null,
          onLongPress: widget.enabled
              ? () {
                  _focus.requestFocus();
                  _editableKey.currentState?.userUpdateTextEditingValue(
                    _controller.value.copyWith(
                      selection: TextSelection(
                        baseOffset: 0,
                        extentOffset: _controller.text.length,
                      ),
                    ),
                    SelectionChangedCause.longPress,
                  );
                  _editableKey.currentState?.showToolbar();
                }
              : null,
          child: UiFocusRing(
            visible: false,
            borderRadius: radius,
            color: (invalid ? colors.destructive : colors.ring).withValues(
              alpha: .5,
            ),
            width: 3,
            offset: 3,
            child: Container(
              width: slotSize,
              height: height.clamp(slotSize, double.infinity),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !widget.enabled
                    ? colors.muted
                    : focused && !selection.isCollapsed
                    ? colors.accent
                    : colors.surface,
                borderRadius: radius,
                border: Border(
                  top: BorderSide(
                    color: invalid ? colors.destructive : colors.input,
                  ),
                  bottom: BorderSide(
                    color: invalid ? colors.destructive : colors.input,
                  ),
                  right: BorderSide(
                    color: invalid ? colors.destructive : colors.input,
                  ),
                  left: BorderSide(
                    color: invalid ? colors.destructive : colors.input,
                    width: i % group == 0 ? 1 : 0,
                    style: i % group == 0
                        ? BorderStyle.solid
                        : BorderStyle.none,
                  ),
                ),
              ),
              child: i < code.length
                  ? Text(code[i], style: style)
                  : focused && !widget.readOnly
                  ? Container(
                      width: 2,
                      height: style.fontSize,
                      color: colors.primary,
                    )
                  : null,
            ),
          ),
        ),
      );
    }
    return UiFieldFrame(
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText,
      enabled: widget.enabled,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Semantics(
                      label: widget.semanticLabel ?? widget.label,
                      enabled: widget.enabled,
                      child: Focus(
                        canRequestFocus: widget.enabled,
                        descendantsAreFocusable: widget.enabled,
                        child: Opacity(
                          opacity: 0,
                          alwaysIncludeSemantics: true,
                          child: EditableText(
                            key: _editableKey,
                            controller: _controller,
                            focusNode: _focus,
                            style: style,
                            cursorColor: colors.primary,
                            backgroundCursorColor: colors.input,
                            readOnly: widget.readOnly || !widget.enabled,
                            autofocus: widget.autofocus && widget.enabled,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: widget.type == UiOtpInputType.digits
                                ? TextInputType.number
                                : TextInputType.text,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableInteractiveSelection: widget.enabled,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(
                                  widget.type == UiOtpInputType.digits
                                      ? '[0-9]'
                                      : '[a-zA-Z0-9]',
                                ),
                              ),
                              LengthLimitingTextInputFormatter(widget.length),
                            ],
                            onChanged: (value) {
                              widget.onChanged?.call(value);
                              if (value.length == widget.length) {
                                widget.onCompleted?.call(value);
                              }
                            },
                            onSubmitted: widget.onSubmitted,
                            contextMenuBuilder: (context, state) =>
                                SystemContextMenu.isSupportedByField(state)
                                ? SystemContextMenu.editableText(
                                    editableTextState: state,
                                  )
                                : UiTextSelectionToolbar.editableText(
                                    editableTextState: state,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Row(mainAxisSize: MainAxisSize.min, children: slots),
                  ),
                  ...rings,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
