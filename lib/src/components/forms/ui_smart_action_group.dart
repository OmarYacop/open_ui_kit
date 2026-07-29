import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/primitives/ui_focus_ring.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'button.dart';

/// One command rendered by [UiSmartActionGroup].
///
/// The [id] must be stable across rebuilds. The group uses it to morph labels
/// and controls between collapsed and expanded states instead of replacing the
/// whole action row abruptly.
@immutable
class UiSmartActionGroupAction {
  const UiSmartActionGroupAction({
    required this.id,
    required this.label,
    required this.onPressed,
    this.intent = UiIntent.defaultIntent,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.loading = false,
    this.showBorder = true,
    this.semanticsLabel,
    this.flex = 1,
    this.expandedFlex,
  })  : assert(flex > 0, 'flex must be greater than zero'),
        assert(
          expandedFlex == null || expandedFlex > 0,
          'expandedFlex must be greater than zero',
        );

  /// Stable identity used for animated transitions.
  final Object id;

  /// Visible button label.
  final String label;

  /// Called when the action is activated. `null` disables the action.
  final VoidCallback? onPressed;

  /// Button visual intent.
  final UiIntent intent;

  /// Optional leading widget, usually an icon.
  final Widget? leading;

  /// Optional trailing widget, usually an icon.
  final Widget? trailing;

  /// Whether this action can be activated.
  final bool enabled;

  /// Whether this action is currently processing.
  final bool loading;

  /// Whether to paint the resolved button outline.
  final bool showBorder;

  /// Spoken label. Defaults to [label].
  final String? semanticsLabel;

  /// Width share used by the action in collapsed wide layouts.
  final int flex;

  /// Optional width share used by the action in expanded wide layouts.
  final int? expandedFlex;
}

/// How flexible actions divide the wide layout after an overflow group expands.
enum UiSmartActionGroupExpandedLayout {
  /// Expanded actions and the collapse control use equal width shares.
  equal,

  /// Expanded actions keep their configured [UiSmartActionGroupAction.flex] /
  /// [UiSmartActionGroupAction.expandedFlex] ratios and the collapse control
  /// keeps its fixed width.
  actionFlex,
}

/// Experimental inline action group for replacing "More" sheets with morphing
/// buttons.
///
/// This renderer is geometry-first: every frame is solved as a list of exact
/// button rectangles before any widgets are built. That keeps width, gaps,
/// opacity, and hit testing coordinated and avoids transient Flex overflows.
class UiSmartActionGroup extends StatefulWidget {
  const UiSmartActionGroup({
    super.key,
    required this.actions,
    this.collapsedCount = 1,
    this.expanded,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.size = UiSize.sm,
    this.moreLabel = 'More',
    this.collapseLabel = 'Less',
    this.moreIcon = const Icon(LucideIcons.ellipsis),
    this.collapseIcon = const Icon(LucideIcons.chevronUp),
    this.moreIntent = UiIntent.neutral,
    this.collapseIntent = UiIntent.neutral,
    this.showCollapseAction = true,
    this.collapseOnAction = false,
    this.expandedLayout = UiSmartActionGroupExpandedLayout.equal,
    this.moreButtonWidth,
    this.collapseButtonWidth,
    this.compactBreakpoint = 420,
    this.spacing,
    this.duration = UiMotionDuration.slow,
    this.curve,
    this.semanticLabel,
  })  : assert(collapsedCount > 0, 'collapsedCount must be greater than zero'),
        assert(
          compactBreakpoint > 0,
          'compactBreakpoint must be greater than zero',
        ),
        assert(
          moreButtonWidth == null || moreButtonWidth > 0,
          'moreButtonWidth must be greater than zero',
        ),
        assert(
          collapseButtonWidth == null || collapseButtonWidth > 0,
          'collapseButtonWidth must be greater than zero',
        );

  /// Ordered actions. The first [collapsedCount] stay visible while collapsed.
  final List<UiSmartActionGroupAction> actions;

  /// Number of leading actions shown before the "more" control.
  final int collapsedCount;

  /// Controlled expanded state. When `null`, the widget owns its state.
  final bool? expanded;

  /// Initial uncontrolled expanded state.
  final bool initiallyExpanded;

  /// Called whenever the expanded state should change.
  final ValueChanged<bool>? onExpandedChanged;

  /// Button size applied to every action.
  final UiSize size;

  /// Label for the collapsed overflow control.
  final String moreLabel;

  /// Label for the expanded collapse control.
  final String collapseLabel;

  /// Leading icon for the collapsed overflow control.
  final Widget moreIcon;

  /// Leading icon for the expanded collapse control.
  final Widget collapseIcon;

  /// Intent for the collapsed overflow control.
  final UiIntent moreIntent;

  /// Intent for the expanded collapse control.
  final UiIntent collapseIntent;

  /// Whether to append a collapse button when expanded.
  final bool showCollapseAction;

  /// Whether activating a non-toggle action collapses the group first.
  ///
  /// Defaults to `false` so callers explicitly choose whether action presses
  /// close the expanded set.
  final bool collapseOnAction;

  /// Width policy once the hidden actions are shown in wide layouts.
  final UiSmartActionGroupExpandedLayout expandedLayout;

  /// Fixed wide-layout width for the collapsed overflow control.
  final double? moreButtonWidth;

  /// Fixed wide-layout width for the expanded collapse control.
  final double? collapseButtonWidth;

  /// Below this width the group falls back to a horizontal scroll viewport.
  final double compactBreakpoint;

  /// Gap between buttons. Defaults to the token x2 spacing.
  final double? spacing;

  final UiMotionDuration duration;

  /// Override transition curve. Defaults to theme standard curve.
  final Curve? curve;

  /// Spoken label for the semantic group.
  final String? semanticLabel;

  @override
  State<UiSmartActionGroup> createState() => _UiSmartActionGroupState();
}

/// Two-button confirmation group with coordinated width and label morphs.
///
/// The primary action first enters a confirmation state. In that state the
/// primary button expands and changes to [confirmLabel], while the secondary
/// button shrinks and becomes [cancelLabel].
class UiConfirmActionGroup extends StatefulWidget {
  const UiConfirmActionGroup({
    super.key,
    required this.actionLabel,
    required this.onConfirm,
    this.confirmLabel = 'Are you sure?',
    this.cancelLabel = 'Cancel',
    this.secondaryLabel,
    this.onCancel,
    this.onSecondaryPressed,
    this.confirming,
    this.initiallyConfirming = false,
    this.onConfirmingChanged,
    this.resetKey,
    this.actionIntent = UiIntent.destructive,
    this.confirmIntent,
    this.secondaryIntent = UiIntent.neutral,
    this.cancelIntent = UiIntent.neutral,
    this.actionLeading,
    this.confirmLeading,
    this.secondaryLeading,
    this.cancelLeading,
    this.isProcessing = false,
    this.actionDisabled = false,
    this.secondaryDisabled = false,
    this.actionShowBorder = true,
    this.secondaryShowBorder = true,
    this.size = UiSize.sm,
    this.primaryFlex = 1,
    this.confirmingPrimaryFlex = 2,
    this.secondaryFlex = 2,
    this.confirmingSecondaryFlex = 1,
    this.compactBreakpoint = 420,
    this.spacing,
    this.duration = UiMotionDuration.slow,
    this.curve,
    this.semanticLabel,
  })  : assert(primaryFlex > 0, 'primaryFlex must be greater than zero'),
        assert(
          confirmingPrimaryFlex > 0,
          'confirmingPrimaryFlex must be greater than zero',
        ),
        assert(secondaryFlex > 0, 'secondaryFlex must be greater than zero'),
        assert(
          confirmingSecondaryFlex > 0,
          'confirmingSecondaryFlex must be greater than zero',
        ),
        assert(
          compactBreakpoint > 0,
          'compactBreakpoint must be greater than zero',
        );

  /// Initial primary label, for example "Save" or "Delete".
  final String actionLabel;

  /// Primary label once confirmation is active.
  final String confirmLabel;

  /// Secondary label once confirmation is active.
  final String cancelLabel;

  /// Secondary label before confirmation. Defaults to [cancelLabel].
  final String? secondaryLabel;

  /// Called when the confirming primary button is activated.
  final VoidCallback onConfirm;

  /// Called when the confirming secondary button cancels confirmation.
  final VoidCallback? onCancel;

  /// Called by the secondary button before confirmation is active.
  final VoidCallback? onSecondaryPressed;

  /// Controlled confirming state. When `null`, the widget owns its state.
  final bool? confirming;

  /// Initial uncontrolled confirming state.
  final bool initiallyConfirming;

  /// Called when the confirming state should change.
  final ValueChanged<bool>? onConfirmingChanged;

  /// Changing this value resets uncontrolled confirming state.
  final Object? resetKey;

  /// Primary intent before confirmation.
  final UiIntent actionIntent;

  /// Primary intent during confirmation. Defaults to [actionIntent].
  final UiIntent? confirmIntent;

  /// Secondary intent before confirmation.
  final UiIntent secondaryIntent;

  /// Secondary intent during confirmation.
  final UiIntent cancelIntent;

  /// Optional primary leading widget before confirmation.
  final Widget? actionLeading;

  /// Optional primary leading widget during confirmation.
  final Widget? confirmLeading;

  /// Optional secondary leading widget before confirmation.
  final Widget? secondaryLeading;

  /// Optional secondary leading widget during confirmation.
  final Widget? cancelLeading;

  /// Whether the confirm action is processing.
  final bool isProcessing;

  /// Whether the primary action is disabled before confirmation.
  final bool actionDisabled;

  /// Whether the secondary action is disabled before confirmation.
  final bool secondaryDisabled;

  /// Whether to paint the primary button outline when its style resolves one.
  final bool actionShowBorder;

  /// Whether to paint the secondary button outline when its style resolves one.
  final bool secondaryShowBorder;

  /// Button size applied to both controls.
  final UiSize size;

  /// Primary width share before confirmation.
  final int primaryFlex;

  /// Primary width share during confirmation.
  final int confirmingPrimaryFlex;

  /// Secondary width share before confirmation.
  final int secondaryFlex;

  /// Secondary width share during confirmation.
  final int confirmingSecondaryFlex;

  /// Below this width the group falls back to a horizontal scroll viewport.
  final double compactBreakpoint;

  /// Gap between buttons. Defaults to the token x2 spacing.
  final double? spacing;

  final UiMotionDuration duration;

  /// Override transition curve. Defaults to theme standard curve.
  final Curve? curve;

  /// Spoken label for the semantic group.
  final String? semanticLabel;

  @override
  State<UiConfirmActionGroup> createState() => _UiConfirmActionGroupState();
}

/// Minimal input item for testing the geometry engine without widgets.
@visibleForTesting
@immutable
class UiActionGroupGeometryItem {
  const UiActionGroupGeometryItem({
    required this.id,
    this.flex = 1,
    this.fixedExtent,
  })  : assert(flex > 0, 'flex must be greater than zero'),
        assert(
          fixedExtent == null || fixedExtent > 0,
          'fixedExtent must be greater than zero',
        );

  final Object id;
  final int flex;
  final double? fixedExtent;
}

/// Solved physical placement for one action-group slot.
@visibleForTesting
@immutable
class UiActionGroupGeometrySlot {
  const UiActionGroupGeometrySlot({
    required this.id,
    required this.rect,
    required this.opacity,
    required this.contentOpacity,
  });

  final Object id;
  final Rect rect;
  final double opacity;
  final double contentOpacity;
}

/// Solved size and child slots for one action-group frame.
@visibleForTesting
@immutable
class UiActionGroupGeometry {
  const UiActionGroupGeometry({
    required this.size,
    required this.slots,
  });

  final Size size;
  final List<UiActionGroupGeometrySlot> slots;
}

/// Geometry-first layout engine used by the smart action renderers.
@visibleForTesting
class UiActionGroupGeometrySolver {
  const UiActionGroupGeometrySolver._();

  static UiActionGroupGeometry solveHorizontal({
    required List<UiActionGroupGeometryItem> fromItems,
    required List<UiActionGroupGeometryItem> toItems,
    required double maxWidth,
    required double height,
    required double spacing,
    required double progress,
  }) {
    if (maxWidth <= 0 || height <= 0 || toItems.isEmpty) {
      return const UiActionGroupGeometry(size: Size.zero, slots: []);
    }

    final t = progress.clamp(0.0, 1.0);
    final fromWidths = _widthsFor(fromItems, maxWidth, spacing);
    final toWidths = _widthsFor(toItems, maxWidth, spacing);
    final fromById = <Object, UiActionGroupGeometryItem>{
      for (final item in fromItems) item.id: item,
    };
    final toById = <Object, UiActionGroupGeometryItem>{
      for (final item in toItems) item.id: item,
    };
    final fromWidthById = <Object, double>{
      for (var i = 0; i < fromItems.length; i++) fromItems[i].id: fromWidths[i],
    };
    final toWidthById = <Object, double>{
      for (var i = 0; i < toItems.length; i++) toItems[i].id: toWidths[i],
    };
    final keepsTargetOrder = toItems.length >= fromItems.length;
    final primaryOrder = keepsTargetOrder ? toItems : fromItems;
    final secondaryOrder = keepsTargetOrder ? fromItems : toItems;
    final primaryById = {
      for (final item in primaryOrder) item.id: item,
    };
    final ids = <Object>[
      for (final item in primaryOrder) item.id,
      for (final item in secondaryOrder)
        if (!primaryById.containsKey(item.id)) item.id,
    ];

    final metrics = <_SolvedSlotMetric>[
      for (var i = 0; i < ids.length; i++)
        _SolvedSlotMetric(
          id: ids[i],
          width: _slotWidth(
            id: ids[i],
            fromWidthById: fromWidthById,
            toWidthById: toWidthById,
            fromById: fromById,
            toById: toById,
            fromItems: fromItems,
            toItems: toItems,
            progress: t,
          ),
          presence: _slotPresence(
            id: ids[i],
            fromById: fromById,
            toById: toById,
            fromItems: fromItems,
            toItems: toItems,
            progress: t,
          ),
        ),
    ];

    final withGaps = <_SolvedSlotMetric>[
      for (var i = 0; i < metrics.length; i++)
        metrics[i].copyWith(
          gapAfter: _gapAfter(metrics, i, spacing),
        ),
    ];
    final fitted = _fitAndFill(withGaps, maxWidth);

    var x = 0.0;
    final slots = <UiActionGroupGeometrySlot>[];
    for (final metric in fitted) {
      if (metric.width > 0.01 || metric.presence > 0.01) {
        slots.add(
          UiActionGroupGeometrySlot(
            id: metric.id,
            rect: Rect.fromLTWH(x, 0, math.max(0, metric.width), height),
            opacity: metric.presence.clamp(0.0, 1.0),
            contentOpacity: _contentOpacity(metric.presence),
          ),
        );
      }
      x += metric.width + metric.gapAfter;
    }

    return UiActionGroupGeometry(
      size: Size(maxWidth, height),
      slots: slots,
    );
  }

  static List<double> _widthsFor(
    List<UiActionGroupGeometryItem> items,
    double maxWidth,
    double spacing,
  ) {
    if (items.isEmpty) return const <double>[];

    final gaps = math.max(0, items.length - 1) * spacing;
    final available = math.max(0.0, maxWidth - gaps);
    final fixedTotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.fixedExtent ?? 0),
    );
    final flexible = [
      for (final item in items)
        if (item.fixedExtent == null) item,
    ];
    if (flexible.isEmpty) {
      final evenWidth = available / items.length;
      return [for (final item in items) item.fixedExtent ?? evenWidth];
    }

    final remaining = math.max(0.0, available - fixedTotal);
    final flexTotal = flexible.fold<int>(0, (sum, item) => sum + item.flex);
    return [
      for (final item in items)
        if (item.fixedExtent != null)
          math.min(item.fixedExtent!, available)
        else
          remaining * item.flex / flexTotal,
    ];
  }

  static double _slotWidth({
    required Object id,
    required Map<Object, double> fromWidthById,
    required Map<Object, double> toWidthById,
    required Map<Object, UiActionGroupGeometryItem> fromById,
    required Map<Object, UiActionGroupGeometryItem> toById,
    required List<UiActionGroupGeometryItem> fromItems,
    required List<UiActionGroupGeometryItem> toItems,
    required double progress,
  }) {
    final fromWidth = fromWidthById[id];
    final toWidth = toWidthById[id];
    if (fromWidth != null && toWidth != null) {
      return lerpDouble(fromWidth, toWidth, progress)!;
    }

    final presence = _slotPresence(
      id: id,
      fromById: fromById,
      toById: toById,
      fromItems: fromItems,
      toItems: toItems,
      progress: progress,
    );
    return (toWidth ?? fromWidth ?? 0) * presence;
  }

  static double _slotPresence({
    required Object id,
    required Map<Object, UiActionGroupGeometryItem> fromById,
    required Map<Object, UiActionGroupGeometryItem> toById,
    required List<UiActionGroupGeometryItem> fromItems,
    required List<UiActionGroupGeometryItem> toItems,
    required double progress,
  }) {
    final existed = fromById.containsKey(id);
    final exists = toById.containsKey(id);
    if (existed && exists) return 1;

    final items = exists ? toItems : fromItems;
    final index = math.max(0, items.indexWhere((item) => item.id == id));
    return _orderedPresence(
      index: index,
      count: items.length,
      progress: progress,
      entering: exists,
    );
  }

  static double _orderedPresence({
    required int index,
    required int count,
    required double progress,
    required bool entering,
  }) {
    if (count <= 0) return entering ? progress : 1 - progress;
    final order = entering ? index : count - 1 - index;
    final step = count <= 1 ? 0.0 : 0.42 / (count - 1);
    final begin = order * step;
    final end = math.min(1.0, begin + 0.34);
    final value = _interval(progress, begin, end);
    return entering ? value : 1 - value;
  }

  static double _contentOpacity(double presence) {
    final value = _interval(presence, 0.48, 0.86);
    return _smooth(value);
  }

  static double _gapAfter(
    List<_SolvedSlotMetric> metrics,
    int index,
    double spacing,
  ) {
    if (index >= metrics.length - 1 || metrics[index].presence <= 0.001) {
      return 0;
    }
    final hasVisibleTrailingSlot =
        metrics.skip(index + 1).any((metric) => metric.presence > 0.001);
    return hasVisibleTrailingSlot ? spacing : 0;
  }

  static List<_SolvedSlotMetric> _fitAndFill(
    List<_SolvedSlotMetric> metrics,
    double maxWidth,
  ) {
    if (metrics.isEmpty) return metrics;

    final totalGaps =
        metrics.fold<double>(0, (sum, metric) => sum + metric.gapAfter);
    final totalWidths =
        metrics.fold<double>(0, (sum, metric) => sum + metric.width);
    final availableForWidths = math.max(0.0, maxWidth - totalGaps);

    if (totalWidths > availableForWidths + 0.01 && totalWidths > 0) {
      final scale = availableForWidths / totalWidths;
      return [
        for (final metric in metrics)
          metric.copyWith(width: metric.width * scale),
      ];
    }

    final slack = availableForWidths - totalWidths;
    if (slack <= 0.01) return metrics;

    final donorIndex = metrics.indexWhere((metric) => metric.presence >= 0.99);
    final index = donorIndex < 0 ? 0 : donorIndex;
    return [
      for (var i = 0; i < metrics.length; i++)
        i == index
            ? metrics[i].copyWith(width: metrics[i].width + slack)
            : metrics[i],
    ];
  }

  static double _interval(double value, double begin, double end) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return (value - begin) / (end - begin);
  }

  static double _smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

class _SolvedSlotMetric {
  const _SolvedSlotMetric({
    required this.id,
    required this.width,
    required this.presence,
    this.gapAfter = 0,
  });

  final Object id;
  final double width;
  final double presence;
  final double gapAfter;

  _SolvedSlotMetric copyWith({
    double? width,
    double? presence,
    double? gapAfter,
  }) {
    return _SolvedSlotMetric(
      id: id,
      width: width ?? this.width,
      presence: presence ?? this.presence,
      gapAfter: gapAfter ?? this.gapAfter,
    );
  }
}

enum _ConfirmActionId { primary, secondary }

enum _ToggleId { overflow }

class _UiConfirmActionGroupState extends State<UiConfirmActionGroup> {
  late bool _confirming = widget.initiallyConfirming;

  bool get _effectiveConfirming => widget.confirming ?? _confirming;

  @override
  void didUpdateWidget(covariant UiConfirmActionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.confirming == null && oldWidget.confirming != null) {
      _confirming = oldWidget.confirming!;
    }
    if (widget.confirming == null && widget.resetKey != oldWidget.resetKey) {
      _confirming = false;
    }
  }

  void _setConfirming(bool value) {
    if (widget.confirming == null) {
      setState(() => _confirming = value);
    }
    widget.onConfirmingChanged?.call(value);
  }

  void _handlePrimary() {
    if (widget.isProcessing || widget.actionDisabled) return;
    if (!_effectiveConfirming) {
      _setConfirming(true);
      return;
    }
    widget.onConfirm();
  }

  void _handleSecondary() {
    if (widget.isProcessing) return;
    if (_effectiveConfirming) {
      _setConfirming(false);
      widget.onCancel?.call();
      return;
    }
    if (widget.secondaryDisabled) return;
    widget.onSecondaryPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = widget.duration.resolve(context);
    final curve = reduceMotion
        ? tokens.motion.linearCurve
        : widget.curve ?? tokens.motion.standardCurve;
    final spacing = widget.spacing ?? tokens.spacing.x2;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = !constraints.hasBoundedWidth ||
              constraints.maxWidth < widget.compactBreakpoint;
          return _MechanicalActionGroup(
            entries: _entries(confirming: _effectiveConfirming),
            collapsedEntries: _entries(confirming: false),
            compact: compact,
            spacing: spacing,
            duration: duration,
            curve: curve,
            onExpandedChanged: _setConfirming,
            onAction: (action) => action.onPressed?.call(),
            size: widget.size,
          );
        },
      ),
    );
  }

  List<_ActionEntry> _entries({required bool confirming}) {
    return [
      _ActionEntry.action(
        UiSmartActionGroupAction(
          id: _ConfirmActionId.primary,
          label: confirming ? widget.confirmLabel : widget.actionLabel,
          onPressed: _handlePrimary,
          intent: confirming
              ? widget.confirmIntent ?? widget.actionIntent
              : widget.actionIntent,
          leading: confirming
              ? widget.confirmLeading ?? widget.actionLeading
              : widget.actionLeading,
          enabled: !widget.actionDisabled,
          loading: widget.isProcessing,
          showBorder: widget.actionShowBorder,
          flex: confirming ? widget.confirmingPrimaryFlex : widget.primaryFlex,
        ),
        expanded: confirming,
      ),
      _ActionEntry.action(
        UiSmartActionGroupAction(
          id: _ConfirmActionId.secondary,
          label: confirming
              ? widget.cancelLabel
              : widget.secondaryLabel ?? widget.cancelLabel,
          onPressed: _handleSecondary,
          intent: confirming ? widget.cancelIntent : widget.secondaryIntent,
          leading: confirming
              ? widget.cancelLeading ?? widget.secondaryLeading
              : widget.secondaryLeading,
          enabled: confirming || !widget.secondaryDisabled,
          showBorder: widget.secondaryShowBorder,
          flex: confirming
              ? widget.confirmingSecondaryFlex
              : widget.secondaryFlex,
        ),
        expanded: confirming,
      ),
    ];
  }
}

class _UiSmartActionGroupState extends State<UiSmartActionGroup> {
  late bool _expanded = widget.initiallyExpanded;

  bool get _effectiveExpanded => widget.expanded ?? _expanded;

  @override
  void didUpdateWidget(covariant UiSmartActionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == null && oldWidget.expanded != null) {
      _expanded = oldWidget.expanded!;
    }
  }

  void _setExpanded(bool value) {
    if (widget.expanded == null) {
      setState(() => _expanded = value);
    }
    widget.onExpandedChanged?.call(value);
  }

  void _handleAction(UiSmartActionGroupAction action) {
    if (widget.collapseOnAction && _effectiveExpanded) {
      _setExpanded(false);
    }
    action.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    final collapsedCount = widget.collapsedCount.clamp(1, actions.length);
    final hasOverflow = actions.length > collapsedCount;
    final expanded = _effectiveExpanded && hasOverflow;
    final tokens = UiThemeTokens.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = widget.duration.resolve(context);
    final curve = reduceMotion
        ? tokens.motion.linearCurve
        : widget.curve ?? tokens.motion.standardCurve;
    final spacing = widget.spacing ?? tokens.spacing.x2;
    final collapsedEntries = _entries(
      actions: actions,
      collapsedCount: collapsedCount,
      expanded: false,
      hasOverflow: hasOverflow,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = !constraints.hasBoundedWidth ||
              constraints.maxWidth < widget.compactBreakpoint;
          return _MechanicalActionGroup(
            entries: _entries(
              actions: actions,
              collapsedCount: collapsedCount,
              expanded: expanded,
              hasOverflow: hasOverflow,
            ),
            collapsedEntries: collapsedEntries,
            compact: compact,
            spacing: spacing,
            duration: duration,
            curve: curve,
            onExpandedChanged: _setExpanded,
            onAction: _handleAction,
            size: widget.size,
          );
        },
      ),
    );
  }

  List<_ActionEntry> _entries({
    required List<UiSmartActionGroupAction> actions,
    required int collapsedCount,
    required bool expanded,
    required bool hasOverflow,
  }) {
    if (!hasOverflow) {
      return [
        for (final action in actions)
          _ActionEntry.action(
            action,
            expanded: expanded,
            equalFlex: expanded &&
                widget.expandedLayout == UiSmartActionGroupExpandedLayout.equal,
          ),
      ];
    }

    if (!expanded) {
      return [
        for (final action in actions.take(collapsedCount))
          _ActionEntry.action(action, expanded: false),
        _ActionEntry.toggle(
          id: _ToggleId.overflow,
          label: widget.moreLabel,
          icon: widget.moreIcon,
          intent: widget.moreIntent,
          fixedWidth: widget.moreButtonWidth ?? _defaultToggleWidth(),
          targetExpanded: true,
        ),
      ];
    }

    return [
      for (final action in actions)
        _ActionEntry.action(
          action,
          expanded: true,
          equalFlex:
              widget.expandedLayout == UiSmartActionGroupExpandedLayout.equal,
        ),
      if (widget.showCollapseAction)
        _ActionEntry.toggle(
          id: _ToggleId.overflow,
          label: widget.collapseLabel,
          icon: widget.collapseIcon,
          intent: widget.collapseIntent,
          fixedWidth:
              widget.expandedLayout == UiSmartActionGroupExpandedLayout.equal
                  ? null
                  : widget.collapseButtonWidth ?? _defaultToggleWidth(),
          targetExpanded: false,
        ),
    ];
  }

  double _defaultToggleWidth() {
    switch (widget.size) {
      case UiSize.sm:
        return 92;
      case UiSize.md:
        return 104;
      case UiSize.lg:
        return 116;
    }
  }
}

class _ActionEntry {
  const _ActionEntry._({
    required this.id,
    required this.label,
    required this.intent,
    required this.leading,
    required this.trailing,
    required this.enabled,
    required this.loading,
    required this.showBorder,
    required this.semanticsLabel,
    required this.flex,
    required this.fixedWidth,
    required this.targetExpanded,
    required this.action,
  });

  factory _ActionEntry.action(
    UiSmartActionGroupAction action, {
    required bool expanded,
    bool equalFlex = false,
  }) {
    return _ActionEntry._(
      id: action.id,
      label: action.label,
      intent: action.intent,
      leading: action.leading,
      trailing: action.trailing,
      enabled: action.enabled,
      loading: action.loading,
      showBorder: action.showBorder,
      semanticsLabel: action.semanticsLabel,
      flex: equalFlex
          ? 1
          : expanded
              ? action.expandedFlex ?? action.flex
              : action.flex,
      fixedWidth: null,
      targetExpanded: null,
      action: action,
    );
  }

  factory _ActionEntry.toggle({
    required _ToggleId id,
    required String label,
    required Widget icon,
    required UiIntent intent,
    required double? fixedWidth,
    required bool targetExpanded,
  }) {
    return _ActionEntry._(
      id: id,
      label: label,
      intent: intent,
      leading: icon,
      trailing: null,
      enabled: true,
      loading: false,
      showBorder: true,
      semanticsLabel: label,
      flex: 1,
      fixedWidth: fixedWidth,
      targetExpanded: targetExpanded,
      action: null,
    );
  }

  final Object id;
  final String label;
  final UiIntent intent;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool loading;
  final bool showBorder;
  final String? semanticsLabel;
  final int flex;
  final double? fixedWidth;
  final bool? targetExpanded;
  final UiSmartActionGroupAction? action;

  bool get isToggle => targetExpanded != null;

  UiActionGroupGeometryItem get geometryItem {
    return UiActionGroupGeometryItem(
      id: id,
      flex: flex,
      fixedExtent: fixedWidth,
    );
  }
}

class _MechanicalActionGroup extends StatefulWidget {
  const _MechanicalActionGroup({
    required this.entries,
    required this.collapsedEntries,
    required this.compact,
    required this.spacing,
    required this.duration,
    required this.curve,
    required this.onExpandedChanged,
    required this.onAction,
    required this.size,
  });

  final List<_ActionEntry> entries;
  final List<_ActionEntry> collapsedEntries;
  final bool compact;
  final double spacing;
  final Duration duration;
  final Curve curve;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<UiSmartActionGroupAction> onAction;
  final UiSize size;

  @override
  State<_MechanicalActionGroup> createState() => _MechanicalActionGroupState();
}

class _MechanicalActionGroupState extends State<_MechanicalActionGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_ActionEntry> _fromEntries;
  late List<_ActionEntry> _toEntries;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _fromEntries = widget.entries;
    _toEntries = widget.entries;
    _signature = _entrySignature(widget.entries);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _fromEntries = _toEntries);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _MechanicalActionGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }

    final nextSignature = _entrySignature(widget.entries);
    if (nextSignature == _signature) return;

    _fromEntries = oldWidget.entries;
    _toEntries = widget.entries;
    _signature = nextSignature;
    if (widget.duration == Duration.zero) {
      _controller.value = 1;
      _fromEntries = _toEntries;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonHeight = _buttonLayoutHeight(widget.size);
    final animating = widget.duration != Duration.zero && _controller.value < 1;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : _fallbackWidth(_toEntries, widget.spacing, widget.size);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final raw =
                  widget.duration == Duration.zero ? 1.0 : _controller.value;
              final progress = widget.duration == Duration.zero
                  ? 1.0
                  : widget.curve.transform(raw);
              if (widget.compact) {
                return _buildCompact(
                  maxWidth: maxWidth,
                  buttonHeight: buttonHeight,
                  progress: progress,
                  animating: animating,
                );
              }
              return _buildHorizontal(
                maxWidth: maxWidth,
                buttonHeight: buttonHeight,
                progress: progress,
                animating: animating,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHorizontal({
    required double maxWidth,
    required double buttonHeight,
    required double progress,
    required bool animating,
  }) {
    final geometry = UiActionGroupGeometrySolver.solveHorizontal(
      fromItems: [for (final entry in _fromEntries) entry.geometryItem],
      toItems: [for (final entry in _toEntries) entry.geometryItem],
      maxWidth: maxWidth,
      height: buttonHeight,
      spacing: widget.spacing,
      progress: progress,
    );
    final fromById = {for (final entry in _fromEntries) entry.id: entry};
    final toById = {for (final entry in _toEntries) entry.id: entry};

    return SizedBox(
      width: geometry.size.width,
      height: geometry.size.height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final slot in geometry.slots)
            _PositionedMechanicalButton(
              key: ValueKey<Object>('slot-${slot.id}'),
              slot: slot,
              source: fromById[slot.id],
              target: toById[slot.id],
              progress: progress,
              interactive: !animating && slot.opacity > 0.99,
              onExpandedChanged: widget.onExpandedChanged,
              onAction: widget.onAction,
              size: widget.size,
            ),
        ],
      ),
    );
  }

  Widget _buildCompact({
    required double maxWidth,
    required double buttonHeight,
    required double progress,
    required bool animating,
  }) {
    final contentWidth = math.max(
      maxWidth,
      math.max(
        _fallbackWidth(_fromEntries, widget.spacing, widget.size),
        _fallbackWidth(_toEntries, widget.spacing, widget.size),
      ),
    );

    return SizedBox(
      width: maxWidth,
      height: buttonHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.hardEdge,
        child: _buildHorizontal(
          maxWidth: contentWidth,
          buttonHeight: buttonHeight,
          progress: progress,
          animating: animating,
        ),
      ),
    );
  }

  static double _fallbackWidth(
    List<_ActionEntry> entries,
    double spacing,
    UiSize size,
  ) {
    final buttonWidth = switch (size) {
      UiSize.sm => 112.0,
      UiSize.md => 132.0,
      UiSize.lg => 156.0,
    };
    return (buttonWidth * entries.length) +
        (spacing * math.max(0, entries.length - 1));
  }

  static String _entrySignature(List<_ActionEntry> entries) {
    return entries
        .map(
          (entry) => Object.hash(
            entry.id,
            entry.label,
            entry.intent,
            entry.enabled,
            entry.loading,
            entry.showBorder,
            entry.flex,
            entry.fixedWidth,
            entry.targetExpanded,
          ).toString(),
        )
        .join('|');
  }
}

class _PositionedMechanicalButton extends StatelessWidget {
  const _PositionedMechanicalButton({
    super.key,
    required this.slot,
    required this.source,
    required this.target,
    required this.progress,
    required this.interactive,
    required this.onExpandedChanged,
    required this.onAction,
    required this.size,
  });

  final UiActionGroupGeometrySlot slot;
  final _ActionEntry? source;
  final _ActionEntry? target;
  final double progress;
  final bool interactive;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<UiSmartActionGroupAction> onAction;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    if (slot.rect.width <= 0.01 || slot.rect.height <= 0.01) {
      return const SizedBox.shrink();
    }
    final layoutHeight = _buttonLayoutHeight(size);
    final revealsVertically = slot.rect.height < layoutHeight - 0.01;

    return Positioned(
      left: slot.rect.left,
      top: slot.rect.top,
      width: slot.rect.width,
      height: slot.rect.height,
      child: revealsVertically
          ? ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: slot.rect.width,
                maxWidth: slot.rect.width,
                minHeight: layoutHeight,
                maxHeight: layoutHeight,
                child: SizedBox(
                  width: slot.rect.width,
                  height: layoutHeight,
                  child: _MechanicalButton(
                    source: source,
                    target: target,
                    progress: progress,
                    opacity: slot.opacity,
                    contentOpacity: slot.contentOpacity,
                    interactive: interactive,
                    onExpandedChanged: onExpandedChanged,
                    onAction: onAction,
                    size: size,
                  ),
                ),
              ),
            )
          : _MechanicalButton(
              source: source,
              target: target,
              progress: progress,
              opacity: slot.opacity,
              contentOpacity: slot.contentOpacity,
              interactive: interactive,
              onExpandedChanged: onExpandedChanged,
              onAction: onAction,
              size: size,
            ),
    );
  }
}

class _MechanicalButton extends StatelessWidget {
  const _MechanicalButton({
    required this.source,
    required this.target,
    required this.progress,
    required this.opacity,
    required this.contentOpacity,
    required this.interactive,
    required this.onExpandedChanged,
    required this.onAction,
    required this.size,
  });

  final _ActionEntry? source;
  final _ActionEntry? target;
  final double progress;
  final double opacity;
  final double contentOpacity;
  final bool interactive;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<UiSmartActionGroupAction> onAction;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final entry = target ?? source;
    if (entry == null) return const SizedBox.shrink();

    final enabled = interactive && entry.enabled && !entry.loading;
    final onPressed = enabled ? _onPressed(entry) : null;

    return ClipRect(
      child: UiPressable(
        enabled: enabled,
        onPressed: onPressed,
        semanticsLabel: entry.semanticsLabel ?? entry.label,
        excludeFromSemantics: opacity < 0.99,
        minTapSize: 0,
        builder: (context, state, _) {
          final tokens = UiThemeTokens.of(context);
          final style = _MechanicalButtonStyle.resolve(
            tokens,
            source ?? entry,
            target ?? entry,
            progress,
            state,
          );
          final scale = state.pressed ? 0.97 : 1.0;
          return SizedBox.expand(
            child: UiFocusRing(
              visible: state.focused,
              borderRadius: tokens.radius.mdAll,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity * style.opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.background,
                      borderRadius: tokens.radius.mdAll,
                      border: style.border == null
                          ? null
                          : Border.all(color: style.border!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: tokens.radius.mdAll,
                      child: Padding(
                        padding: _buttonPaddingFor(size, tokens),
                        child: _MechanicalButtonContentStack(
                          source: source,
                          target: target,
                          sourceOpacity: source == null
                              ? 0
                              : contentOpacity *
                                  _sourceContentOpacity(source!, target),
                          targetOpacity: target == null
                              ? 0
                              : contentOpacity *
                                  _targetContentOpacity(source, target!),
                          style: style,
                          size: size,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  VoidCallback? _onPressed(_ActionEntry entry) {
    if (entry.isToggle) {
      return () => onExpandedChanged(entry.targetExpanded!);
    }
    final action = entry.action;
    if (action == null || action.onPressed == null) return null;
    return () => onAction(action);
  }

  double _sourceContentOpacity(_ActionEntry source, _ActionEntry? target) {
    if (target == null) return 1 - _interval(progress, 0.0, 0.55);
    if (_sameContent(source, target)) return 0;
    return 1 - _interval(progress, 0.08, 0.42);
  }

  double _targetContentOpacity(_ActionEntry? source, _ActionEntry target) {
    if (source == null) return _interval(progress, 0.0, 0.36);
    if (_sameContent(source, target)) return 1;
    return _interval(progress, 0.42, 0.88);
  }

  static bool _sameContent(_ActionEntry a, _ActionEntry b) {
    return a.label == b.label &&
        a.intent == b.intent &&
        (a.leading == null) == (b.leading == null) &&
        (a.trailing == null) == (b.trailing == null) &&
        a.loading == b.loading &&
        a.showBorder == b.showBorder;
  }

  static double _interval(double value, double begin, double end) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return (value - begin) / (end - begin);
  }
}

class _MechanicalButtonContentStack extends StatelessWidget {
  const _MechanicalButtonContentStack({
    required this.source,
    required this.target,
    required this.sourceOpacity,
    required this.targetOpacity,
    required this.style,
    required this.size,
  });

  final _ActionEntry? source;
  final _ActionEntry? target;
  final double sourceOpacity;
  final double targetOpacity;
  final _MechanicalButtonStyle style;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final visibleSource = source != null && sourceOpacity > 0.001;
    final visibleTarget = target != null && targetOpacity > 0.001;

    if (visibleTarget && !visibleSource) {
      return _MechanicalButtonContent(
        entry: target!,
        foreground: style.foreground,
        size: size,
      );
    }
    if (visibleSource && !visibleTarget) {
      return _MechanicalButtonContent(
        entry: source!,
        foreground: style.sourceForeground,
        size: size,
      );
    }
    if (!visibleSource && !visibleTarget) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: sourceOpacity.clamp(0.0, 1.0),
          child: _MechanicalButtonContent(
            entry: source!,
            foreground: style.sourceForeground,
            size: size,
          ),
        ),
        Opacity(
          opacity: targetOpacity.clamp(0.0, 1.0),
          child: _MechanicalButtonContent(
            entry: target!,
            foreground: style.foreground,
            size: size,
          ),
        ),
      ],
    );
  }
}

class _MechanicalButtonContent extends StatelessWidget {
  const _MechanicalButtonContent({
    required this.entry,
    required this.foreground,
    required this.size,
  });

  final _ActionEntry entry;
  final Color foreground;
  final UiSize size;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final iconSize = UiButtonMetrics.iconSize(size);
    final iconExtent = math.max(iconSize, 16.0);
    if (entry.loading) {
      return Center(child: SizedBox(width: iconExtent, height: iconExtent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gapSize = UiButtonMetrics.gap(size, tokens.spacing);
        final hasLeading = entry.leading != null;
        final hasTrailing = entry.trailing != null;
        final iconReserve =
            (hasLeading ? iconExtent : 0) + (hasTrailing ? iconExtent : 0);
        final gapReserve =
            (hasLeading ? gapSize : 0) + (hasTrailing ? gapSize : 0);
        final canShowLabel =
            constraints.maxWidth > iconReserve + gapReserve + 16;
        final canShowLeading =
            !hasLeading || constraints.maxWidth >= iconExtent;
        final canShowTrailing =
            !hasTrailing || constraints.maxWidth >= iconReserve + gapReserve;
        final labelMaxWidth = math.max(
          0.0,
          constraints.maxWidth -
              (canShowLeading && hasLeading ? iconExtent + gapSize : 0) -
              (canShowTrailing && hasTrailing ? iconExtent + gapSize : 0),
        );

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasLeading && canShowLeading) ...[
                IconTheme.merge(
                  data: IconThemeData(color: foreground, size: iconSize),
                  child: SizedBox(
                    width: iconExtent,
                    height: iconExtent,
                    child: Center(child: entry.leading!),
                  ),
                ),
                if (canShowLabel) SizedBox(width: gapSize),
              ],
              if (canShowLabel)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelMaxWidth),
                  child: UiText(
                    entry.label,
                    variant: UiButtonMetrics.textVariant(size),
                    style: UiButtonMetrics.textStyle(size, tokens).copyWith(
                      color: foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (hasTrailing && canShowTrailing) ...[
                if (canShowLabel) SizedBox(width: gapSize),
                IconTheme.merge(
                  data: IconThemeData(color: foreground, size: iconSize),
                  child: SizedBox(
                    width: iconExtent,
                    height: iconExtent,
                    child: Center(child: entry.trailing!),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MechanicalButtonStyle {
  const _MechanicalButtonStyle({
    required this.background,
    required this.foreground,
    required this.sourceForeground,
    this.border,
    this.opacity = 1,
  });

  final Color background;
  final Color foreground;
  final Color sourceForeground;
  final Color? border;
  final double opacity;

  static _MechanicalButtonStyle resolve(
    UiThemeTokens tokens,
    _ActionEntry source,
    _ActionEntry target,
    double progress,
    UiPressableState state,
  ) {
    final sourcePalette = _paletteFor(source.intent, tokens);
    final targetPalette = _paletteFor(target.intent, tokens);
    final background = Color.lerp(
      sourcePalette.background,
      targetPalette.background,
      progress,
    )!;
    final foreground = Color.lerp(
        sourcePalette.foreground, targetPalette.foreground, progress)!;
    final border = Color.lerp(
      source.showBorder
          ? sourcePalette.border ?? const Color(0x00000000)
          : const Color(0x00000000),
      target.showBorder
          ? targetPalette.border ?? const Color(0x00000000)
          : const Color(0x00000000),
      progress,
    );
    final enabledOpacity = target.enabled && !target.loading ? 1.0 : 0.5;

    return _MechanicalButtonStyle(
      background: background,
      foreground: foreground,
      sourceForeground: sourcePalette.foreground,
      border: border == null || border.a <= 0.01 ? null : border,
      opacity: state.disabled ? enabledOpacity : 1,
    );
  }

  static UiIntentPalette _paletteFor(UiIntent intent, UiThemeTokens tokens) {
    final resolved =
        intent == UiIntent.defaultIntent ? UiIntent.primary : intent;
    return UiIntentPalette.rest(resolved, tokens.colors);
  }
}

EdgeInsets _buttonPaddingFor(UiSize size, UiThemeTokens tokens) {
  switch (size) {
    case UiSize.sm:
      return EdgeInsets.symmetric(horizontal: tokens.spacing.x3);
    case UiSize.md:
      return EdgeInsets.symmetric(horizontal: tokens.spacing.x4);
    case UiSize.lg:
      return EdgeInsets.symmetric(horizontal: tokens.spacing.x6);
  }
}

double _buttonLayoutHeight(UiSize size) {
  return math.max(44.0, UiButtonMetrics.minHeight(size));
}
