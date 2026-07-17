import 'dart:math' as math;

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/overlay/overlay.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart' show UiButtonMetrics, UiSize;

/// Builder for the label slot inside an option row — replaces the
/// default `Text(option.label)` while keeping the row's default chrome
/// (padding, hover background, selected check).
typedef UiSelectOptionLabelBuilder<T> = Widget Function(
  BuildContext context,
  UiSelectOption<T> option,
  bool selected,
);

/// Single item in a [UiSelect].
///
/// [value] and [label] are always required: [value] is the typed
/// identity of the option, and [label] is the string form used for the
/// trigger's collapsed display, accessibility, and screen-reader
/// announcements. Everything else is presentation.
///
/// For richer rows that still sit inside the default row chrome, supply
/// either:
/// - [leading] — a leading widget (avatar, swatch, icon) painted to
///   the left of the label;
/// - [subtitle] — a secondary line of text under the label;
/// - [labelBuilder] — a full override for the label widget. The builder
///   receives the selected state so it can tweak weight/colour/etc.
///
/// When [labelBuilder] is set the default `label` Text is replaced, but
/// the surrounding row (padding, hover highlight, check glyph, leading,
/// subtitle) is preserved. Use [UiSelect.optionBuilder] when you need
/// to swap out the whole row, not just the label slot.
@immutable
class UiSelectOption<T> {
  const UiSelectOption({
    required this.value,
    required this.label,
    this.leading,
    this.subtitle,
    this.labelBuilder,
  });

  /// Typed identity; this is what [UiSelect.onChanged] emits and what
  /// [UiSelect.value] compares against.
  final T value;

  /// Plain-text label. Used by the collapsed trigger, the default row
  /// label, and accessibility announcements.
  final String label;

  /// Optional widget drawn to the left of the label inside the row.
  /// Typical uses: country flag, colour swatch, status dot.
  final Widget? leading;

  /// Optional second line rendered beneath the label.
  final String? subtitle;

  /// Optional widget builder that replaces only the label slot. Prefer
  /// this over [UiSelect.optionBuilder] when you want custom label
  /// rendering but still want the default row chrome around it.
  final UiSelectOptionLabelBuilder<T>? labelBuilder;
}

typedef UiSelectValidator<T> = String? Function(T? value);

/// Placement strategy used when the dropdown opens.
enum UiSelectPlacement {
  /// Default: open below when there's room, otherwise above.
  auto,

  /// Anchor the selected item directly over the trigger, like a native
  /// picker. Falls back to [auto] when there is no selected value.
  anchorSelected,
}

/// Builder for the dropdown option row.
typedef UiSelectOptionBuilder<T> = Widget Function(
  BuildContext context,
  UiSelectOption<T> option,
  bool selected,
);

/// Builder for the value shown inside the closed trigger.
typedef UiSelectValueBuilder<T> = Widget Function(
  BuildContext context,
  UiSelectOption<T>? selected,
);

/// Generic dropdown select.
///
/// Value-based API — pass [value] + [onChanged] like a standard controlled
/// input. The menu is rendered through the ambient `Overlay` so its
/// styling stays consistent with the rest of the kit (no Material popup
/// inside the list).
class UiSelect<T> extends StatefulWidget {
  const UiSelect({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.enabled = true,
    this.size = UiSize.md,
    this.placement = UiSelectPlacement.auto,
    this.optionBuilder,
    this.valueBuilder,
    this.shrinkWrap = false,
  });

  final List<UiSelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final UiSelectValidator<T>? validator;
  final bool enabled;
  final UiSize size;

  /// How the overlay positions itself relative to the trigger.
  final UiSelectPlacement placement;

  /// Optional override for rendering each dropdown row.
  final UiSelectOptionBuilder<T>? optionBuilder;

  /// Optional override for rendering the value inside the closed trigger.
  final UiSelectValueBuilder<T>? valueBuilder;

  /// When true the trigger sizes to its content instead of stretching to the
  /// parent's full width — for compact, inline placements (e.g. a top-bar
  /// language switcher).
  final bool shrinkWrap;

  @override
  State<UiSelect<T>> createState() => UiSelectState<T>();
}

class UiSelectState<T> extends State<UiSelect<T>> {
  final GlobalKey _targetKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _entry;
  String? _internalError;
  bool _openAbove = false;
  bool _isDisposing = false;
  double _menuWidth = 160;
  double _menuMaxHeight = 240;
  double _horizontalOffset = 0;
  double _anchorOffset = 0;
  double? _triggerWidth;
  Rect? _targetOverlayRect;
  Rect? _targetGlobalRect;

  String? get errorText => widget.errorText ?? _internalError;

  bool get _disabled => !widget.enabled || widget.onChanged == null;

  int get _selectedIndex {
    for (var i = 0; i < widget.options.length; i++) {
      if (widget.options[i].value == widget.value) return i;
    }
    return -1;
  }

  bool validate() {
    final v = widget.validator;
    if (v == null) return true;
    final err = v(widget.value);
    setState(() => _internalError = err);
    return err == null;
  }

  @override
  void dispose() {
    _isDisposing = true;
    _hide(notify: false);
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!mounted || _isDisposing) return;
    if (_entry != null) {
      _hide();
    } else {
      _show();
    }
  }

  void _show() {
    if (!mounted || _isDisposing || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _resolveOverlayPlacement(overlay);
    _entry = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_entry!);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _hide({bool notify = true}) {
    _removeOverlayEntry();
    if (notify && mounted && !_isDisposing) setState(() {});
  }

  void _removeOverlayEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _pick(UiSelectOption<T> option) {
    widget.onChanged?.call(option.value);
    if (_internalError != null) _internalError = null;
    _hide();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final idx = _selectedIndex;
    if (idx < 0) return;
    final rowHeight = _estimatedRowHeight();
    final target = math.max(0.0, idx * rowHeight - _menuMaxHeight / 2);
    _scrollController.jumpTo(
      target.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
    );
  }

  double _estimatedRowHeight() {
    final tokens = UiThemeTokens.of(context);
    return tokens.spacing.x2 * 2 + 20;
  }

  Widget _buildOverlay() {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final verticalOffset = tokens.spacing.x1;
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
            child: _AnimatedMenuReveal(
              openAbove: _openAbove,
              duration: tokens.motion.standard,
              curve: tokens.motion.standardCurve,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _menuMaxHeight),
                child: UiBox(
                  key: const ValueKey<String>('ui-select-menu'),
                  background: c.popover,
                  border: Border.all(color: c.border),
                  borderRadius: tokens.radius.mdAll,
                  boxShadow: tokens.shadows.md,
                  child: ListView.separated(
                    controller: _scrollController,
                    primary: false,
                    padding: EdgeInsets.all(tokens.spacing.x2),
                    scrollCacheExtent: ScrollCacheExtent.pixels(
                      rowCacheExtent,
                    ),
                    itemCount: widget.options.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: tokens.spacing.x1),
                    itemBuilder: (context, i) => _buildRow(widget.options[i]),
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

        // Full row override wins: caller provides their own row from
        // scratch, the kit supplies nothing else.
        final fullOverride =
            widget.optionBuilder?.call(context, option, isSelected);

        // Label slot: either a caller-provided builder, or the default
        // Text(option.label). Either way, weight updates based on
        // selection so the hierarchy matches shadcn.
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
    final error = errorText;
    final hasError = error != null && error.isNotEmpty;
    final open = _entry != null;

    UiSelectOption<T>? selected;
    for (final o in widget.options) {
      if (o.value == widget.value) {
        selected = o;
        break;
      }
    }

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
              final borderColor = hasError ? c.destructive : c.input;
              final triggerRadius = tokens.radius.mdAll;
              return UiFocusRing(
                visible: (state.focused || open) && !hasError,
                borderRadius: triggerRadius,
                child: AnimatedContainer(
                  duration: tokens.motion.fast,
                  curve: tokens.motion.standardCurve,
                  decoration: BoxDecoration(
                    color: _disabled ? c.muted : c.surface,
                    border: Border.all(color: borderColor),
                    borderRadius: triggerRadius,
                  ),
                  constraints: BoxConstraints(
                    minHeight: _minHeightFor(widget.size),
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
        if (hasError) ...[
          SizedBox(height: tokens.spacing.x1),
          UiText(
            error,
            variant: UiTextVariant.caption,
            tone: UiTextTone.danger,
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

  /// Trigger height per size. Sourced from [UiButtonMetrics] so the
  /// select and the button stay on the same baseline at every size
  /// without having to keep two switch statements in sync.
  static double _minHeightFor(UiSize size) => UiButtonMetrics.minHeight(size);

  /// Trigger padding per size. Matches shadcn's select literally
  /// (`h-9 px-3 py-2`): horizontal is tight (12pt) at sm/md because
  /// selects stretch to full form-field width, and vertical padding
  /// is zero — the `minHeight` constraint owns the vertical rhythm so
  /// content sits centred in the 32/36/40pt tall trigger. Adding
  /// explicit vertical strips on top of `minHeight` is what made the
  /// previous version look taller than shadcn's reference.
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
    final rowHeight = math.max(40.0, tokens.spacing.x2 * 2 + 20);
    final separators = math.max(0, widget.options.length - 1);
    final desiredHeight = tokens.spacing.x2 * 2 +
        widget.options.length * rowHeight +
        separators * tokens.spacing.x1;
    final maxAllowed = math.min(320.0, desiredHeight);
    final geometry = resolveUiAnchoredOverlayGeometry(
      context: context,
      targetKey: _targetKey,
      overlay: overlay,
      desiredHeight: desiredHeight,
      maxHeight: maxAllowed,
      minWidth: 160,
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
      final idx = _selectedIndex;
      if (idx >= 0) {
        final rowStride = rowHeight + tokens.spacing.x1;
        final rowCenterOffset =
            tokens.spacing.x2 + idx * rowStride + rowHeight / 2;
        // Shift the menu so the selected row centers on the trigger line.
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

class _AnimatedMenuReveal extends StatefulWidget {
  const _AnimatedMenuReveal({
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
  State<_AnimatedMenuReveal> createState() => _AnimatedMenuRevealState();
}

class _AnimatedMenuRevealState extends State<_AnimatedMenuReveal>
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
