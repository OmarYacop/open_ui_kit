import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/primitives/ui_box.dart';
import '../../foundation/primitives/ui_pressable.dart';
import '../../foundation/primitives/ui_text.dart';
import '../../foundation/theme/ui_theme_extensions.dart';
import '../forms/button.dart' show UiIntent;

/// Stack position for toasts.
///
/// [adaptive] places toasts at the top on compact/mobile viewports and at the
/// bottom start corner on wider viewports.
enum UiToastPosition { adaptive, top, bottom }

/// Optional action button attached to a toast.
@immutable
class UiToastAction {
  const UiToastAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

/// Sonner-like toast surface.
///
/// Defaults to a compact, high-contrast card. Intent tokens drive color
/// without leaking system look, so it reads as design-system output
/// across both light and dark.
class UiToast extends StatelessWidget {
  const UiToast({
    super.key,
    required this.message,
    this.title,
    this.intent = UiIntent.defaultIntent,
    this.leading,
    this.action,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final UiIntent intent;
  final Widget? leading;
  final UiToastAction? action;

  /// Invoked when the user taps the close affordance. Rarely set by
  /// callers directly — the toaster injects its own dismiss callback.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final c = tokens.colors;
    final isDarkTheme = c.background.computeLuminance() < 0.2;

    var (bg, fg, accent) = switch (intent) {
      UiIntent.primary => (c.primary, c.primaryForeground, c.primaryForeground),
      UiIntent.destructive => (
          c.destructive,
          c.destructiveForeground,
          c.destructiveForeground,
        ),
      UiIntent.danger => (
          c.destructive,
          c.destructiveForeground,
          c.destructiveForeground,
        ),
      UiIntent.secondary => (c.secondary, c.secondaryForeground, c.foreground),
      _ => (c.popover, c.popoverForeground, c.popoverForeground),
    };
    final borderColor = c.border.withValues(alpha: 0.92);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.hasBoundedWidth
            ? math.min(420.0, constraints.maxWidth)
            : 420.0;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 52),
          child: UiBox(
            background: bg,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: tokens.radius.lgAll,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.x5,
              vertical: tokens.spacing.x4,
            ),
            boxShadow: tokens.shadows.lg,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: accent, size: 18),
                    child: leading!,
                  ),
                  SizedBox(width: tokens.spacing.x3),
                ],
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, textConstraints) {
                      final compactHeight = textConstraints.hasBoundedHeight &&
                          textConstraints.maxHeight <= 56;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null) ...[
                            UiText(
                              title!,
                              variant: UiTextVariant.label,
                              maxLines: compactHeight ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg),
                            ),
                            SizedBox(height: tokens.spacing.x1),
                          ],
                          UiText(
                            message,
                            variant: UiTextVariant.bodySm,
                            maxLines:
                                compactHeight ? (title == null ? 2 : 1) : null,
                            overflow:
                                compactHeight ? TextOverflow.ellipsis : null,
                            softWrap: true,
                            style: TextStyle(color: fg),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (action != null) ...[
                  SizedBox(width: tokens.spacing.x3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 128),
                    child: UiPressable(
                      onPressed: action!.onPressed,
                      minTapSize: 0,
                      builder: (context, state, _) {
                        final isDefaultDark =
                            intent == UiIntent.defaultIntent && isDarkTheme;
                        final actionBg = isDefaultDark
                            ? (state.pressed
                                ? const Color(0xFFE4E4E7)
                                : state.hovered
                                    ? const Color(0xFFEDEDF0)
                                    : const Color(0xFFF4F4F5))
                            : state.hovered || state.pressed
                                ? c.accent
                                : const Color(0x00000000);
                        final actionFg =
                            isDefaultDark ? const Color(0xFF18181B) : accent;
                        return UiBox(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.x2,
                            vertical: tokens.spacing.x1,
                          ),
                          borderRadius: tokens.radius.smAll,
                          background: actionBg,
                          border: Border.all(
                            color: isDefaultDark
                                ? const Color(0x00000000)
                                : accent.withValues(
                                    alpha: state.hovered ? 0.7 : 0.35,
                                  ),
                          ),
                          child: UiText(
                            action!.label,
                            variant: UiTextVariant.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: actionFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Toaster --------------------------------------------------------------

@immutable
class _ToastSpec {
  const _ToastSpec({
    required this.id,
    required this.builder,
    required this.duration,
    required this.position,
  });
  final int id;
  final WidgetBuilder builder;
  final Duration duration;
  final UiToastPosition position;
}

class _ToastController {
  static final _ToastController instance = _ToastController._();
  _ToastController._();
  static const Duration exitDuration = Duration(milliseconds: 200);

  final ValueNotifier<List<_ToastSpec>> _visible =
      ValueNotifier<List<_ToastSpec>>(const []);
  final Map<int, Timer> _timers = <int, Timer>{};
  final Map<int, DateTime> _dismissAt = <int, DateTime>{};
  final Map<int, Duration> _remaining = <int, Duration>{};
  final Set<int> _dismissing = <int>{};
  int _nextId = 0;
  int _maxVisible = 3;
  int _pauseRequests = 0;

  ValueListenable<List<_ToastSpec>> get visibleListenable => _visible;

  int get maxVisible => _maxVisible;
  bool isDismissing(int id) => _dismissing.contains(id);

  void setMaxVisible(int value) {
    if (value < 1) value = 1;
    if (value == _maxVisible) return;
    _maxVisible = value;
    final overflow = _visible.value.length - _maxVisible;
    if (overflow <= 0) return;
    final trimmed = _visible.value.sublist(overflow);
    for (final dropped in _visible.value.take(overflow)) {
      _dismissing.remove(dropped.id);
      _timers.remove(dropped.id)?.cancel();
      _dismissAt.remove(dropped.id);
      _remaining.remove(dropped.id);
    }
    _visible.value = trimmed;
  }

  VoidCallback push(_ToastSpec spec) {
    final active = _visible.value
        .where((s) => !_dismissing.contains(s.id))
        .toList(growable: false);
    if (active.length >= _maxVisible) {
      _startDismiss(active.first.id, notify: false);
    }
    _visible.value = [..._visible.value, spec];
    _scheduleDismiss(spec);
    return () => dismiss(spec.id);
  }

  void _scheduleDismiss(_ToastSpec spec) {
    _timers[spec.id]?.cancel();
    if (_pauseRequests > 0) {
      _remaining[spec.id] = spec.duration;
      _dismissAt.remove(spec.id);
      return;
    }
    _startTimer(spec.id, spec.duration);
  }

  void dismiss(int id) {
    _startDismiss(id);
  }

  void _startDismiss(int id, {bool notify = true}) {
    if (_dismissing.contains(id)) return;
    if (_visible.value.indexWhere((s) => s.id == id) == -1) return;
    _timers.remove(id)?.cancel();
    _dismissAt.remove(id);
    _remaining.remove(id);
    _dismissing.add(id);
    if (notify) {
      // Trigger rebuild so slots can animate exit.
      _visible.value = [..._visible.value];
    }
    Timer(exitDuration, () {
      _dismissing.remove(id);
      _dismissAt.remove(id);
      _remaining.remove(id);
      final next = [..._visible.value];
      next.removeWhere((s) => s.id == id);
      _visible.value = next;
    });
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _dismissAt.clear();
    _remaining.clear();
    _dismissing.clear();
    _pauseRequests = 0;
    _visible.value = const [];
  }

  int nextId() => _nextId++;

  void pauseTimers() {
    _pauseRequests += 1;
    if (_pauseRequests != 1) return;
    final now = DateTime.now();
    for (final entry in _timers.entries.toList()) {
      entry.value.cancel();
      final dismissAt = _dismissAt[entry.key];
      _remaining[entry.key] =
          dismissAt == null ? Duration.zero : dismissAt.difference(now);
    }
    _timers.clear();
    _dismissAt.clear();
  }

  void resumeTimers() {
    if (_pauseRequests == 0) return;
    _pauseRequests -= 1;
    if (_pauseRequests != 0) return;
    for (final entry in _remaining.entries.toList()) {
      if (_visible.value.indexWhere((s) => s.id == entry.key) == -1) {
        _remaining.remove(entry.key);
        continue;
      }
      _startTimer(entry.key, entry.value);
    }
  }

  void _startTimer(int id, Duration duration) {
    final effectiveDuration =
        duration <= Duration.zero ? Duration.zero : duration;
    _remaining.remove(id);
    _dismissAt[id] = DateTime.now().add(effectiveDuration);
    _timers[id] = Timer(effectiveDuration, () => dismiss(id));
  }
}

/// Sonner-like toaster.
///
/// Call [UiToaster.show] / [UiToaster.showToast] from anywhere with a
/// [BuildContext] whose subtree has an `Overlay`. The first call installs
/// a single overlay entry; subsequent toasts stack and, when the stack is
/// full, the oldest visible toast is replaced by the newest.
class UiToaster {
  UiToaster._();

  static OverlayEntry? _hostEntry;
  static int? _installedThemeSignature;

  /// Maximum number of toasts visible at once. Defaults to 3 (matches
  /// Sonner's default).
  static int get maxVisible => _ToastController.instance.maxVisible;
  static set maxVisible(int value) =>
      _ToastController.instance.setMaxVisible(value);

  /// Shows a simple titled message.
  static VoidCallback show(
    BuildContext context, {
    required String message,
    String? title,
    UiIntent intent = UiIntent.defaultIntent,
    Widget? leading,
    UiToastAction? action,
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    return showToast(
      context,
      (_) => UiToast(
        title: title,
        message: message,
        intent: intent,
        leading: leading,
        action: action,
      ),
      duration: duration,
      position: position,
    );
  }

  /// Shows an arbitrary widget as the toast surface.
  static VoidCallback showToast(
    BuildContext context,
    WidgetBuilder builder, {
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    _installHost(context);
    final id = _ToastController.instance.nextId();
    return _ToastController.instance.push(
      _ToastSpec(
        id: id,
        builder: builder,
        duration: duration,
        position: position,
      ),
    );
  }

  /// Removes every visible toast.
  static void dismissAll() => _ToastController.instance.clear();

  /// Tracks the overlay we last inserted into. Reset when that overlay is
  /// torn down (between tests or page swaps) so we re-install on the next
  /// toast request instead of trying to reuse a detached entry.
  static OverlayState? _installedInto;

  static void _installHost(BuildContext context) {
    final overlay = Overlay.of(context);
    final tokens = UiThemeTokens.of(context);
    final themeSignature = Object.hash(
      tokens.colors.background.toARGB32(),
      tokens.colors.surface.toARGB32(),
      tokens.colors.textPrimary.toARGB32(),
      tokens.colors.border.toARGB32(),
      tokens.colors.primary.toARGB32(),
    );
    if (_hostEntry != null &&
        _installedInto == overlay &&
        _installedThemeSignature == themeSignature) {
      return;
    }
    // Reinstall when overlay target or theme signature changes so toasts
    // always follow the active subtree theme (light/dark/system).
    _hostEntry?.remove();
    final capturedThemes = InheritedTheme.capture(
      from: context,
      to: overlay.context,
    );
    _hostEntry = OverlayEntry(
      builder: (_) => capturedThemes.wrap(const _ToastHost()),
    );
    overlay.insert(_hostEntry!);
    _installedInto = overlay;
    _installedThemeSignature = themeSignature;
  }
}

/// Back-compat shim for the older API.
class UiToastOverlay {
  UiToastOverlay._();

  /// Legacy entrypoint: shows a single ready-made toast widget. Forwards
  /// to [UiToaster.showToast].
  static VoidCallback show(
    BuildContext context, {
    required Widget toast,
    Duration duration = const Duration(seconds: 3),
    UiToastPosition position = UiToastPosition.adaptive,
  }) {
    return UiToaster.showToast(
      context,
      (_) => toast,
      duration: duration,
      position: position,
    );
  }
}

class _ToastHost extends StatelessWidget {
  const _ToastHost();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_ToastSpec>>(
      valueListenable: _ToastController.instance.visibleListenable,
      builder: (context, specs, _) {
        if (specs.isEmpty) return const SizedBox.shrink();
        final mediaSize = MediaQuery.maybeSizeOf(context);
        final isCompact = mediaSize == null || mediaSize.shortestSide < 600;
        final topSpecs =
            specs.where((s) => _resolvesTop(s.position, isCompact)).toList();
        final bottomSpecs =
            specs.where((s) => s.position == UiToastPosition.bottom).toList();
        final adaptiveBottomSpecs = specs
            .where(
              (s) => s.position == UiToastPosition.adaptive && !isCompact,
            )
            .toList();
        return Stack(
          fit: StackFit.expand,
          children: [
            if (topSpecs.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child:
                    _ToastLane(specs: topSpecs, position: UiToastPosition.top),
              ),
            if (bottomSpecs.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ToastLane(
                  specs: bottomSpecs,
                  position: UiToastPosition.bottom,
                ),
              ),
            if (adaptiveBottomSpecs.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ToastLane(
                  specs: adaptiveBottomSpecs,
                  position: UiToastPosition.bottom,
                  alignStart: true,
                ),
              ),
          ],
        );
      },
    );
  }

  bool _resolvesTop(UiToastPosition position, bool isCompact) {
    return switch (position) {
      UiToastPosition.top => true,
      UiToastPosition.bottom => false,
      UiToastPosition.adaptive => isCompact,
    };
  }
}

class _ToastLane extends StatefulWidget {
  const _ToastLane({
    required this.specs,
    required this.position,
    this.alignStart = false,
  });
  final List<_ToastSpec> specs;
  final UiToastPosition position;
  final bool alignStart;

  @override
  State<_ToastLane> createState() => _ToastLaneState();
}

class _ToastLaneState extends State<_ToastLane> {
  static const double _gap = 14;
  static const double _scaleStep = 0.05;

  final Map<int, double> _heights = <int, double>{};
  double _lastFrontHeight = _ToastMetrics.fallbackHeight;
  bool _hovering = false;
  bool _interacting = false;
  bool _timersPaused = false;

  @override
  void dispose() {
    if (_timersPaused) {
      _ToastController.instance.resumeTimers();
      _timersPaused = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final mq = MediaQuery.maybeOf(context);
    final padding = mq?.padding ?? EdgeInsets.zero;
    final isBottom = widget.position == UiToastPosition.bottom;
    final ordered = [...widget.specs];
    final expanded = ordered.length > 1 && (_hovering || _interacting);
    final frontHeight = ordered.isEmpty
        ? _lastFrontHeight
        : (_heights[ordered.last.id] ?? _lastFrontHeight);
    final duration = tokens.motion.standard == Duration.zero
        ? Duration.zero
        : _ToastMetrics.transitionDuration;

    return MouseRegion(
      onEnter: (_) => _setHovering(true),
      onHover: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setInteracting(true),
        onPointerCancel: (_) => _setInteracting(false),
        onPointerUp: (_) => _setInteracting(false),
        child: Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.x4,
            right: tokens.spacing.x4,
            top: isBottom ? 0 : padding.top + tokens.spacing.x4,
            bottom: isBottom ? padding.bottom + tokens.spacing.x4 : 0,
          ),
          child: Align(
            alignment: _alignment(isBottom),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: _alignment(isBottom),
              children: [
                for (var i = 0; i < ordered.length; i++)
                  _ToastSlot(
                    key: ValueKey<int>(ordered[i].id),
                    spec: ordered[i],
                    indexFromFront: ordered.length - 1 - i,
                    collapsedScale: math.max(
                      0.82,
                      1 - (ordered.length - 1 - i) * _scaleStep,
                    ),
                    collapsedOffset: _collapsedOffset(
                      ordered.length - 1 - i,
                      isBottom,
                    ),
                    expandedOffset: expanded ? _expandedOffset(ordered, i) : 0,
                    frontHeight: frontHeight,
                    expanded: expanded,
                    isBottom: isBottom,
                    duration: duration,
                    dismissing: _ToastController.instance.isDismissing(
                      ordered[i].id,
                    ),
                    onSizeChanged: (height) =>
                        _handleSizeChanged(ordered[i].id, height),
                    onInteractingChanged: _setInteracting,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AlignmentDirectional _alignment(bool isBottom) {
    if (isBottom && widget.alignStart) return AlignmentDirectional.bottomStart;
    return isBottom
        ? AlignmentDirectional.bottomCenter
        : AlignmentDirectional.topCenter;
  }

  double _expandedOffset(List<_ToastSpec> ordered, int index) {
    var offset = 0.0;
    for (var i = ordered.length - 1; i > index; i--) {
      offset +=
          (_heights[ordered[i].id] ?? _ToastMetrics.fallbackHeight) + _gap;
    }
    if (widget.position == UiToastPosition.bottom) return -offset;
    return offset;
  }

  double _collapsedOffset(int indexFromFront, bool isBottom) {
    final offset = _gap * indexFromFront;
    return isBottom ? -offset : offset;
  }

  void _setHovering(bool value) {
    if (!mounted) return;
    if (_hovering == value) return;
    setState(() => _hovering = value);
    _syncTimerPause();
  }

  void _setInteracting(bool value) {
    if (!mounted) return;
    if (_interacting == value) return;
    setState(() => _interacting = value);
    _syncTimerPause();
  }

  void _handleSizeChanged(int id, double height) {
    if (!mounted) return;
    final previous = _heights[id];
    if (previous != null && (previous - height).abs() < 0.5) return;
    setState(() {
      _heights[id] = height;
      if (widget.specs.isNotEmpty && widget.specs.last.id == id) {
        _lastFrontHeight = height;
      }
    });
  }

  void _syncTimerPause() {
    if (!mounted) return;
    final shouldPause = _hovering || _interacting;
    if (shouldPause == _timersPaused) return;
    _timersPaused = shouldPause;
    if (shouldPause) {
      _ToastController.instance.pauseTimers();
    } else {
      _ToastController.instance.resumeTimers();
    }
  }
}

class _ToastSlot extends StatefulWidget {
  const _ToastSlot({
    super.key,
    required this.spec,
    required this.indexFromFront,
    required this.collapsedScale,
    required this.collapsedOffset,
    required this.expandedOffset,
    required this.frontHeight,
    required this.expanded,
    required this.isBottom,
    required this.duration,
    required this.dismissing,
    required this.onSizeChanged,
    required this.onInteractingChanged,
  });
  final _ToastSpec spec;
  final int indexFromFront;
  final double collapsedScale;
  final double collapsedOffset;
  final double expandedOffset;
  final double frontHeight;
  final bool expanded;
  final bool isBottom;
  final Duration duration;
  final bool dismissing;
  final ValueChanged<double> onSizeChanged;
  final ValueChanged<bool> onInteractingChanged;

  @override
  State<_ToastSlot> createState() => _ToastSlotState();
}

class _ToastSlotState extends State<_ToastSlot> {
  Offset? _dragStart;
  DateTime? _dragStartedAt;
  double _swipeX = 0;
  double _swipeY = 0;
  bool _swiping = false;
  bool _started = false;
  bool _mountedInPlace = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = UiThemeTokens.of(context).motion;
    if (_started) return;
    _started = true;
    if (motion.standard == Duration.zero) {
      _mountedInPlace = true;
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mountedInPlace = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncSize();
    final slotAlignment =
        widget.isBottom ? Alignment.bottomCenter : Alignment.topCenter;

    final entryOffset = _mountedInPlace
        ? 0.0
        : (widget.isBottom ? widget.frontHeight : -widget.frontHeight);
    final removalOffset = widget.indexFromFront == 0 || widget.expanded
        ? (widget.isBottom ? widget.frontHeight : -widget.frontHeight)
        : (widget.isBottom ? -widget.frontHeight : widget.frontHeight) * 0.4;
    final stackOffset =
        widget.expanded ? widget.expandedOffset : widget.collapsedOffset;
    final y =
        widget.dismissing ? removalOffset : entryOffset + stackOffset + _swipeY;
    final scale = widget.expanded ? 1.0 : widget.collapsedScale;
    final opacity = widget.dismissing ? 0.0 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration:
          widget.dismissing ? _ToastMetrics.exitDuration : widget.duration,
      curve: Curves.ease,
      child: AnimatedContainer(
        duration: _swiping ? Duration.zero : widget.duration,
        curve: Curves.ease,
        transform: Matrix4.translationValues(_swipeX, y, 0),
        child: AnimatedScale(
          scale: scale,
          alignment: slotAlignment,
          duration: widget.duration,
          curve: Curves.ease,
          child: _Dismissible(
            onDragDown: _handleDragDown,
            onDragStart: _handleDragStart,
            onDragUpdate: _handleDragUpdate,
            onDragEnd: _handleDragEnd,
            onInteractingChanged: widget.onInteractingChanged,
            child: Builder(builder: widget.spec.builder),
          ),
        ),
      ),
    );
  }

  void _syncSize() {
    if (!widget.expanded && widget.indexFromFront > 0) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      widget.onSizeChanged(renderObject.size.height);
    });
  }

  void _handleDragDown(DragDownDetails details) {
    if (!mounted) return;
    _dragStart = details.globalPosition;
    _dragStartedAt = DateTime.now();
    setState(() => _swiping = true);
  }

  void _handleDragStart(DragStartDetails details) {
    if (!mounted) return;
    _dragStart ??= details.globalPosition;
    _dragStartedAt ??= DateTime.now();
    setState(() => _swiping = true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!mounted) return;
    final start = _dragStart;
    if (start == null) return;
    final delta = details.globalPosition - start;
    final allowed = widget.isBottom ? delta.dy > 0 : delta.dy < 0;
    final y = allowed ? delta.dy : delta.dy * _dampening(delta.dy);
    setState(() {
      _swipeX = delta.dx;
      _swipeY = y;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!mounted) return;
    final startedAt = _dragStartedAt;
    final elapsed = startedAt == null
        ? 1
        : math.max(1, DateTime.now().difference(startedAt).inMilliseconds);
    final velocity = _swipeY.abs() / elapsed;
    final shouldDismiss = _swipeY.abs() >= _ToastMetrics.swipeThreshold ||
        velocity > _ToastMetrics.swipeVelocityThreshold ||
        details.velocity.pixelsPerSecond.dx.abs() > 200;

    if (shouldDismiss) {
      _ToastController.instance.dismiss(widget.spec.id);
    }
    setState(() {
      _swiping = false;
      _swipeX = 0;
      _swipeY = 0;
      _dragStart = null;
      _dragStartedAt = null;
    });
  }

  double _dampening(double delta) {
    final factor = delta.abs() / 20;
    return 1 / (1.5 + factor);
  }
}

class _ToastMetrics {
  const _ToastMetrics._();

  static const double fallbackHeight = 80;
  static const double swipeThreshold = 45;
  static const double swipeVelocityThreshold = 0.11;
  static const Duration transitionDuration = Duration(milliseconds: 400);
  static const Duration exitDuration = Duration(milliseconds: 200);
}

class _Dismissible extends StatelessWidget {
  const _Dismissible({
    required this.child,
    required this.onDragDown,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onInteractingChanged,
  });
  final Widget child;
  final GestureDragDownCallback onDragDown;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final ValueChanged<bool> onInteractingChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onInteractingChanged(true),
      onTapUp: (_) => onInteractingChanged(false),
      onTapCancel: () => onInteractingChanged(false),
      onPanDown: (details) {
        onInteractingChanged(true);
        onDragDown(details);
      },
      onPanStart: (details) {
        onInteractingChanged(true);
        onDragStart(details);
      },
      onPanUpdate: onDragUpdate,
      onPanEnd: (details) {
        onDragEnd(details);
        onInteractingChanged(false);
      },
      onPanCancel: () => onInteractingChanged(false),
      child: child,
    );
  }
}
