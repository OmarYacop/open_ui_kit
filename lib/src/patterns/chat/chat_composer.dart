import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/menu/ui_dropdown_menu.dart';
import '../../components/chat/message_utility_strip.dart';
import '../../foundation/motion/ui_contour_controller.dart';
import '../../foundation/motion/ui_contour_morph.dart';
import '../../foundation/primitives/ui_progress.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
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
    this.controlExtent = 48,
    this.inputBorderRadius,
    this.idleAction,
    this.allowEmptySend = false,
    this.textDirection,
    this.clearOnSend = true,
  }) : _conversation = false,
       attachmentShelf = null,
       contextShelf = null,
       attachmentItems = const [],
       attachmentLabel = 'Attach file',
       onRecord = null,
       recordLabel = 'Record voice message',
       recordStarting = false,
       modeSurface = null,
       actionMode = null,
       onAttachmentMenuOpened = null;

  /// LMS-style floating input: attachment outside, reply and actions inside.
  /// Use [actionMode] for selection or recording with a shared Contour deck.
  /// [modeSurface] replaces the whole composer for custom presentations.
  /// Native services and draft ownership remain with the caller.
  const UiChatComposer.conversation({
    super.key,
    required this.onSend,
    this.controller,
    this.focusNode,
    this.hint = 'Message…',
    this.disabled = false,
    this.loading = false,
    this.onChanged,
    this.sendLabel = 'Send',
    this.maxLines = 5,
    this.controlExtent = 48,
    this.inputBorderRadius,
    this.allowEmptySend = false,
    this.textDirection,
    this.contextShelf,
    this.attachmentShelf,
    this.attachmentItems = const [],
    this.attachmentLabel = 'Attach file',
    this.onRecord,
    this.recordLabel = 'Record voice message',
    this.recordStarting = false,
    this.modeSurface,
    this.actionMode,
    this.onAttachmentMenuOpened,
    this.clearOnSend = true,
    this.leading,
    this.idleAction,
  }) : _conversation = true,
       header = null,
       compactSendAction = true,
       submitOnKeyboardAction = false,
       textInputAction = TextInputAction.newline,
       floating = true;

  final bool _conversation;
  final Widget? contextShelf;

  /// Staged attachments above the text field, inside the shared input surface.
  /// Use UiChatAttachmentTray and set allowEmptySend while attachments exist.
  final Widget? attachmentShelf;
  final List<UiMenuItem> attachmentItems;
  final String attachmentLabel;
  final VoidCallback? onRecord;
  final String recordLabel;
  final bool recordStarting;
  final Widget? modeSurface;
  final UiChatComposerActions? actionMode;
  final VoidCallback? onAttachmentMenuOpened;

  /// Set false when the caller clears the draft after asynchronous submission.
  final bool clearOnSend;

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

  /// Removes the toolbar background so the shared input/action surface
  /// floats above a page edge fade.
  final bool floating;
  final double controlExtent;
  final BorderRadius? inputBorderRadius;

  /// Replaces the disabled send action while there is no text.
  final Widget? idleAction;

  /// Allows callers with staged media to submit an empty caption.
  final bool allowEmptySend;
  final TextDirection? textDirection;

  @override
  State<UiChatComposer> createState() => _UiChatComposerState();
}

class _UiChatComposerState extends State<UiChatComposer>
    with SingleTickerProviderStateMixin {
  late final UiContourController _mode = UiContourController(vsync: this);
  UiChatComposerActions? _lastActions;
  bool _modeRequested = false;

  void _syncMode() {
    _lastActions = widget.actionMode ?? _lastActions;
    final active = widget.actionMode != null;
    if (active == _modeRequested) return;
    _modeRequested = active;
    if (active) {
      _mode.open(context);
    } else {
      _mode.close(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMode();
  }

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
    _syncMode();
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
    _mode.dispose();
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
    if (widget.disabled || widget.loading) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty && !widget.allowEmptySend) return;
    widget.onSend(text);
    if (widget.clearOnSend) _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    if (widget._conversation) {
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : tokens.motion.fast;
      return AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .985, end: 1.0).animate(animation),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
        child: widget.modeSurface ?? _conversationInput(context),
      );
    }

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
                child: UiBox(
                  key: const ValueKey('chat-composer-input-surface'),
                  background: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: widget.inputBorderRadius ?? tokens.radius.lgAll,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth != _inputWidth) {
                              _inputWidth = constraints.maxWidth;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _update();
                              });
                            }
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: widget.controlExtent,
                              ),
                              child: UiInput(
                                variant: UiInputVariant.embedded,
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
                                minHeight: widget.controlExtent,
                                borderRadius:
                                    widget.inputBorderRadius ??
                                    tokens.radius.lgAll,
                                textDirection: widget.textDirection,
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: tokens.spacing.x2),
                      if (widget.compactSendAction)
                        SizedBox.square(
                          dimension: widget.controlExtent,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            reverseDuration: const Duration(milliseconds: 150),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: .78,
                                      end: 1,
                                    ).animate(animation),
                                    child: RotationTransition(
                                      turns: Tween<double>(
                                        begin: -.035,
                                        end: 0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                                ),
                            child:
                                !_canSend &&
                                    !widget.allowEmptySend &&
                                    widget.idleAction != null
                                ? KeyedSubtree(
                                    key: const ValueKey('chat-idle-action'),
                                    child: widget.idleAction!,
                                  )
                                : UiIconButton(
                                    key: const ValueKey('chat-send-action'),
                                    surfaceMargin: EdgeInsets.all(
                                      tokens.spacing.x1 + tokens.spacing.x1 / 2,
                                    ),
                                    icon: const Icon(LucideIcons.send),
                                    semanticsLabel: widget.sendLabel,
                                    intent: UiIntent.primary,
                                    borderRadius: tokens.radius.pillAll,
                                    onPressed:
                                        widget.disabled ||
                                            widget.loading ||
                                            (!_canSend &&
                                                !widget.allowEmptySend)
                                        ? null
                                        : _submit,
                                  ),
                          ),
                        )
                      else
                        UiButton(
                          label: widget.sendLabel,
                          intent: UiIntent.primary,
                          loading: widget.loading,
                          onPressed:
                              widget.disabled ||
                                  widget.loading ||
                                  (!_canSend && !widget.allowEmptySend)
                              ? null
                              : _submit,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conversationSurface(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : tokens.motion.fast;
    final canSend = _canSend || widget.allowEmptySend;
    final radius = widget.inputBorderRadius ?? tokens.radius.xlAll;
    return UiBox(
      key: const ValueKey('chat-composer-surface'),
      background: tokens.colors.surface,
      border: Border.all(color: tokens.colors.border),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.contextShelf != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.x2,
                tokens.spacing.x2,
                tokens.spacing.x2,
                0,
              ),
              child: widget.contextShelf!,
            ),
          if (widget.attachmentShelf != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.x2,
                tokens.spacing.x2,
                tokens.spacing.x2,
                0,
              ),
              child: widget.attachmentShelf!,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: UiInput(
                  controller: _ctrl,
                  focusNode: widget.focusNode,
                  hint: widget.hint,
                  enabled: !widget.disabled && !widget.loading,
                  variant: UiInputVariant.embedded,
                  minHeight: widget.controlExtent,
                  minLines: 1,
                  maxLines: widget.maxLines,
                  textDirection: widget.textDirection,
                  textInputAction: TextInputAction.newline,
                  onChanged: widget.onChanged,
                ),
              ),
              AnimatedSwitcher(
                duration: duration,
                switchInCurve: tokens.motion.standardCurve,
                switchOutCurve: tokens.motion.standardCurve,
                child: !canSend && widget.idleAction != null
                    ? widget.idleAction!
                    : SizedBox.square(
                        key: ValueKey(
                          canSend ? 'chat-send-action' : 'chat-idle-action',
                        ),
                        dimension: widget.controlExtent,
                        child: UiIconButton(
                          semanticsLabel: canSend
                              ? widget.sendLabel
                              : widget.recordLabel,
                          intent: canSend ? UiIntent.primary : UiIntent.ghost,
                          backgroundColor: canSend
                              ? null
                              : const Color(0x00000000),
                          borderColor: canSend ? null : const Color(0x00000000),
                          borderWidth: canSend ? 1 : 0,
                          surfaceMargin: EdgeInsets.all(
                            tokens.spacing.x1 * 1.5,
                          ),
                          borderRadius: tokens.radius.pillAll,
                          onPressed:
                              widget.disabled ||
                                  widget.loading ||
                                  widget.recordStarting
                              ? null
                              : canSend
                              ? _submit
                              : widget.onRecord,
                          icon: widget.loading || widget.recordStarting
                              ? const UiSpinner(size: 18)
                              : Icon(
                                  canSend ? LucideIcons.send : LucideIcons.mic,
                                  size: canSend ? 19 : 21,
                                ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conversationInput(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final selected = widget.actionMode != null;
    final actions = widget.actionMode ?? _lastActions;
    // Reuse the input and deck during geometry ticks. Rebuilding EditableText
    // and its descendants every frame makes mode changes needlessly expensive.
    final writingSurface = _conversationSurface(context);
    final actionDeck = actions == null
        ? const SizedBox.shrink()
        : _actionDeck(context, actions);
    return AnimatedBuilder(
      key: const ValueKey('chat-writing-surface'),
      animation: _mode,
      builder: (context, _) {
        final progress = _mode.value.clamp(0.0, 1.0);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x3,
            vertical: tokens.spacing.x2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.leading != null ||
                  widget.attachmentItems.isNotEmpty ||
                  actions != null) ...[
                if (selected || progress > 0)
                  _closeModeButton(context, actions!, progress)
                else
                  SizedBox.square(
                    dimension: widget.controlExtent,
                    child: UiDropdownMenu(
                      title: widget.attachmentLabel,
                      destinationOffset: Offset(
                        0,
                        -widget.controlExtent - tokens.spacing.x3,
                      ),
                      menuTokens: tokens.menu.copyWith(
                        borderColor: tokens.colors.border,
                        borderWidth: 1,
                      ),
                      triggerBuilder: (_, open) => widget.leading != null
                          ? widget.leading!
                          : UiIconButton(
                              key: const ValueKey('open-attachments'),
                              visualExtent: widget.controlExtent,
                              icon: Transform.rotate(
                                angle: progress * math.pi / 4,
                                child: const Icon(LucideIcons.plus),
                              ),
                              semanticsLabel: widget.attachmentLabel,
                              intent: UiIntent.secondary,
                              borderRadius: tokens.radius.pillAll,
                              backgroundColor: tokens.colors.surface,
                              borderColor: tokens.colors.border,
                              onPressed: widget.disabled || widget.loading
                                  ? null
                                  : () {
                                      widget.onAttachmentMenuOpened?.call();
                                      open();
                                    },
                            ),
                      items: widget.attachmentItems,
                    ),
                  ),
                SizedBox(width: tokens.spacing.x2),
              ],
              Expanded(
                child: UiContourMorph(
                  controller: _mode,
                  alignment: Alignment.bottomCenter,
                  collapsed: ExcludeFocus(
                    excluding: selected,
                    child: IgnorePointer(
                      ignoring: selected,
                      child: writingSurface,
                    ),
                  ),
                  expanded: actionDeck,
                ),
              ),
              SizedBox(
                width: (widget.controlExtent + tokens.spacing.x2) * progress,
                height: widget.controlExtent,
                child: ClipRect(
                  clipBehavior: progress == 1 ? Clip.none : Clip.hardEdge,
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerEnd,
                    minWidth: widget.controlExtent,
                    maxWidth: widget.controlExtent,
                    child: IgnorePointer(
                      ignoring: !selected || progress < .95,
                      child: ExcludeSemantics(
                        excluding: !selected || progress < .95,
                        child: Opacity(
                          opacity: progress,
                          child: actions == null
                              ? const SizedBox.shrink()
                              : SizedBox.square(
                                  dimension: widget.controlExtent,
                                  child: UiIconButton(
                                    key: ValueKey(
                                      'selection-primary-${actions.primary.id}',
                                    ),
                                    visualExtent: widget.controlExtent,
                                    icon: Icon(actions.primary.icon, size: 20),
                                    semanticsLabel: actions.primary.label,
                                    intent: actions.primary.intent,
                                    backgroundColor:
                                        actions.primary.intent ==
                                            UiIntent.danger
                                        ? tokens.colors.danger
                                        : actions.primary.intent ==
                                              UiIntent.primary
                                        ? null
                                        : tokens.colors.surface,
                                    foregroundColor:
                                        actions.primary.intent ==
                                            UiIntent.danger
                                        ? tokens.colors.onDanger
                                        : actions.primary.intent ==
                                              UiIntent.primary
                                        ? null
                                        : tokens.colors.textPrimary,
                                    borderColor:
                                        actions.primary.intent ==
                                            UiIntent.danger
                                        ? tokens.colors.danger
                                        : actions.primary.intent ==
                                              UiIntent.primary
                                        ? null
                                        : tokens.colors.border,
                                    borderRadius: tokens.radius.pillAll,
                                    onPressed:
                                        actions.primary.enabled && selected
                                        ? actions.primary.onPressed
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _closeModeButton(
    BuildContext context,
    UiChatComposerActions actions,
    double progress,
  ) {
    final tokens = UiThemeTokens.of(context);
    final count = actions.selectedCount;
    final showCount = count > 1;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : tokens.motion.fast;
    return UiPressable(
      key: const ValueKey('open-attachments'),
      semanticsLabel: showCount
          ? '${actions.closeLabel}, ${actions.selectionLabel}'
          : actions.closeLabel,
      onPressed: widget.disabled || widget.loading ? null : actions.onClose,
      minTapSize: widget.controlExtent,
      builder: (_, state, child) => UiFocusRing(
        visible: state.focused,
        borderRadius: tokens.radius.pillAll,
        child: AnimatedOpacity(
          duration: duration,
          opacity: state.pressed ? .72 : 1,
          child: UiBox(
            key: const ValueKey('selection-close-surface'),
            height: widget.controlExtent,
            background: tokens.colors.surface,
            border: Border.all(color: tokens.colors.border),
            borderRadius: tokens.radius.pillAll,
            child: AnimatedSize(
              duration: duration,
              curve: tokens.motion.standardCurve,
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
        ),
      ),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: widget.controlExtent,
              child: Center(
                child: Transform.rotate(
                  angle: progress * math.pi / 4,
                  child: Icon(
                    LucideIcons.plus,
                    color: tokens.colors.textPrimary,
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: duration,
              child: showCount
                  ? Padding(
                      key: ValueKey(count),
                      padding: EdgeInsetsDirectional.only(
                        end: tokens.spacing.x3,
                      ),
                      child: UiText(
                        '$count',
                        variant: UiTextVariant.bodySm,
                        style: TextStyle(
                          color: tokens.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-selection-count')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionDeck(BuildContext context, UiChatComposerActions actions) {
    final tokens = UiThemeTokens.of(context);
    return Semantics(
      label: actions.selectionLabel,
      child: UiBox(
        key: const ValueKey('chat-selection-composer'),
        background: tokens.colors.surface,
        border: Border.all(color: tokens.colors.border),
        borderRadius: widget.inputBorderRadius ?? tokens.radius.xlAll,
        clipBehavior: Clip.antiAlias,
        height: widget.controlExtent,
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x1),
        child:
            actions.content ??
            Row(
              children: [
                for (final action in actions.actions)
                  Expanded(
                    child: UiIconButton(
                      key: ValueKey('selection-action-${action.id}'),
                      icon: Icon(action.icon, size: 20),
                      semanticsLabel: action.label,
                      intent: action.intent,
                      borderRadius: tokens.radius.pillAll,
                      onPressed: widget.actionMode != null && action.enabled
                          ? action.onPressed
                          : null,
                    ),
                  ),
                if (actions.actions.isEmpty)
                  Expanded(
                    child: UiText(
                      actions.selectionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
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
      text: TextSpan(text: text, style: tokens.typography.body),
      textDirection: widget.textDirection ?? Directionality.of(context),
      maxLines: widget.maxLines,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _inputWidth);

    final wrappedLines = textPainter.computeLineMetrics().length;
    final lines = math.max(hardLines, wrappedLines);
    textPainter.dispose();
    return lines.clamp(1, widget.maxLines);
  }
}

/// Active composer mode; the host owns commands and recording/selection state.
class UiChatComposerActions {
  const UiChatComposerActions({
    required this.selectionLabel,
    required this.closeLabel,
    required this.onClose,
    required this.primary,
    this.actions = const [],
    this.content,
    this.selectedCount = 0,
  }) : assert(selectedCount >= 0);

  /// The close control shows a count only when more than one item is selected.
  final int selectedCount;

  /// Optional deck content, such as recording duration and waveform.
  /// When provided, replaces the inline action row.
  final Widget? content;

  /// Accessible description of the active mode.
  final String selectionLabel, closeLabel;
  final VoidCallback onClose;
  final UiMessageUtilityAction primary;
  final List<UiMessageUtilityAction> actions;
}
