import 'package:flutter/widgets.dart';

import 'ui_contour_physics.dart';
import 'ui_motion_spec.dart';

/// The legal states of a Contour transition.
///
/// Exactly one [UiContourController] is the authoritative owner of both the
/// current [UiContourPhase] and the progress timeline that drives it. No
/// other controller, implicit animation, or physics simulation should
/// independently infer this state — see `doc/contour.md`.
enum UiContourPhase {
  /// Fully collapsed into the source. Resting state.
  collapsed,

  /// Animating from collapsed toward expanded.
  opening,

  /// Fully expanded. Resting state.
  expanded,

  /// Animating from expanded toward collapsed.
  closing,

  /// Reversing direction mid-flight (e.g. closing while still opening).
  reversing,

  /// A transition was interrupted by a new request before it settled.
  interrupted,

  /// The trigger/source this transition depends on is no longer available.
  sourceUnavailable,

  /// The destination this transition would resolve to is unavailable.
  destinationUnavailable,

  /// The transition has reached and stayed at a resting endpoint for at
  /// least one frame; safe to drop expensive rendering resources.
  settled,

  /// The controller has been disposed and must not be used further.
  disposed,
}

/// The single authoritative state and progress owner for a Contour
/// transition.
///
/// [UiContourController] wraps exactly one [AnimationController]. Every
/// widget participating in the transition (morph geometry, content handoff,
/// emergence stagger, material treatment) reads the same [value] and
/// [phase] — nothing else independently animates or infers this state.
///
/// Reversal never resets progress: calling [close] while [opening] reverses
/// from the current value, and calling [open] while [closing] does the
/// same. Rapid re-triggering is safe by construction because there is only
/// ever one controller to reason about.
class UiContourController extends ChangeNotifier {
  UiContourController({
    required TickerProvider vsync,
    this.physics = UiContourPhysics.control,
  }) : _animation = AnimationController(vsync: vsync, value: 0) {
    _animation.addListener(_handleTick);
    _animation.addStatusListener(_handleStatus);
  }

  final AnimationController _animation;

  /// The physics family available to this transition for *optional,
  /// decorative* deformation — not for the geometry timeline itself, which
  /// always uses a plain restrained curve resolved from `UiMotionSpec` (see
  /// [UiContourPhysics]'s class doc for why the two are kept separate).
  ///
  /// Re-resolve this via [UiContourPhysics.resolve] whenever accessibility
  /// preferences may have changed (e.g. in `didChangeDependencies`) — the
  /// controller itself is created once and kept for the owning widget's
  /// lifetime, so physics is mutable rather than fixed at construction.
  UiContourPhysics physics;

  UiContourPhase _phase = UiContourPhase.collapsed;
  bool _disposed = false;

  /// Current transition progress, 0 (collapsed) to 1 (expanded). Monotonic
  /// under the default curve — geometry consumers do not need to clamp this
  /// for layout, though defensive clamping remains harmless.
  double get value => _animation.value;

  UiContourPhase get phase => _phase;

  bool get isDisposed => _disposed;

  void _setPhase(UiContourPhase next) {
    if (_phase == next) return;
    _phase = next;
    notifyListeners();
  }

  void _handleTick() {
    if (_phase != UiContourPhase.sourceUnavailable &&
        _phase != UiContourPhase.destinationUnavailable) {
      notifyListeners();
    }
  }

  void _handleStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.completed:
        _setPhase(UiContourPhase.expanded);
      case AnimationStatus.dismissed:
        _setPhase(UiContourPhase.collapsed);
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
    }
  }

  /// Opens (expands) the transition. If already [closing] or [reversing],
  /// this reverses direction from the current value rather than restarting.
  TickerFuture open(BuildContext context, {UiMotionDuration? duration}) {
    _assertNotDisposed();
    final wasCollapsing = _phase == UiContourPhase.closing;
    final motion = UiMotionSpec.resolveTiming(
      context,
      duration: duration ?? UiMotionDuration.standard,
    );
    motion.configure(_animation);
    _setPhase(
        wasCollapsing ? UiContourPhase.reversing : UiContourPhase.opening);
    return _animation.animateTo(1, curve: motion.curve);
  }

  /// Closes (collapses) the transition. If already [opening] or
  /// [reversing], this reverses direction from the current value rather
  /// than restarting.
  TickerFuture close(BuildContext context, {UiMotionDuration? duration}) {
    _assertNotDisposed();
    final wasOpening = _phase == UiContourPhase.opening;
    final motion = UiMotionSpec.resolveTiming(
      context,
      duration: duration ?? UiMotionDuration.standard,
    );
    motion.configure(_animation);
    _setPhase(wasOpening ? UiContourPhase.reversing : UiContourPhase.closing);
    return _animation.animateBack(0, curve: motion.reverseCurve);
  }

  /// Immediately jumps to the collapsed state without animating, and marks
  /// the transition's source as unavailable. Use when the trigger moves out
  /// of the tree, is unmounted, or scrolls fully offstage mid-transition —
  /// the geometry system must never interpolate toward stale source
  /// geometry.
  void markSourceUnavailable() {
    _assertNotDisposed();
    _animation.stop();
    _animation.value = 0;
    _setPhase(UiContourPhase.sourceUnavailable);
  }

  /// Marks the destination as unavailable (e.g. a deep-linked navigation
  /// target that never resolves). Callers should degrade to a
  /// destination-only entrance rather than fabricate source geometry.
  void markDestinationUnavailable() {
    _assertNotDisposed();
    _setPhase(UiContourPhase.destinationUnavailable);
  }

  /// Whether the current value is resting at a settled endpoint (fully
  /// [UiContourPhase.collapsed] or [UiContourPhase.expanded]). Widgets
  /// should use this to decide when it's safe to drop transition-only
  /// rendering work (clip layers, extra widgets) rather than inferring it
  /// from `value` alone.
  bool get isSettled {
    if (_phase == UiContourPhase.collapsed && _animation.value == 0) {
      return true;
    }
    if (_phase == UiContourPhase.expanded && _animation.value == 1) {
      return true;
    }
    return false;
  }

  void _assertNotDisposed() {
    assert(
      !_disposed,
      'UiContourController used after dispose(). Each controller must have '
      'exactly one owner responsible for its lifecycle.',
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _phase = UiContourPhase.disposed;
    _animation.removeListener(_handleTick);
    _animation.removeStatusListener(_handleStatus);
    _animation.dispose();
    super.dispose();
  }
}
