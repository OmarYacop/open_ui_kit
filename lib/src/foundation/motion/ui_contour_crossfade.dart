import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../effects/ui_effects_tokens.dart';
import '../theme/ui_theme_extensions.dart';
import 'ui_motion_spec.dart';

/// A reusable, generic cross-dissolve abstraction: when [update] receives a
/// value whose [identity] differs from the current one, the old value fades
/// out while the new value fades in over one shared progress timeline — both
/// visible simultaneously mid-transition, neither morphing into the other's
/// geometry or position. See `doc/contour.md`, "Two kinds of value change."
///
/// Use this when consecutive values occupy the same on-screen slot but are
/// structurally unrelated (a different tab's accessory content, a different
/// screen's toolbar actions) — there is nothing to geometrically morph
/// between them, only a soft dissolve. For a slot whose *existence* changes
/// (appears/disappears entirely), use [UiContourPresenceController] instead;
/// the two compose when a persistent shell's existence is owned by
/// [UiContourPresenceController] while its inner content, once visible, is
/// owned by this controller.
///
/// [identity] defaults to `next` itself (via `==`) when omitted, which
/// suits plain value types. Widget-bearing types such as configuration
/// records rarely override `==` in a way that's meaningful here — a fresh
/// instance is typically rebuilt every frame even when nothing logically
/// changed — so callers holding those should pass an explicit, stable
/// identity (e.g. a label or index), the same pattern `AnimatedSwitcher`
/// uses with `child.key`.
class UiContourCrossfadeController<T> extends ChangeNotifier {
  UiContourCrossfadeController({required TickerProvider vsync})
      : _animation = AnimationController(vsync: vsync, value: 1) {
    _animation.addListener(_handleTick);
  }

  final AnimationController _animation;
  T? _previous;
  T? _current;
  Object? _currentIdentity;
  bool _initialized = false;
  bool _disposed = false;
  Curve _curve = Curves.linear;

  /// The value fading out, or `null` once the transition settles.
  T? get previous => _previous;

  /// The value fading in, or already fully visible at rest.
  T? get current => _current;

  /// 0 at the start of a transition (only [previous] visible), 1 at rest
  /// (only [current] visible).
  double get progress =>
      _initialized ? _curve.transform(_animation.value) : 1.0;

  /// Whether a transition is in flight — [previous] is non-null and still
  /// fading out.
  bool get isTransitioning => _previous != null;

  bool get isDisposed => _disposed;

  void _handleTick() {
    // Checked against `value`, not `AnimationController.status`: a
    // zero-duration animateTo (reduced motion) calls notifyListeners()
    // before it updates status to completed, so an `isCompleted` check here
    // would miss that tick and leave `previous` stuck.
    if (_animation.value >= 1.0 && _previous != null) {
      _previous = null;
    }
    notifyListeners();
  }

  /// Sets the target value. Starts a new cross-dissolve from whatever is
  /// currently visible only when [identity] (or `next` itself, if
  /// [identity] is omitted) differs from the current identity —
  /// interrupting an in-flight transition restarts cleanly from the
  /// visually-current blend rather than discarding it.
  void update(
    BuildContext context,
    T? next, {
    Object? identity,
    UiMotionDuration? duration,
  }) {
    _assertNotDisposed();
    final nextIdentity = identity ?? next;
    if (!_initialized) {
      _initialized = true;
      _current = next;
      _currentIdentity = nextIdentity;
      _animation.value = 1;
      return;
    }
    if (nextIdentity == _currentIdentity) {
      // Same logical slot; accept a possibly-rebuilt instance without
      // animating (e.g. an unrelated ancestor rebuild produced a new but
      // logically identical value).
      _current = next;
      return;
    }
    final motion = UiMotionSpec.resolveTiming(
      context,
      duration: duration ?? UiMotionDuration.standard,
    );
    _previous = _current;
    _current = next;
    _currentIdentity = nextIdentity;
    _curve = motion.curve;
    _animation
      ..stop()
      ..value = 0;
    _animation.animateTo(1, duration: motion.duration, curve: Curves.linear);
  }

  void _assertNotDisposed() {
    assert(
      !_disposed,
      'UiContourCrossfadeController used after dispose(). Each controller '
      'must have exactly one owner responsible for its lifecycle.',
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _animation.removeListener(_handleTick);
    _animation.dispose();
    super.dispose();
  }
}

/// How much blur a Contour cross-dissolve should carry at a given
/// [progress], as a 0..1 fraction of a caller-chosen peak sigma. Peaks at
/// the midpoint and resolves to zero at both rest ends — a brief, soft
/// blur while content is mid-swap, not a blur held throughout the
/// transition. This is what reads as "glass" in Apple's own system content
/// transitions (SF Symbols content-transition, tab bar item swaps) rather
/// than a flat cross dissolve.
///
/// Pure function of [progress] — no widgets, no platform or effects-tier
/// checks. [buildUiContourCrossfade] is the usual entry point; call this
/// directly only when composing a custom visual treatment.
double uiContourCrossfadeBlurFraction(double progress) {
  return math.sin(math.pi * progress.clamp(0.0, 1.0));
}

/// Whether the current platform is one where Open UI's glass-like
/// treatments (this transient cross-dissolve blur, backdrop materials
/// elsewhere in the kit) read as native rather than decorative. Android and
/// desktop-non-Apple platforms have their own, flatter system idiom for a
/// content swap; only iOS and macOS carry the "glass" association this
/// blur is standing in for.
bool uiContourPrefersGlassTreatment() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return false;
  }
}

/// Builds the visual for a [UiContourCrossfadeController]-driven
/// transition: [previous] and [current] cross-dissolve via opacity, with a
/// transient backdrop blur layered on top on platforms where that reads as
/// native (see [uiContourPrefersGlassTreatment]) — bounded and tier-aware
/// via [UiEffectsTokens.scaleBlur], so it already collapses to zero under
/// reduced motion / reduced effects. Pass either endpoint as `null` to
/// render only the other one, unblurred (nothing to dissolve between).
///
/// [peakBlurSigma] is the blur strength at the transition's midpoint
/// (`progress == 0.5`); it fades to zero at both rest ends regardless of
/// platform or effects tier.
Widget buildUiContourCrossfade(
  BuildContext context, {
  required double progress,
  Widget? previous,
  Widget? current,
  double peakBlurSigma = 8,
}) {
  if (previous == null) return current ?? const SizedBox.shrink();
  if (current == null) return previous;

  final stack = Stack(
    alignment: Alignment.center,
    children: [
      Opacity(opacity: 1 - progress, child: previous),
      Opacity(opacity: progress, child: current),
    ],
  );

  if (!uiContourPrefersGlassTreatment()) return stack;

  final tokens = UiThemeTokens.effectsOf(context);
  final sigma = tokens.scaleBlur(peakBlurSigma) *
      uiContourCrossfadeBlurFraction(progress);
  if (sigma <= 0) return stack;

  return ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    child: stack,
  );
}
