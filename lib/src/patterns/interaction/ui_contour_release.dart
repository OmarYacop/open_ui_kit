import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../components/forms/button.dart';
import '../../components/forms/icon_button.dart';
import '../../foundation/motion/motion.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import 'ui_contour_action_geometry.dart';

/// One action released by a [UiContourRelease] trigger.
///
/// A `null` [onPressed] renders a genuinely disabled control — correct
/// appearance, pointer behavior, focus behavior, and semantics all come
/// from [UiIconButton]'s own disabled contract. [UiContourRelease] never
/// substitutes a non-null closure for a null callback.
@immutable
class UiContourReleaseAction {
  const UiContourReleaseAction({
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final Widget icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
}

/// A trigger that releases a row of actions in place.
///
/// Spatial continuity comes from geometry alone: one persistent trigger
/// surface stays mounted for the widget's entire lifetime (a single
/// [UiButton] call site — not a crossfaded pair), and each action travels,
/// position and width together, from a zero-width point co-located with
/// the trigger's trailing edge out to its final laid-out rectangle. A
/// hairline border wraps the whole component and grows with it, so the
/// component itself — not its parent — visibly reads as the transforming
/// surface. There is no shader, no glow, and no material blend; see
/// `doc/contour.md` for why that path was retired.
///
/// The trigger's own content hands off at the same activation threshold
/// actions become interactive at: its icon swaps from [collapsedIcon] to a
/// collapse affordance, and its label swaps from [label] to [expandedLabel]
/// — a single deterministic cutover derived from the shared progress value,
/// never a second visible label and never a separate implicit animation.
///
/// This widget needs a parent that permits it to grow past its collapsed
/// width (e.g. a `Row` with `mainAxisSize: MainAxisSize.min`, or an
/// unconstrained/scrollable toolbar) — a parent that clamps it to exactly
/// its collapsed width will visibly clip the released actions.
///
/// Supports 1 to [maxInlineActions] actions. Route additional commands
/// through a menu or sheet instead of growing this list further.
class UiContourRelease extends StatefulWidget {
  UiContourRelease({
    super.key,
    required this.label,
    required this.actions,
    this.intent = UiIntent.defaultIntent,
    this.size = UiSize.md,
    this.collapseOnAction = false,
    this.expandedLabel,
    this.collapsedIcon = const Icon(LucideIcons.ellipsis),
    this.expandedIcon = const Icon(LucideIcons.x),
    this.collapsedSemanticsLabel,
    this.expandedSemanticsLabel,
    this.expanded,
    this.onExpandedChanged,
  }) : assert(
          actions.isNotEmpty && actions.length <= maxInlineActions,
          'UiContourRelease supports 1 to $maxInlineActions inline released '
          'actions; route additional commands through a menu or sheet '
          'instead of growing this list.',
        );

  /// Maximum number of actions this widget lays out inline. This is a
  /// deliberate compact-layout policy, not an arbitrary limit — an
  /// unbounded horizontal action list has no responsive story on narrow
  /// widths. Callers with more commands should offer a menu or sheet.
  static const maxInlineActions = 4;

  /// Label shown on the trigger while collapsed.
  final String label;

  /// Label shown on the trigger once expanded. Defaults to `'Done'` — kept
  /// intentionally close in length to [label] so the trigger's own
  /// footprint doesn't visibly jump at the handoff instant.
  final String? expandedLabel;

  /// Icon shown on the trigger while collapsed.
  final Widget collapsedIcon;

  /// Icon shown on the trigger once expanded — a clear collapse affordance.
  final Widget expandedIcon;

  /// Actions released alongside the trigger when expanded.
  final List<UiContourReleaseAction> actions;

  final UiIntent intent;
  final UiSize size;

  /// Collapse back to the trigger immediately after an action fires.
  final bool collapseOnAction;

  /// Semantics label while collapsed. Defaults to [label].
  final String? collapsedSemanticsLabel;

  /// Semantics label while expanded. Defaults to `'Collapse actions'`.
  final String? expandedSemanticsLabel;

  /// Pass to drive expansion externally (controlled mode). Omit for the
  /// widget to own its own expanded/collapsed state.
  final bool? expanded;

  /// Called when the trigger requests a state change, in both controlled and
  /// uncontrolled mode.
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<UiContourRelease> createState() => _UiContourReleaseState();
}

class _UiContourReleaseState extends State<UiContourRelease>
    with SingleTickerProviderStateMixin {
  // Actions become eligible for pointer input and semantics only once their
  // rect has emerged to at least this fraction of its natural width — kept
  // in sync with UiContourActionGeometryInput.activationThreshold's default
  // so the widget's interaction gating agrees with what is actually
  // painted.
  static const _activationThreshold = 0.92;

  late final UiContourController _controller = UiContourController(
    vsync: this,
  );
  bool _uncontrolledExpanded = false;
  bool _initialized = false;

  bool get _isExpanded => widget.expanded ?? _uncontrolledExpanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (_isExpanded) {
        _controller.open(context, duration: UiMotionDuration.instant);
      }
    }
  }

  @override
  void didUpdateWidget(covariant UiContourRelease oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      _syncTo(widget.expanded!);
    }
  }

  void _syncTo(bool expand) {
    if (expand) {
      _controller.open(context);
    } else {
      _controller.close(context);
    }
  }

  void _requestExpand(bool expand) {
    if (widget.expanded == null) {
      setState(() => _uncontrolledExpanded = expand);
    }
    widget.onExpandedChanged?.call(expand);
    _syncTo(expand);
  }

  void _handleAction(UiContourReleaseAction action) {
    action.onPressed?.call();
    if (widget.collapseOnAction) _requestExpand(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final expanded = progress >= _activationThreshold;

        // A single deterministic cutover — never a second, independently
        // animated crossfade — so the trigger's own content hands off in
        // lockstep with the same progress value that drives every action's
        // geometry. Reversal crosses the exact same threshold, so it is
        // continuous by construction.
        final trigger = Semantics(
          label: expanded
              ? (widget.expandedSemanticsLabel ?? 'Collapse actions')
              : (widget.collapsedSemanticsLabel ?? widget.label),
          container: true,
          excludeSemantics: true,
          child: UiButton(
            key: const ValueKey('contour-release-trigger'),
            label: expanded ? (widget.expandedLabel ?? 'Done') : widget.label,
            leading: expanded ? widget.expandedIcon : widget.collapsedIcon,
            intent: widget.intent,
            size: widget.size,
            onPressed: () => _requestExpand(!_isExpanded),
          ),
        );

        final actionWidgets = [
          for (final action in widget.actions)
            ExcludeSemantics(
              excluding: !expanded,
              child: IgnorePointer(
                ignoring: !expanded,
                child: UiIconButton(
                  icon: action.icon,
                  semanticsLabel: action.semanticsLabel,
                  size: widget.size,
                  onPressed: action.onPressed == null
                      ? null
                      : () => _handleAction(action),
                ),
              ),
            ),
        ];

        // A hairline border wrapping the whole component and growing with
        // it — so this surface, not an ancestor card or toolbar, is what
        // visibly reads as the transforming object. No fill (buttons keep
        // their own), so this never doubles up as a card-in-card.
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.colors.border),
            borderRadius: tokens.radius.mdAll,
          ),
          child: _ContourActionReleaseLayout(
            progress: progress,
            spacing: UiThemeTokens.spacingOf(context).x2,
            activationThreshold: _activationThreshold,
            trigger: trigger,
            actions: actionWidgets,
          ),
        );
      },
    );
  }
}

/// Lays out one persistent trigger and N released actions per
/// [UiContourActionGeometrySolver], and paints/hit-tests each action
/// clipped to its solved rect.
///
/// This is a pure geometry/paint layer: it does not own progress and does
/// not decide which actions are interactive — [_UiContourReleaseState]
/// gates that with `IgnorePointer`/`ExcludeSemantics` on the child widgets
/// before they reach here, since eligibility depends only on `progress`,
/// not on anything this render object measures. It applies no material
/// treatment of its own. The first child is always the trigger; every
/// subsequent child is one action, in order.
class _ContourActionReleaseLayout extends MultiChildRenderObjectWidget {
  _ContourActionReleaseLayout({
    required this.progress,
    required this.spacing,
    required this.activationThreshold,
    required Widget trigger,
    required List<Widget> actions,
  }) : super(children: [trigger, ...actions]);

  final double progress;
  final double spacing;
  final double activationThreshold;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderContourActionRelease(
      progress: progress,
      spacing: spacing,
      activationThreshold: activationThreshold,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderContourActionRelease renderObject,
  ) {
    renderObject
      ..progress = progress
      ..spacing = spacing
      ..activationThreshold = activationThreshold
      ..textDirection = Directionality.of(context);
  }
}

class _ContourActionParentData extends ContainerBoxParentData<RenderBox> {
  /// The solved (possibly narrower) rect this child is clipped and
  /// hit-tested against. `null` for the trigger, which is never clipped.
  Rect? clipRect;

  /// Legibility-assist opacity from the same solver pass that produced
  /// [clipRect] — position and clipping remain the primary spatial signal;
  /// this only smooths the reveal. Always 1 for the trigger.
  double visibility = 1;
}

class _RenderContourActionRelease extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ContourActionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ContourActionParentData> {
  _RenderContourActionRelease({
    required double progress,
    required double spacing,
    required double activationThreshold,
    required TextDirection textDirection,
  })  : _progress = progress,
        _spacing = spacing,
        _activationThreshold = activationThreshold,
        _textDirection = textDirection;

  double _progress;
  double _spacing;
  double _activationThreshold;
  TextDirection _textDirection;

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsLayout();
  }

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  set activationThreshold(double value) {
    if (_activationThreshold == value) return;
    _activationThreshold = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ContourActionParentData) {
      child.parentData = _ContourActionParentData();
    }
  }

  @override
  void performLayout() {
    final trigger = firstChild;
    if (trigger == null) {
      size = constraints.smallest;
      return;
    }

    final looseConstraints = constraints.loosen();
    trigger.layout(looseConstraints, parentUsesSize: true);

    final actionSizes = <Size>[];
    var child = childAfter(trigger);
    while (child != null) {
      child.layout(looseConstraints, parentUsesSize: true);
      actionSizes.add(child.size);
      child = childAfter(child);
    }

    final geometry = UiContourActionGeometrySolver.solve(
      UiContourActionGeometryInput(
        triggerSize: trigger.size,
        actionSizes: actionSizes,
        spacing: _spacing,
        progress: _progress,
        activationThreshold: _activationThreshold,
      ),
    );

    size = constraints.constrain(geometry.outerSize);

    final totalWidth = geometry.outerSize.width;
    Rect mirror(Rect r) => _textDirection == TextDirection.rtl
        ? Rect.fromLTWH(totalWidth - r.right, r.top, r.width, r.height)
        : r;

    final triggerData = trigger.parentData! as _ContourActionParentData;
    final triggerRect = mirror(geometry.triggerRect);
    triggerData
      ..offset = triggerRect.topLeft
      ..clipRect = null;

    child = childAfter(trigger);
    var index = 0;
    while (child != null) {
      final data = child.parentData! as _ContourActionParentData;
      final rect = mirror(geometry.actionRects[index]);
      // Natural content stays centered within the (possibly narrower) clip
      // window, so the reveal grows symmetrically outward from the glyph
      // rather than hard-slicing from one edge.
      final natural = child.size;
      data
        ..offset = Offset(
          rect.center.dx - natural.width / 2,
          rect.center.dy - natural.height / 2,
        )
        ..clipRect = rect
        ..visibility = geometry.actionVisibility[index];
      child = childAfter(child);
      index++;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final trigger = firstChild;
    if (trigger == null) return;
    final triggerData = trigger.parentData! as _ContourActionParentData;
    context.paintChild(trigger, offset + triggerData.offset);

    var child = childAfter(trigger);
    while (child != null) {
      final data = child.parentData! as _ContourActionParentData;
      final clipRect = data.clipRect!;
      if (!clipRect.isEmpty && data.visibility > 0) {
        final capturedChild = child;
        // clipRect is passed local (NOT pre-shifted by offset) — pushClipRect
        // shifts internally. Shifting it here too was the double-offset bug
        // that clipped released actions at the wrong screen position
        // whenever this component sat away from the global origin.
        context.pushClipRect(
          needsCompositing,
          offset,
          clipRect,
          (context, clippedOffset) {
            context.pushOpacity(
              clippedOffset + data.offset,
              (data.visibility.clamp(0.0, 1.0) * 255).round(),
              (context, paintOffset) {
                context.paintChild(capturedChild, paintOffset);
              },
            );
          },
        );
      }
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Reverse paint order so a later (rightmost, most-recently-revealed)
    // action wins on overlap during the brief window before rects settle.
    final children = <RenderBox>[];
    RenderBox? child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }

    for (final candidate in children.reversed) {
      final data = candidate.parentData! as _ContourActionParentData;
      final clipRect = data.clipRect;
      if (clipRect != null && !clipRect.contains(position)) continue;
      final isHit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            candidate.hitTest(result, position: transformed),
      );
      if (isHit) return true;
    }
    return false;
  }
}
