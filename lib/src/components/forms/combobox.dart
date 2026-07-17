import 'dart:math' as math;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiButtonMetrics, UiSize;
import 'select.dart'
    show
        UiSelectOption,
        UiSelectOptionBuilder,
        UiSelectPlacement,
        UiSelectValueBuilder;

typedef UiComboboxFilter<T> = bool Function(
  UiSelectOption<T> option,
  String query,
);

/// Searchable select for larger option sets.
///
/// Unlike [UiSelect], the popup body is backed by `ListView.builder`, so rows
/// are built lazily as they enter the viewport. Use this for long lists or any
/// picker where the user benefits from search.
class UiCombobox<T> extends StatefulWidget {
  const UiCombobox({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.searchHint = 'Search...',
    this.emptyText = 'No results found.',
    this.enabled = true,
    this.size = UiSize.md,
    this.placement = UiSelectPlacement.auto,
    this.optionBuilder,
    this.valueBuilder,
    this.filter,
    this.shrinkWrap = false,
  });

  final List<UiSelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? hint;
  final String searchHint;
  final String emptyText;
  final bool enabled;
  final UiSize size;
  final UiSelectPlacement placement;
  final UiSelectOptionBuilder<T>? optionBuilder;
  final UiSelectValueBuilder<T>? valueBuilder;
  final UiComboboxFilter<T>? filter;
  final bool shrinkWrap;

  @override
  State<UiCombobox<T>> createState() => _UiComboboxState<T>();
}

class _UiComboboxState<T> extends State<UiCombobox<T>> {
  final GlobalKey _targetKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  OverlayEntry? _entry;
  StateSetter? _overlaySetState;
  bool _openAbove = false;
  bool _isDisposing = false;
  double _menuWidth = 200;
  double _menuMaxHeight = 280;
  double _horizontalOffset = 0;
  double _anchorOffset = 0;
  double? _triggerWidth;
  Rect? _targetOverlayRect;
  Rect? _targetGlobalRect;

  bool get _disabled => !widget.enabled || widget.onChanged == null;

  UiSelectOption<T>? get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  List<int> get _visibleIndexes {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return List<int>.generate(widget.options.length, (i) => i);
    }
    final filter = widget.filter;
    final folded = query.toLowerCase();
    final indexes = <int>[];
    for (var i = 0; i < widget.options.length; i++) {
      final option = widget.options[i];
      final matches = filter?.call(option, query) ??
          option.label.toLowerCase().contains(folded) ||
              (option.subtitle?.toLowerCase().contains(folded) ?? false);
      if (matches) indexes.add(i);
    }
    return indexes;
  }

  int get _selectedVisibleIndex {
    final selected = widget.value;
    if (selected == null) return -1;
    final indexes = _visibleIndexes;
    for (var i = 0; i < indexes.length; i++) {
      if (widget.options[indexes[i]].value == selected) return i;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_handleQueryChange);
  }

  @override
  void dispose() {
    _isDisposing = true;
    _hide(notify: false);
    _queryController.removeListener(_handleQueryChange);
    _queryController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleQueryChange() {
    if (_entry == null) return;
    _overlaySetState?.call(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _toggle() {
    if (!mounted || _isDisposing) return;
    if (_entry == null) {
      _show();
    } else {
      _hide();
    }
  }

  void _show() {
    if (!mounted || _isDisposing || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _queryController.clear();
    _resolveOverlayPlacement(overlay);
    _entry = OverlayEntry(
      builder: (_) => StatefulBuilder(
        builder: (context, setOverlayState) {
          _overlaySetState = setOverlayState;
          return _buildOverlay();
        },
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      _searchFocusNode.requestFocus();
      _overlaySetState?.call(() {});
      _scrollToSelected();
    });
  }

  void _hide({bool notify = true}) {
    _entry?.remove();
    _entry = null;
    _overlaySetState = null;
    if (notify && mounted && !_isDisposing) setState(() {});
  }

  void _pick(UiSelectOption<T> option) {
    widget.onChanged?.call(option.value);
    _hide();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final idx = _selectedVisibleIndex;
    if (idx < 0) return;
    final rowHeight = _estimatedRowHeight();
    final target = math.max(0.0, idx * rowHeight - _menuMaxHeight / 2);
    _scrollController.jumpTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  double _estimatedRowHeight() {
    final tokens = UiThemeTokens.of(context);
    return math.max(40.0, tokens.spacing.x2 * 2 + 20);
  }

  Widget _buildOverlay() {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final verticalOffset = tokens.spacing.x1;
    final indexes = _visibleIndexes;
    final rowCacheExtent = _estimatedRowHeight() * 6;

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleOverlayPointerDown,
          ),
        ),
        if (_targetOverlayRect != null)
          Positioned.fromRect(
            rect: _targetOverlayRect!,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _hide(),
            ),
          ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _openAbove ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _openAbove ? Alignment.bottomLeft : Alignment.topLeft,
          offset: Offset(
            _horizontalOffset,
            (_openAbove ? -verticalOffset : verticalOffset) + _anchorOffset,
          ),
          child: SizedBox(
            width: _menuWidth,
            child: _ComboboxMenuReveal(
              openAbove: _openAbove,
              duration: tokens.motion.standard,
              curve: tokens.motion.standardCurve,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _menuMaxHeight),
                child: UiBox(
                  key: const ValueKey<String>('ui-combobox-menu'),
                  background: c.popover,
                  border: Border.all(color: c.border),
                  borderRadius: tokens.radius.mdAll,
                  boxShadow: tokens.shadows.md,
                  padding: EdgeInsets.all(tokens.spacing.x2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ComboboxSearchField(
                        key: const ValueKey<String>('ui-combobox-search'),
                        controller: _queryController,
                        focusNode: _searchFocusNode,
                        hint: widget.searchHint,
                      ),
                      SizedBox(height: tokens.spacing.x2),
                      Flexible(
                        child: indexes.isEmpty
                            ? Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: tokens.spacing.x3,
                                  vertical: tokens.spacing.x4,
                                ),
                                child: UiText(
                                  widget.emptyText,
                                  variant: UiTextVariant.body,
                                  tone: UiTextTone.muted,
                                ),
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                primary: false,
                                scrollCacheExtent: ScrollCacheExtent.pixels(
                                  rowCacheExtent,
                                ),
                                itemCount: indexes.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: tokens.spacing.x1),
                                itemBuilder: (context, i) {
                                  final option = widget.options[indexes[i]];
                                  return _buildRow(option);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    final targetRect = _targetGlobalRect;
    if (targetRect == null || targetRect.contains(event.position)) {
      _hide();
      return;
    }
    _hide();
  }

  Widget _buildRow(UiSelectOption<T> option) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final isSelected = option.value == widget.value;

    return UiPressable(
      onPressed: () => _pick(option),
      minTapSize: 0,
      builder: (context, state, _) {
        final background = state.hovered || state.pressed
            ? c.accent
            : isSelected
                ? c.accent.withValues(alpha: 0.68)
                : const Color(0x00000000);
        final fullOverride =
            widget.optionBuilder?.call(context, option, isSelected);
        final labelSlot = option.labelBuilder != null
            ? option.labelBuilder!(context, option, isSelected)
            : UiText(
                option.label,
                variant: UiTextVariant.body,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : null,
                  color: c.popoverForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );

        final content = fullOverride ??
            Row(
              children: [
                if (option.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: c.popoverForeground, size: 16),
                    child: option.leading!,
                  ),
                  SizedBox(width: tokens.spacing.x2),
                ],
                Expanded(
                  child: option.subtitle == null
                      ? labelSlot
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            labelSlot,
                            SizedBox(height: tokens.spacing.x1 / 2),
                            UiText(
                              option.subtitle!,
                              variant: UiTextVariant.caption,
                              tone: UiTextTone.muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
                if (isSelected) ...[
                  SizedBox(width: tokens.spacing.x2),
                  Icon(
                    LucideIcons.check,
                    size: 16,
                    color: c.popoverForeground,
                  ),
                ],
              ],
            );

        return UiBox(
          background: background,
          borderRadius: tokens.radius.mdAll,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.x3,
            vertical: tokens.spacing.x2,
          ),
          child: content,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final open = _entry != null;
    final selected = _selected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.shrinkWrap
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          UiText(widget.label!, variant: UiTextVariant.label),
          SizedBox(height: tokens.spacing.x1),
        ],
        CompositedTransformTarget(
          key: _targetKey,
          link: _link,
          child: UiPressable(
            enabled: !_disabled,
            onPressed: _toggle,
            semanticsLabel: widget.label ?? widget.hint,
            builder: (context, state, _) {
              final triggerRadius = tokens.radius.mdAll;
              return UiFocusRing(
                visible: state.focused || open,
                borderRadius: triggerRadius,
                child: AnimatedContainer(
                  duration: tokens.motion.fast,
                  curve: tokens.motion.standardCurve,
                  decoration: BoxDecoration(
                    color: _disabled ? c.muted : c.surface,
                    border: Border.all(color: open ? c.ring : c.input),
                    borderRadius: triggerRadius,
                  ),
                  constraints: BoxConstraints(
                    minHeight: UiButtonMetrics.minHeight(widget.size),
                    minWidth:
                        widget.shrinkWrap && open ? _triggerWidth ?? 0 : 0,
                  ),
                  padding: _paddingFor(widget.size, tokens),
                  child: Row(
                    mainAxisSize:
                        widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      Flexible(
                        fit: widget.shrinkWrap ? FlexFit.loose : FlexFit.tight,
                        child: widget.valueBuilder != null
                            ? widget.valueBuilder!(context, selected)
                            : UiText(
                                selected?.label ?? widget.hint ?? '',
                                variant: UiTextVariant.body,
                                tone: selected == null
                                    ? UiTextTone.muted
                                    : UiTextTone.primary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      SizedBox(width: tokens.spacing.x2),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: tokens.motion.fast,
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: c.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static EdgeInsets _paddingFor(UiSize size, UiThemeTokens t) {
    switch (size) {
      case UiSize.sm:
      case UiSize.md:
        return EdgeInsets.symmetric(horizontal: t.spacing.x3);
      case UiSize.lg:
        return EdgeInsets.symmetric(horizontal: t.spacing.x4);
    }
  }

  void _resolveOverlayPlacement(OverlayState overlay) {
    final tokens = UiThemeTokens.of(context);
    final rowHeight = _estimatedRowHeight();
    final visibleRows = math.min(widget.options.length, 7);
    final desiredHeight = UiButtonMetrics.minHeight(UiSize.md) +
        tokens.spacing.x2 +
        tokens.spacing.x2 * 2 +
        visibleRows * rowHeight +
        math.max(0, visibleRows - 1) * tokens.spacing.x1;
    final maxAllowed = math.min(360.0, desiredHeight);
    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: desiredHeight,
      maxHeight: maxAllowed,
      minWidth: 220,
    );
    if (geometry == null) return;

    _targetOverlayRect = geometry.targetOverlayRect;
    _targetGlobalRect = geometry.targetGlobalRect;
    _triggerWidth = geometry.triggerWidth;
    _openAbove = geometry.openAbove;
    _menuMaxHeight = geometry.maxHeight;
    _menuWidth = geometry.width;
    _horizontalOffset = geometry.horizontalOffset;

    _anchorOffset = 0;
    if (widget.placement == UiSelectPlacement.anchorSelected) {
      final idx = _selectedVisibleIndex;
      if (idx >= 0) {
        final rowStride = rowHeight + tokens.spacing.x1;
        final searchBlockHeight =
            UiButtonMetrics.minHeight(UiSize.md) + tokens.spacing.x2;
        final rowCenterOffset = tokens.spacing.x2 +
            searchBlockHeight +
            idx * rowStride +
            rowHeight / 2;
        final baseTop = geometry.openAbove
            ? geometry.targetOverlayRect.top - geometry.gap - geometry.maxHeight
            : geometry.targetOverlayRect.bottom + geometry.gap;
        var shift =
            geometry.targetOverlayRect.center.dy - rowCenterOffset - baseTop;
        final minShift = geometry.topLimit - baseTop;
        final maxShift = geometry.bottomLimit - geometry.maxHeight - baseTop;
        shift = shift.clamp(
          math.min(minShift, maxShift),
          math.max(minShift, maxShift),
        );
        _anchorOffset = shift;
      }
    }
  }
}

class _ComboboxSearchField extends StatelessWidget {
  const _ComboboxSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    return UiBox(
      background: c.surface,
      border: Border.all(color: focusNode.hasFocus ? c.ring : c.input),
      borderRadius: tokens.radius.mdAll,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.x3),
      height: UiButtonMetrics.minHeight(UiSize.md),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: c.mutedForeground),
          SizedBox(width: tokens.spacing.x2),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (controller.text.isEmpty)
                  IgnorePointer(
                    child: UiText(
                      hint,
                      variant: UiTextVariant.body,
                      tone: UiTextTone.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                EditableText(
                  controller: controller,
                  focusNode: focusNode,
                  style: tokens.typography.body.copyWith(color: c.foreground),
                  cursorColor: c.primary,
                  backgroundCursorColor: c.input,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  maxLines: 1,
                  showCursor: false,
                  enableInteractiveSelection: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboboxMenuReveal extends StatefulWidget {
  const _ComboboxMenuReveal({
    required this.openAbove,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final bool openAbove;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_ComboboxMenuReveal> createState() => _ComboboxMenuRevealState();
}

class _ComboboxMenuRevealState extends State<_ComboboxMenuReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = widget.curve.transform(_controller.value);
        return RepaintBoundary(
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (widget.openAbove ? 4 : -4) * (1 - t)),
              child: Transform.scale(
                scale: 0.98 + t * 0.02,
                alignment: widget.openAbove
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
