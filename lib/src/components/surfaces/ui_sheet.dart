import 'package:flutter/widgets.dart';

import '../../foundation/intl/intl.dart';
import '../../foundation/layout/ui_form_factor.dart';
import '../../foundation/motion/ui_motion_transitions.dart';
import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// How a sheet sizes itself along the vertical axis.
enum UiSheetSnapKind { fit, fraction }

/// Snap-point model for [UiSheet] presentation.
@immutable
class UiSheetSnap {
  const UiSheetSnap.fit()
      : fraction = null,
        kind = UiSheetSnapKind.fit;
  const UiSheetSnap.fraction(double value)
      : fraction = value,
        kind = UiSheetSnapKind.fraction;
  const UiSheetSnap.half()
      : fraction = 0.5,
        kind = UiSheetSnapKind.fraction;
  const UiSheetSnap.full()
      : fraction = 1.0,
        kind = UiSheetSnapKind.fraction;

  final double? fraction;
  final UiSheetSnapKind kind;

  bool get isFit => kind == UiSheetSnapKind.fit;
}

/// Controls an open sheet. Exposed via [UiSheetScope.show] so callers
/// can dismiss the sheet from inside the sheet body.
class UiSheetController<T> {
  UiSheetController._(this._dismiss);

  final void Function([T? result]) _dismiss;

  /// Dismiss the sheet, optionally completing the presentation future
  /// with [result].
  void dismiss([T? result]) => _dismiss(result);
}

/// Canonical sheet surface — use directly inside [UiSheetScope.show] or
/// drop into a route body for non-modal presentations.
///
/// Structure slots: [header] / [child] / [footer]. All three are
/// optional so the sheet can be anything from a plain content card to a
/// full form with an action row pinned to the bottom.
class UiSheet extends StatelessWidget {
  const UiSheet({
    super.key,
    this.header,
    this.footer,
    this.child,
    this.padding,
    this.showHandle = true,
  });

  final Widget? header;
  final Widget? footer;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final bodyPadding = padding ?? EdgeInsets.all(tokens.spacing.x6);

    return UiBox(
      background: c.card,
      borderRadius: BorderRadius.only(
        topLeft: tokens.radius.xl,
        topRight: tokens.radius.xl,
      ),
      boxShadow: tokens.shadows.lg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle) const UiSheetHandle(),
          if (header != null) header!,
          Flexible(child: Padding(padding: bodyPadding, child: child)),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// Default drag-handle affordance rendered at the top of [UiSheet]s.
class UiSheetHandle extends StatelessWidget {
  const UiSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.x2),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: tokens.colors.borderStrong,
            borderRadius: tokens.radius.pillAll,
          ),
        ),
      ),
    );
  }
}

/// Pre-composed header with optional title/subtitle and trailing slot.
class UiSheetHeader extends StatelessWidget {
  const UiSheetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.x6,
        vertical: tokens.spacing.x2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  UiText(title!, variant: UiTextVariant.heading),
                if (subtitle != null) ...[
                  SizedBox(height: tokens.spacing.x1),
                  UiText(
                    subtitle!,
                    variant: UiTextVariant.bodySm,
                    tone: UiTextTone.muted,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Semantic wrapper used when sheet body is split across helpers.
class UiSheetBody extends StatelessWidget {
  const UiSheetBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Action row pinned to the bottom of the sheet.
class UiSheetFooter extends StatelessWidget {
  const UiSheetFooter({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  final List<Widget> children;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.x6,
        right: tokens.spacing.x6,
        top: tokens.spacing.x2,
        bottom: tokens.spacing.x6,
      ),
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: tokens.spacing.x2),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Imperative helpers for presenting a [UiSheet] as a modal overlay.
class UiSheetScope {
  UiSheetScope._();

  /// Form-factor-aware max-width recommendation for modal sheets.
  ///
  /// A full-width bottom sheet reads as a card on phone but as a
  /// canvas-filling slab on tablet/desktop. Call this to pick a
  /// sensible cap for the current viewport:
  ///
  /// ```dart
  /// UiSheetScope.show<void>(
  ///   context,
  ///   maxWidth: UiSheetScope.adaptiveMaxWidth(context),
  ///   builder: (_, controller) => UiSheet(...),
  /// );
  /// ```
  ///
  /// Returns `null` on phone (full width), `560` on tablet, `720` on
  /// desktop. Override per call site with a custom `maxWidth` when
  /// a different ceiling fits better.
  static double? adaptiveMaxWidth(
    BuildContext context, {
    UiBreakpoints breakpoints = UiBreakpoints.standard,
  }) {
    switch (uiFormFactorOf(context, breakpoints: breakpoints)) {
      case UiFormFactor.phone:
        return null;
      case UiFormFactor.tablet:
        return 560;
      case UiFormFactor.desktop:
        return 720;
    }
  }

  /// Present a modal sheet. [builder] receives a [UiSheetController] so
  /// it can dismiss itself with a typed result.
  ///
  /// When [maxWidth] is non-null, the sheet is centered horizontally
  /// and clamped to that width — useful on tablet/desktop where a
  /// full-width bottom sheet reads as a slab. Leave null (default)
  /// for the legacy phone-style edge-to-edge layout. Pair with
  /// [adaptiveMaxWidth] for a single-line form-factor-aware call site.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext, UiSheetController<T>) builder,
    bool barrierDismissible = true,
    bool isDismissible = true,
    UiSheetSnap snap = const UiSheetSnap.fit(),
    double? maxWidth,
  }) {
    final tokens = UiThemeTokens.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    return navigator.push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierDismissible: barrierDismissible,
        barrierColor: tokens.colors.overlay,
        transitionDuration: tokens.motion.standard,
        reverseTransitionDuration: tokens.motion.fast,
        pageBuilder: (ctx, animation, __) {
          late UiSheetController<T> controller;
          controller = UiSheetController<T>._(([r]) {
            Navigator.of(ctx).maybePop(r);
          });
          return capturedThemes.wrap(
            _SheetHost<T>(
              snap: snap,
              isDismissible: isDismissible,
              controller: controller,
              builder: builder,
              maxWidth: maxWidth,
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: tokens.motion.standardCurve,
            reverseCurve: tokens.motion.standardCurve,
          );
          return UiSlideFadeTransition(
            animation: curved,
            beginOffset: const Offset(0, 1),
            fade: false,
            child: child,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Persistent sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Controls a [UiPersistentSheet]. Exposes imperative snap navigation
/// and observes snap changes via [ChangeNotifier].
///
/// Lifecycle: owners either pass a controller they dispose themselves,
/// or omit it and let [UiPersistentSheet] create + dispose an internal
/// one. Mixing the two is not supported.
class UiPersistentSheetController extends ChangeNotifier {
  UiPersistentSheetController({int initialIndex = 0})
      : _snapIndex = initialIndex;

  int _snapIndex;
  int _snapCount = 0;
  bool _disposed = false;

  /// Current snap index. Clamped into `[0, snapCount)` once the sheet
  /// has been attached.
  int get snapIndex => _snapIndex;

  /// Number of snap points configured on the attached [UiPersistentSheet],
  /// or `0` before first attach.
  int get snapCount => _snapCount;

  /// Whether the sheet is currently past its first snap (useful when
  /// the first snap is a zero-height "closed" state).
  bool get isExpanded => _snapIndex > 0;

  /// Snap to [index]. Silently clamps into range if the sheet is
  /// attached; otherwise records the request for when attach happens.
  void snapTo(int index) {
    if (_disposed) return;
    final next = _snapCount == 0 ? index : index.clamp(0, _snapCount - 1);
    if (next == _snapIndex) return;
    _snapIndex = next;
    notifyListeners();
  }

  /// Snap to the last configured point.
  void expand() {
    if (_snapCount == 0) return;
    snapTo(_snapCount - 1);
  }

  /// Snap to the first configured point (typically the closed/peek state).
  void collapse() => snapTo(0);

  // Internal attach point used by [UiPersistentSheet] to publish its
  // snap count and reconcile the initial index.
  void _attach(int count) {
    _snapCount = count;
    final clamped = _snapIndex.clamp(0, count - 1);
    if (clamped != _snapIndex) {
      _snapIndex = clamped;
      // Defer notification until the next frame so attach doesn't
      // fire during a build of the sheet widget.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Test hook: identifies the sized surface that represents the current
/// sheet height. Exposed so integration tests can measure the rendered
/// sheet directly (the surrounding [UiPersistentSheet] fills its parent
/// layout and therefore reports the wrong height).
@visibleForTesting
const ValueKey<String> persistentSheetSurfaceKey =
    ValueKey('ui_persistent_sheet_surface');

/// A non-modal, persistent bottom sheet that keeps the host body
/// visible and interactive — the design used by Apple Maps / Google
/// Maps filter panels and modern search sheets.
///
/// Unlike [UiSheetScope.show] this is *not* a Navigator route. Place
/// the widget inside your page tree (typically as the last child of a
/// [Stack]) and the host content remains tappable everywhere the sheet
/// does not paint.
///
/// ```dart
/// Stack(
///   children: [
///     MapView(),                     // still interactive under the sheet
///     const Align(
///       alignment: Alignment.bottomCenter,
///       child: UiPersistentSheet(
///         snaps: [
///           UiSheetSnap.fraction(0.2),  // peek
///           UiSheetSnap.fraction(0.5),  // half
///           UiSheetSnap.fraction(0.95), // full
///         ],
///         child: UiSheet(child: _Filters()),
///       ),
///     ),
///   ],
/// )
/// ```
///
/// ### Host interaction model
///
/// By design there is **no modal barrier** and **no dim scrim**. The
/// host body behind/around the sheet stays fully interactive. If you
/// need to block host interaction at large snaps (e.g. when the sheet
/// covers most of the screen), wrap the host body in an
/// [AbsorbPointer] or [IgnorePointer] that you toggle via the
/// controller — we deliberately do not impose a barrier policy.
///
/// ### Snap behavior
///
/// [snaps] must be a non-empty list of fraction-based [UiSheetSnap]s
/// (`UiSheetSnap.fit` is rejected because there is no meaningful
/// drag-destination without a target height). The list is consumed in
/// the order given; it does not need to be sorted but is typically
/// ascending. Dragging past the midpoint between two neighbours
/// snaps to the further one, matching the iOS Maps feel.
///
/// ### Dismiss
///
/// Set [allowClose] to let the user swipe below the first snap to
/// dismiss. [onClose] fires when the user completes the swipe. The
/// sheet does not rebuild itself away after dismiss — the host is
/// responsible for removing the widget (usually by setting a
/// visibility flag in state).
class UiPersistentSheet extends StatefulWidget {
  const UiPersistentSheet({
    super.key,
    required this.snaps,
    required this.child,
    this.controller,
    this.enableDrag = true,
    this.allowClose = false,
    this.onClose,
    this.duration,
    this.curve,
  }) : assert(snaps.length > 0, 'snaps must be non-empty');

  /// Snap points as fractions of the available vertical space.
  final List<UiSheetSnap> snaps;

  /// Sheet body. Typically a [UiSheet].
  final Widget child;

  /// External controller. If null, an internal one is created and
  /// disposed with this widget.
  final UiPersistentSheetController? controller;

  /// Enables drag-to-snap. When false the sheet is driven exclusively
  /// through the controller.
  final bool enableDrag;

  /// Allow swipe-to-dismiss below the first snap.
  final bool allowClose;

  /// Fires when a dismiss gesture completes (only when [allowClose]).
  final VoidCallback? onClose;

  /// Animation duration between snaps. Falls back to the theme's
  /// `motion.standard`.
  final Duration? duration;

  /// Animation curve. Falls back to the theme's `motion.standardCurve`.
  final Curve? curve;

  @override
  State<UiPersistentSheet> createState() => _UiPersistentSheetState();
}

class _UiPersistentSheetState extends State<UiPersistentSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final UiPersistentSheetController _controller;
  late final bool _ownsController;

  // Live drag fraction overlay on top of [_anim.value]. While the user
  // is dragging we set this to the unclamped fraction; on release we
  // animate _anim to the chosen snap and clear _dragFraction.
  double? _dragFraction;

  // Scroll-arbitration state (PR-5). When an inner `Scrollable`
  // reports an [OverscrollNotification] the sheet treats the leftover
  // drag pixels as a sheet-drive adjustment, then snaps on
  // `ScrollEndNotification`. This is the "inner list at extent → hand
  // off to sheet" behaviour for map/filter-style UIs.
  bool _scrollDriveActive = false;
  double _scrollAvailableHeight = 1;
  bool _dismissed = false;
  Duration _resolvedDuration = const Duration(milliseconds: 200);
  Curve _resolvedCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? UiPersistentSheetController();
    _controller._attach(widget.snaps.length);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _fractionFor(_controller.snapIndex),
    );
    _controller.addListener(_handleControllerChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveMotion();
  }

  @override
  void didUpdateWidget(covariant UiPersistentSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveMotion();
    if (oldWidget.snaps.length != widget.snaps.length) {
      _controller._attach(widget.snaps.length);
    }
  }

  void _resolveMotion() {
    final motion = UiThemeTokens.of(context).motion;
    _resolvedDuration = widget.duration ?? motion.standard;
    _resolvedCurve = widget.curve ?? motion.standardCurve;
    _anim.duration = _resolvedDuration;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _anim.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  double _fractionFor(int index) {
    final snap = widget.snaps[index.clamp(0, widget.snaps.length - 1)];
    if (snap.isFit) {
      // Fit at a snap point is ambiguous (no target); degrade to full.
      return 1.0;
    }
    return (snap.fraction ?? 1.0).clamp(0.0, 1.0);
  }

  void _handleControllerChange() {
    if (!mounted) return;
    if (_dismissed) {
      setState(() => _dismissed = false);
    }
    final target = _fractionFor(_controller.snapIndex);
    _animateTo(target);
  }

  void _onDragUpdate(DragUpdateDetails details, double available) {
    if (!widget.enableDrag || available <= 0) return;
    if (_dismissed) {
      setState(() => _dismissed = false);
    }
    final current = _dragFraction ?? _anim.value;
    final deltaFraction = -details.delta.dy / available;
    final minSnap = widget.allowClose ? 0.0 : _fractionFor(0);
    setState(() {
      _dragFraction = (current + deltaFraction).clamp(minSnap, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details, double available) {
    if (!widget.enableDrag) return;
    final velocity = details.primaryVelocity ?? 0; // px/s, downward positive
    final current = _dragFraction ?? _anim.value;

    // Nearest-snap with velocity bias.
    final snapFractions = List<double>.generate(
      widget.snaps.length,
      (i) => _fractionFor(i),
    );

    int targetIndex = 0;
    double bestDelta = double.infinity;
    for (var i = 0; i < snapFractions.length; i++) {
      final d = (snapFractions[i] - current).abs();
      if (d < bestDelta) {
        bestDelta = d;
        targetIndex = i;
      }
    }

    // Strong velocity biases one snap further in the direction of the
    // swipe. Threshold matches the feel of the existing modal sheet.
    const velocityThreshold = 600.0;
    if (velocity.abs() > velocityThreshold) {
      if (velocity < 0) {
        targetIndex = (targetIndex + 1).clamp(0, widget.snaps.length - 1);
      } else {
        if (widget.allowClose &&
            targetIndex == 0 &&
            current < _fractionFor(0)) {
          _dismiss();
          return;
        }
        targetIndex = (targetIndex - 1).clamp(0, widget.snaps.length - 1);
      }
    } else if (widget.allowClose &&
        targetIndex == 0 &&
        current < _fractionFor(0) * 0.5) {
      _dismiss();
      return;
    }

    _dragFraction = null;
    _controller.snapTo(targetIndex);
    // _handleControllerChange runs and animates. If the index didn't
    // change (still snap 0 after a small drag), kick the animation
    // back to the current snap's fraction ourselves.
    if (_controller.snapIndex == targetIndex) {
      _animateTo(snapFractions[targetIndex]);
    }
    setState(() {});
  }

  void _dismiss() {
    _dragFraction = null;
    _dismissed = true;
    _animateTo(0);
    setState(() {});
    widget.onClose?.call();
  }

  // ── Inner-scroll arbitration (PR-5) ──────────────────────────────

  bool _onInnerScrollNotification(ScrollNotification n) {
    // Vertical-axis scrollables only. A horizontal list inside a
    // vertical sheet is fine — ignore it.
    final axis = n.metrics.axisDirection;
    if (axis != AxisDirection.up && axis != AxisDirection.down) {
      return false;
    }
    if (!widget.enableDrag) return false;

    if (n is OverscrollNotification) {
      // The inner list tried to scroll beyond its boundary by
      // `n.overscroll` pixels (signed in the scroll-axis direction).
      // For a downward-axis ListView:
      //
      // - overscroll < 0 → user dragged DOWN past the top → sheet
      //   should collapse (drive DECREASES).
      // - overscroll > 0 → user dragged UP past the bottom → sheet
      //   should expand (drive INCREASES) — typically already at max
      //   snap, so clamping absorbs the push.
      //
      // Both mappings use `drive += overscroll / available`:
      //   (-20) / 600 ≈ -0.033  → drive shrinks → collapse ✓
      //   (+20) / 600 ≈ +0.033  → drive grows   → expand  ✓
      if (_scrollAvailableHeight <= 0) return false;
      final delta = n.overscroll / _scrollAvailableHeight;
      final minSnap = widget.allowClose ? 0.0 : _fractionFor(0);
      final newValue = (_anim.value + delta).clamp(minSnap, 1.0);
      if (newValue != _anim.value) {
        _scrollDriveActive = true;
        _anim.value = newValue;
      }
      return false;
    }

    if (n is ScrollEndNotification && _scrollDriveActive) {
      _scrollDriveActive = false;
      _snapFromScrollEnd();
    }
    return false;
  }

  void _snapFromScrollEnd() {
    final snapFractions = List<double>.generate(
      widget.snaps.length,
      _fractionFor,
    );
    int nearest = 0;
    double best = double.infinity;
    for (var i = 0; i < snapFractions.length; i++) {
      final d = (snapFractions[i] - _anim.value).abs();
      if (d < best) {
        best = d;
        nearest = i;
      }
    }
    // If allowClose and the user dragged well below the first snap,
    // treat the release as a dismiss so the PR-5 handoff respects the
    // existing semantics of the direct-drag path.
    if (widget.allowClose &&
        nearest == 0 &&
        _anim.value < _fractionFor(0) * 0.5) {
      _dismiss();
      return;
    }
    _controller.snapTo(nearest);
    // `snapTo` notifies the controller listener which triggers the
    // animation. If the index didn't actually change, kick the
    // animation ourselves so we still settle on the snap fraction.
    if (_controller.snapIndex == nearest) {
      _animateTo(snapFractions[nearest]);
    }
  }

  void _animateTo(double target) {
    final duration = _effectiveDuration;
    if (duration == Duration.zero) {
      _anim.value = target;
      return;
    }
    _anim.animateTo(
      target,
      duration: duration,
      curve: _effectiveCurve,
    );
  }

  Duration get _effectiveDuration => _resolvedDuration;

  Curve get _effectiveCurve => _resolvedCurve;

  @override
  Widget build(BuildContext context) {
    _resolveMotion();
    final strings = UiLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        _scrollAvailableHeight = available;
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            if (_dismissed) {
              return const SizedBox.shrink();
            }
            final fraction = _dragFraction ?? _anim.value;
            final height = (fraction * available).clamp(0.0, available);
            if (height == 0) {
              return const SizedBox.shrink();
            }
            // PR-5 arbitration: descendants' scroll notifications
            // bubble into the listener below. Inner-list drags that
            // stay within the list's scroll range are absorbed by the
            // list (standard arena behaviour). Drags that push past
            // the list's boundary produce OverscrollNotifications;
            // those leftover pixels drive the sheet's expand/collapse
            // instead. On `ScrollEndNotification` we snap to the
            // nearest snap point so releases feel deterministic.
            final child = NotificationListener<ScrollNotification>(
              onNotification: _onInnerScrollNotification,
              child: Semantics(
                container: true,
                label: strings.sheet,
                child: RepaintBoundary(child: widget.child),
              ),
            );
            return Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: persistentSheetSurfaceKey,
                width: double.infinity,
                height: height,
                child: widget.enableDrag
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (d) =>
                            _onDragUpdate(d, available),
                        onVerticalDragEnd: (d) => _onDragEnd(d, available),
                        child: child,
                      )
                    : child,
              ),
            );
          },
        );
      },
    );
  }
}

class _SheetHost<T> extends StatefulWidget {
  const _SheetHost({
    required this.snap,
    required this.isDismissible,
    required this.controller,
    required this.builder,
    this.maxWidth,
  });

  final UiSheetSnap snap;
  final bool isDismissible;
  final UiSheetController<T> controller;
  final Widget Function(BuildContext, UiSheetController<T>) builder;
  final double? maxWidth;

  @override
  State<_SheetHost<T>> createState() => _SheetHostState<T>();
}

class _SheetHostState<T> extends State<_SheetHost<T>> {
  double _dragOffset = 0;

  double _resolveMaxHeight(BoxConstraints constraints) {
    final snap = widget.snap;
    if (snap.isFit) return constraints.maxHeight;
    final fraction = snap.fraction ?? 1.0;
    return constraints.maxHeight * fraction;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = _resolveMaxHeight(constraints);
        // When `maxWidth` is set (typically via adaptiveMaxWidth on
        // tablet / desktop), centre the sheet and clamp its width.
        // `null` preserves the edge-to-edge phone layout.
        final widthCap = widget.maxWidth;
        final Widget sheet = Transform.translate(
          offset: Offset(0, _dragOffset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: widget.builder(context, widget.controller),
          ),
        );
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboard,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: widget.isDismissible
                    ? (d) {
                        setState(() {
                          _dragOffset =
                              (_dragOffset + d.delta.dy).clamp(0.0, 1000.0);
                        });
                      }
                    : null,
                onVerticalDragEnd: widget.isDismissible
                    ? (d) {
                        final velocity = d.primaryVelocity ?? 0;
                        if (velocity > 500 || _dragOffset > 120) {
                          widget.controller.dismiss();
                        } else {
                          setState(() => _dragOffset = 0);
                        }
                      }
                    : null,
                child: widthCap == null
                    ? sheet
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: widthCap),
                          child: sheet,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
