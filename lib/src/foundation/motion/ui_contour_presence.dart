import 'package:flutter/widgets.dart';

import 'ui_contour_controller.dart';
import 'ui_motion_spec.dart';

/// A generic "optional slot" presence controller: animates a value between
/// absent (`null`) and present (non-`null`) on a single [UiContourController]
/// timeline, **retaining the last non-null value while animating out** so a
/// consumer never loses its content mid-transition.
///
/// This is the abstract layer behind Contour's accessory-presence pattern
/// (see `doc/contour.md`). It formalizes what individual components would
/// otherwise hand-roll — an `AnimationController` plus a manually retained
/// "last visible value" field — as one reusable, already-tested primitive:
/// `UiBottomTabScaffold`'s accessory presence is built on this.
///
/// Usage: create one per owning [State] (`late final` + `vsync: this`), and
/// call [update] with the current target value on every build or
/// `didUpdateWidget`. Read [value] for what to actually render — it is the
/// target while present, and the *previous* target while collapsing away —
/// and [progress]/[phase] for the underlying timeline.
///
/// ```dart
/// late final _presence = UiContourPresenceController<UiBottomTabAccessory>(
///   vsync: this,
/// );
///
/// @override
/// void didUpdateWidget(covariant MyWidget old) {
///   super.didUpdateWidget(old);
///   _presence.update(context, widget.accessory);
/// }
///
/// // in build():
/// final accessory = _presence.value; // renders during both open and close
/// ```
class UiContourPresenceController<T> extends ChangeNotifier {
  UiContourPresenceController({required TickerProvider vsync})
      : controller = UiContourController(vsync: vsync) {
    controller.addListener(_handleControllerChange);
  }

  /// The single owning timeline — one state owner, one progress, per
  /// Contour's architectural rule.
  final UiContourController controller;

  T? _visibleValue;
  T? _target;
  bool _initialized = false;

  /// What to render right now: the current target while present or
  /// animating in, and the *previous* target while animating out. Only
  /// `null` once fully collapsed with no target — never null merely because
  /// the target just became null.
  T? get value => _visibleValue;

  /// The underlying timeline's progress, 0 (absent) to 1 (present).
  double get progress => controller.value;

  UiContourPhase get phase => controller.phase;

  bool get isDisposed => controller.isDisposed;

  /// Call with the current target value on every build/`didUpdateWidget`.
  /// The very first call establishes the initial state without animating —
  /// a component that starts with a non-null value does not fade it in.
  ///
  /// [onRemove], when [next] is `null` and a value is currently retained,
  /// transforms that retained value before it starts fading out — e.g.
  /// collapsing an expanded sub-state (`(v) => v.copyWith(expanded: false)`)
  /// so removal never animates out mid-expansion.
  ///
  /// [duration] overrides the resolved open/close timing (both directions);
  /// omit to use the theme's standard structural-motion duration.
  void update(
    BuildContext context,
    T? next, {
    T Function(T)? onRemove,
    UiMotionDuration? duration,
  }) {
    _target = next;
    if (!_initialized) {
      _initialized = true;
      _visibleValue = next;
      if (next != null) {
        controller.open(context, duration: UiMotionDuration.instant);
      }
      return;
    }
    if (next != null) {
      _visibleValue = next;
      if (controller.phase != UiContourPhase.expanded &&
          controller.phase != UiContourPhase.opening) {
        controller.open(context, duration: duration);
      }
      return;
    }
    if (_visibleValue != null &&
        controller.phase != UiContourPhase.collapsed &&
        controller.phase != UiContourPhase.closing) {
      if (onRemove != null) _visibleValue = onRemove(_visibleValue as T);
      controller.close(context, duration: duration);
    }
  }

  void _handleControllerChange() {
    if (controller.phase == UiContourPhase.collapsed &&
        _target == null &&
        _visibleValue != null) {
      _visibleValue = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChange);
    controller.dispose();
    super.dispose();
  }
}
