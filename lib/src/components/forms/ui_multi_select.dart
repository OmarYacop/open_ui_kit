import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'input.dart';
import 'icon_button.dart';
import 'select.dart';
import 'button.dart';
import 'internal/ui_field_frame.dart';

/// Controlled searchable multi-selection with removable values and lazy options.
///
/// The caller owns [value]. Each callback receives a new unmodifiable set.
/// Replacing/filtering options never silently removes existing selections.
/// Values must have stable equality; labels should be supplied for off-list values
/// with [selectedLabelBuilder] when their toString is not suitable for display.
class UiMultiSelect<T> extends StatefulWidget {
  const UiMultiSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.helper,
    this.errorText,
    this.searchHint,
    this.emptyText,
    this.enabled = true,
    this.disabledValues = const {},
    this.focusNode,
    this.maxSelections,
    this.maxMenuHeight = 280,
    this.selectedLabelBuilder,
    this.filter,
  }) : assert(maxSelections == null || maxSelections > 0),
       assert(maxMenuHeight > 0);

  final List<UiSelectOption<T>> options;
  final Set<T> value;
  final ValueChanged<Set<T>>? onChanged;
  final String? label;
  final String? helper;
  final String? errorText;
  final String? searchHint;
  final String? emptyText;
  final bool enabled;
  final Set<T> disabledValues;
  final FocusNode? focusNode;
  final int? maxSelections;
  final double maxMenuHeight;
  final String Function(T value)? selectedLabelBuilder;
  final bool Function(UiSelectOption<T> option, String query)? filter;

  @override
  State<UiMultiSelect<T>> createState() => _UiMultiSelectState<T>();
}

class _UiMultiSelectState<T> extends State<UiMultiSelect<T>> {
  final _portal = OverlayPortalController();
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _tapGroup = Object();
  late FocusNode _focus;
  int _active = -1;
  bool _open = false;
  bool get _enabled => widget.enabled && widget.onChanged != null;
  List<UiSelectOption<T>> get _visible {
    final query = _query.text.trim();
    return widget.options
        .where(
          (option) =>
              widget.filter?.call(option, query) ??
              option.label.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  bool _canToggle(T value) =>
      _enabled &&
      !widget.disabledValues.contains(value) &&
      (widget.value.contains(value) ||
          widget.maxSelections == null ||
          widget.value.length < widget.maxSelections!);
  double get _rowHeight =>
      math.max(48, MediaQuery.textScalerOf(context).scale(16) + 20);

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_focusChanged);
    _query.addListener(_queryChanged);
  }

  @override
  void didUpdateWidget(covariant UiMultiSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_focusChanged);
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_focusChanged);
    }
    if (!_enabled && _open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_enabled) _hide();
      });
    }
    _normalizeActive();
  }

  void _normalizeActive() {
    final options = _visible;
    if (_active < 0 ||
        _active >= options.length ||
        !_canToggle(options[_active].value)) {
      _active = options.indexWhere((option) => _canToggle(option.value));
    }
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _show();
    } else {
      _hide();
    }
  }

  void _queryChanged() {
    _active = -1;
    _normalizeActive();
    if (_focus.hasFocus) _show();
    if (mounted) setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _show() {
    if (!_enabled || Overlay.maybeOf(context) == null) return;
    _normalizeActive();
    _portal.show();
    if (!_open) setState(() => _open = true);
  }

  void _hide() {
    _portal.hide();
    if (_open && mounted) setState(() => _open = false);
  }

  void _toggle(T value) {
    if (!_canToggle(value)) return;
    final next = Set<T>.of(widget.value);
    if (!next.remove(value)) next.add(value);
    widget.onChanged?.call(Set.unmodifiable(next));
    _focus.requestFocus();
  }

  void _move(int delta) {
    _show();
    final options = _visible;
    if (options.isEmpty) return;
    for (var step = 1; step <= options.length; step++) {
      final index = (_active + delta * step) % options.length;
      if (_canToggle(options[index].value)) {
        setState(() => _active = index);
        if (_scroll.hasClients) {
          final position = _scroll.position;
          final top = index * _rowHeight;
          final bottom = top + _rowHeight;
          final offset = top < position.pixels
              ? top
              : bottom > position.pixels + position.viewportDimension
              ? bottom - position.viewportDimension
              : position.pixels;
          _scroll.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
        }
        return;
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_enabled || event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _open) {
      _hide();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (!_open) {
        _show();
      } else {
        _move(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (!_open) {
        _show();
      } else {
        final options = _visible;
        if (_active >= 0 && _active < options.length) {
          _toggle(options[_active].value);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace &&
        _query.text.isEmpty &&
        widget.value.isNotEmpty) {
      final removable = widget.value.where(
        (value) => !widget.disabledValues.contains(value),
      );
      if (removable.isNotEmpty) _toggle(removable.last);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _label(T value) =>
      widget.selectedLabelBuilder?.call(value) ??
      widget.options
          .where((option) => option.value == value)
          .firstOrNull
          ?.label ??
      '$value';

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final strings = UiLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 320.0;
        return UiFieldFrame(
          label: widget.label,
          helper: widget.helper,
          errorText: widget.errorText,
          enabled: _enabled,
          child: TapRegion(
            groupId: _tapGroup,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.value.isNotEmpty) ...[
                  Wrap(
                    spacing: tokens.spacing.x1,
                    runSpacing: tokens.spacing.x1,
                    children: [
                      for (final value in widget.value)
                        Semantics(
                          label: strings.removeSelection(_label(value)),
                          button: true,
                          enabled: _canToggle(value),
                          onTap: _canToggle(value)
                              ? () => _toggle(value)
                              : null,
                          child: ExcludeSemantics(
                            child: UiButton(
                              label: _label(value),
                              size: UiSize.sm,
                              intent: UiIntent.neutral,
                              trailing: const Icon(LucideIcons.x, size: 14),
                              onPressed: _canToggle(value)
                                  ? () => _toggle(value)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.x1),
                ],
                UiAnchoredSurface(
                  controller: _portal,
                  overlayChild: _enabled
                      ? _menu(width)
                      : const SizedBox.shrink(),
                  child: Focus(
                    canRequestFocus: false,
                    onKeyEvent: _key,
                    child: UiInput(
                      controller: _query,
                      focusNode: _focus,
                      enabled: _enabled,
                      hint: widget.searchHint ?? strings.searchOptions,
                      trailing: const Icon(
                        LucideIcons.chevronsUpDown,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menu(double width) {
    final tokens = UiThemeTokens.of(context);
    final options = _visible;
    return UiAnchoredOverlayTapRegion(
      groupId: _tapGroup,
      onDismiss: () {
        _focus.unfocus();
        _hide();
      },
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
          child: UiBox(
            key: const ValueKey('ui-multi-select-menu'),
            background: tokens.colors.popover,
            border: Border.all(color: tokens.colors.border),
            borderRadius: tokens.radius.mdAll,
            boxShadow: tokens.shadows.md,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.x2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          label: _active >= 0 && _active < options.length
                              ? UiLocalizations.of(context).activeSelection(
                                  options[_active].label,
                                  widget.value.length,
                                )
                              : UiLocalizations.of(context)
                                    .selectionCount(widget.value.length),
                          child: ExcludeSemantics(
                            child: UiText(
                              UiLocalizations.of(context)
                                  .selectionCount(widget.value.length),
                              variant: UiTextVariant.caption,
                              tone: UiTextTone.muted,
                            ),
                          ),
                        ),
                      ),
                      UiIconButton(
                        semanticsLabel: UiLocalizations.of(context).close,
                        icon: const Icon(LucideIcons.x),
                        size: UiSize.sm,
                        onPressed: () {
                          _focus.requestFocus();
                          _hide();
                        },
                      ),
                    ],
                  ),
                ),
                if (options.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(tokens.spacing.x4),
                    child: UiText(
                      widget.emptyText ?? UiLocalizations.of(context).noOptions,
                      variant: UiTextVariant.body,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      controller: _scroll,
                      primary: false,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemExtent: _rowHeight,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = widget.value.contains(option.value);
                        final enabled = _canToggle(option.value);
                        return Semantics(
                          selected: selected,
                          enabled: enabled,
                          button: true,
                          label: option.label,
                          onTap: enabled ? () => _toggle(option.value) : null,
                          child: ExcludeFocus(
                            child: UiPressable(
                              enabled: enabled,
                              excludeFromSemantics: true,
                              onPressed: enabled
                                  ? () => _toggle(option.value)
                                  : null,
                              builder: (context, state, _) => UiBox(
                                background: index == _active || state.hovered
                                    ? tokens.colors.surfaceMuted
                                    : const Color(0x00000000),
                                padding: EdgeInsets.symmetric(
                                  horizontal: tokens.spacing.x3,
                                ),
                                child: Row(
                                  children: [
                                    if (option.leading != null) ...[
                                      option.leading!,
                                      SizedBox(width: tokens.spacing.x2),
                                    ],
                                    Expanded(
                                      child: UiText(
                                        option.label,
                                        variant: UiTextVariant.body,
                                        tone: enabled
                                            ? UiTextTone.primary
                                            : UiTextTone.muted,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        LucideIcons.check,
                                        size: 16,
                                        color: tokens.colors.popoverForeground,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _query.removeListener(_queryChanged);
    _query.dispose();
    _scroll.dispose();
    _focus.removeListener(_focusChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }
}
