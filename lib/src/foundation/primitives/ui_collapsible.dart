import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';
import 'ui_pressable.dart';

/// Imperative controller for [UiCollapsible].
///
/// Emits notifications on expand/collapse so callers can observe or
/// drive state from outside the widget tree. Lifecycle: owners either
/// pass a controller they dispose themselves, or let [UiCollapsible]
/// create + dispose an internal one when the controller arg is null.
class UiCollapsibleController extends ChangeNotifier {
  UiCollapsibleController({bool initiallyExpanded = false})
      : _expanded = initiallyExpanded;

  bool _expanded;

  bool get isExpanded => _expanded;

  set isExpanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    notifyListeners();
  }

  void expand() => isExpanded = true;
  void collapse() => isExpanded = false;
  void toggle() => isExpanded = !_expanded;
}

/// A reusable collapsible region.
///
/// Drives expand/collapse with a clipped [Align] + animation factor,
/// which is robust to intrinsic-sizing limits that trip up
/// [AnimatedSize] inside scrollables. The widget supports three
/// control models — use whichever fits your caller:
///
/// | Mode | How to use |
/// |---|---|
/// | Uncontrolled | Omit [expanded] + [controller]. Seed with [initiallyExpanded]. Header tap toggles internal state. |
/// | Controlled | Pass [expanded] + [onExpandedChanged]. Header tap fires the callback; state does NOT change until the parent rebuilds with the new value. |
/// | Controller-driven | Pass a [UiCollapsibleController]. Header tap calls `controller.toggle()`; callers drive state imperatively. |
///
/// [header] is optional — omit it to animate an external trigger's
/// expansion (composing this primitive into menus / details / action
/// accordions). When provided, the header wraps in a [UiPressable] so
/// it picks up keyboard (Enter/Space), focus ring, hover/press state.
///
/// Semantics: when a header is present, the pressable exposes an
/// `expanded` flag matching the current state so screen readers
/// announce the collapsed/expanded status.
class UiCollapsible extends StatefulWidget {
  const UiCollapsible({
    super.key,
    this.header,
    required this.child,
    this.expanded,
    this.onExpandedChanged,
    this.controller,
    this.initiallyExpanded = false,
    this.duration,
    this.curve,
    this.semanticsLabel,
    this.maintainState = false,
    this.focusNode,
  }) : assert(
          expanded == null || controller == null,
          'Pass either `expanded` (controlled) or `controller` — not both.',
        );

  /// Optional trigger rendered above [child]. Tapping toggles the
  /// collapsible (in whichever control mode is active).
  final Widget? header;

  /// Collapsible body.
  final Widget child;

  /// Controlled expanded state. When non-null, [UiCollapsible] does
  /// not own state; the parent must update this in response to
  /// [onExpandedChanged].
  final bool? expanded;

  /// Fires when the user taps the header (or activates via keyboard)
  /// in controlled or uncontrolled mode. Pre-wired to the controller
  /// in controller-driven mode — callers can still observe via
  /// `controller.addListener`.
  final ValueChanged<bool>? onExpandedChanged;

  /// Imperative controller. Mutually exclusive with [expanded].
  final UiCollapsibleController? controller;

  /// Initial expanded state for uncontrolled mode. Ignored when
  /// [expanded] or [controller] is provided.
  final bool initiallyExpanded;

  /// Expand/collapse animation duration. Falls back to
  /// `theme.motion.standard` at build time.
  final Duration? duration;

  /// Expand/collapse curve. Falls back to `theme.motion.standardCurve`.
  final Curve? curve;

  /// Label announced for the header's semantics node. Falls back to
  /// the pressable's child semantics.
  final String? semanticsLabel;

  /// If true, [child] is kept alive (built) even while collapsed, so
  /// internal state (form inputs, scroll offsets) survives the
  /// collapse. Default `false` — child is removed from the tree when
  /// fully collapsed.
  final bool maintainState;

  /// Focus node for the header trigger. Forwarded to the internal
  /// [UiPressable]. If omitted, the pressable manages its own node.
  final FocusNode? focusNode;

  @override
  State<UiCollapsible> createState() => _UiCollapsibleState();
}

class _UiCollapsibleState extends State<UiCollapsible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final UiCollapsibleController _controller;
  late final bool _ownsController;

  // Uncontrolled mode only — mirrors _controller.isExpanded.
  bool get _isControlled => widget.expanded != null;

  bool get _currentExpanded {
    if (_isControlled) return widget.expanded!;
    return _controller.isExpanded;
  }

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null && !_isControlled;
    _controller = widget.controller ??
        UiCollapsibleController(
          initiallyExpanded: widget.initiallyExpanded,
        );
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: _currentExpanded ? 1.0 : 0.0,
    );
    if (!_isControlled) {
      _controller.addListener(_handleControllerChange);
    }
  }

  @override
  void didUpdateWidget(covariant UiCollapsible old) {
    super.didUpdateWidget(old);
    if (_isControlled && widget.expanded != old.expanded) {
      _animateTo(widget.expanded!);
    }
  }

  @override
  void dispose() {
    if (!_isControlled) {
      _controller.removeListener(_handleControllerChange);
    }
    _anim.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) return;
    setState(() {
      // Semantics (expanded flag) reads _currentExpanded synchronously
      // — rebuild so it tracks the controller even while the body
      // animation is still easing.
    });
    _animateTo(_controller.isExpanded);
  }

  void _animateTo(bool expanded) {
    final tokens = UiThemeTokens.of(context);
    _anim.animateTo(
      expanded ? 1.0 : 0.0,
      duration: widget.duration ?? tokens.motion.standard,
      curve: widget.curve ?? tokens.motion.standardCurve,
    );
  }

  void _handleHeaderTap() {
    if (_isControlled) {
      widget.onExpandedChanged?.call(!widget.expanded!);
      return;
    }
    _controller.toggle();
    widget.onExpandedChanged?.call(_controller.isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final headerWidget = widget.header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headerWidget != null)
          // UiPressable already wires keyboard activation (Enter/Space),
          // focus ring, hover/press state, and a button-shaped
          // Semantics node. We wrap its child in an outer Semantics
          // that adds the `expanded` flag + label on top of what
          // UiPressable already provides.
          Semantics(
            container: true,
            button: true,
            label: widget.semanticsLabel,
            expanded: _currentExpanded,
            onTap: _handleHeaderTap,
            child: UiPressable(
              onPressed: _handleHeaderTap,
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              minTapSize: 0,
              focusNode: widget.focusNode,
              builder: (context, state, _) => headerWidget,
            ),
          ),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            // When fully collapsed and state is not maintained, drop
            // the child from the tree so offstage inputs don't burn
            // frames.
            if (!widget.maintainState && _anim.value == 0.0) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _anim.value.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: _anim.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ],
    );
  }
}
