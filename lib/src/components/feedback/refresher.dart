import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/intl/ui_localizations.dart';
import '../../foundation/motion/ui_motion_spec.dart';
import '../../foundation/overlay/ui_layered_overlay.dart';
import '../../foundation/theme/ui_theme_extensions.dart';

/// Lifecycle states shared by [UiRefresher] and [UiSliverRefresher].
enum UiRefreshStatus {
  idle,
  dragging,
  armed,
  refreshing,
  completed,
  failed,
}

/// Immutable input passed to a [UiRefreshIndicatorBuilder].
@immutable
class UiRefreshIndicatorDetails {
  const UiRefreshIndicatorDetails({
    required this.status,
    required this.progress,
    required this.pulledExtent,
    required this.triggerDistance,
    this.error,
  });

  /// Current refresh lifecycle state.
  final UiRefreshStatus status;

  /// Pull progress in the inclusive range 0–1.
  ///
  /// This remains 1 while refreshing and while completion feedback is shown.
  final double progress;

  /// Current physical pull/reveal extent in logical pixels.
  final double pulledExtent;

  /// Distance at which releasing the gesture starts a refresh.
  final double triggerDistance;

  /// Error thrown by the refresh callback when [status] is
  /// [UiRefreshStatus.failed].
  final Object? error;
}

typedef UiRefreshIndicatorBuilder = Widget Function(
  BuildContext context,
  UiRefreshIndicatorDetails details,
);

typedef UiRefreshErrorCallback = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Imperative companion for [UiRefresher].
///
/// A controller is optional; pull-to-refresh works without one. Use [refresh]
/// for desktop refresh buttons, keyboard shortcuts, or initial silent loads
/// that should share the same concurrency guard and visual feedback.
class UiRefresherController {
  _UiRefresherState? _state;

  bool get attached => _state != null;

  UiRefreshStatus get status => _state?._status ?? UiRefreshStatus.idle;

  bool get isRefreshing => status == UiRefreshStatus.refreshing;

  /// Starts a refresh or returns the active refresh future when one is already
  /// running.
  ///
  /// The future completes with the refresh callback. Terminal visual feedback
  /// may remain briefly afterward; callback errors are rethrown to the caller.
  Future<void> refresh() {
    final state = _state;
    if (state == null) {
      throw StateError(
        'UiRefresherController.refresh() requires an attached UiRefresher.',
      );
    }
    return state._requestRefresh();
  }

  void _attach(_UiRefresherState state) {
    if (_state != null && _state != state) {
      throw StateError(
        'A UiRefresherController cannot be attached to multiple refreshers.',
      );
    }
    _state = state;
  }

  void _detach(_UiRefresherState state) {
    if (_state == state) _state = null;
  }
}

/// Pull-to-refresh behavior for any vertical, non-reversed [Scrollable].
///
/// The child remains in control of its content and scroll controller; this
/// widget only listens to scroll notifications and paints the indicator above
/// it. By default it composes always-scrollable physics into the ambient
/// [ScrollBehavior], so even short lists can refresh.
///
/// ```dart
/// UiRefresher(
///   onRefresh: controller.reload,
///   child: ListView.builder(
///     itemCount: items.length,
///     itemBuilder: (_, index) => ItemTile(items[index]),
///   ),
/// )
/// ```
///
/// Use [UiSliverRefresher] when the indicator needs to participate in a
/// `CustomScrollView`'s sliver layout.
class UiRefresher extends StatefulWidget {
  const UiRefresher({
    super.key,
    required this.onRefresh,
    required this.child,
    this.controller,
    this.indicatorBuilder,
    this.onStatusChanged,
    this.onError,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.enabled = true,
    this.alwaysScrollable = true,
    this.triggerDistance = 72,
    this.indicatorExtent = 56,
    this.edgeOffset = 0,
    this.maxDragExtent,
    this.dragResistance = 0.55,
    this.settleDuration = UiMotionDuration.fast,
    this.feedbackDuration,
    this.dismissDuration = UiMotionDuration.standard,
  })  : assert(triggerDistance > 0),
        assert(indicatorExtent > 0),
        assert(edgeOffset >= 0),
        assert(maxDragExtent == null || maxDragExtent >= triggerDistance),
        assert(dragResistance > 0 && dragResistance <= 1);

  final Future<void> Function() onRefresh;
  final Widget child;
  final UiRefresherController? controller;
  final UiRefreshIndicatorBuilder? indicatorBuilder;
  final ValueChanged<UiRefreshStatus>? onStatusChanged;
  final UiRefreshErrorCallback? onError;
  final ScrollNotificationPredicate notificationPredicate;
  final bool enabled;

  /// Ensures short scrollables can overscroll without replacing explicit
  /// physics supplied by the child.
  final bool alwaysScrollable;

  final double triggerDistance;
  final double indicatorExtent;
  final double edgeOffset;
  final double? maxDragExtent;

  /// Resistance applied when clamping physics report rejected overscroll.
  final double dragResistance;

  final UiMotionDuration settleDuration;

  /// How long completion/error feedback remains readable. This is a content
  /// hold, not animation timing, so it intentionally remains a [Duration].
  final Duration? feedbackDuration;
  final UiMotionDuration dismissDuration;

  double _effectiveEdgeOffset(BuildContext context) {
    return MediaQuery.viewPaddingOf(context).top + edgeOffset;
  }

  /// Physics suitable for [UiSliverRefresher] on every platform.
  static const ScrollPhysics sliverPhysics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  State<UiRefresher> createState() => _UiRefresherState();
}

class _UiRefresherState extends State<UiRefresher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  Timer? _feedbackTimer;
  Completer<void>? _feedbackDelay;

  Animation<double>? _extentAnimation;
  UiRefreshStatus _status = UiRefreshStatus.idle;
  double _pulledExtent = 0;
  bool _scrollDragActive = false;
  Future<void>? _refreshFuture;
  Object? _error;

  double get _maxDragExtent =>
      widget.maxDragExtent ?? widget.triggerDistance * 1.6;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(vsync: this)
      ..addListener(_tickMotion);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(UiRefresher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.enabled && !widget.enabled && _refreshFuture == null) {
      _scrollDragActive = false;
      _setStatus(UiRefreshStatus.idle);
      _setPulledExtent(0);
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _feedbackDelay?.complete();
    widget.controller?._detach(this);
    _motionController.dispose();
    super.dispose();
  }

  void _tickMotion() {
    final animation = _extentAnimation;
    if (animation == null || !mounted) return;
    setState(() => _pulledExtent = animation.value);
  }

  void _setStatus(UiRefreshStatus next) {
    if (_status == next || !mounted) return;
    setState(() => _status = next);
    widget.onStatusChanged?.call(next);
  }

  void _setPulledExtent(double value) {
    final next = value.clamp(0.0, _maxDragExtent).toDouble();
    if ((_pulledExtent - next).abs() < 0.01 || !mounted) return;
    setState(() => _pulledExtent = next);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.enabled || !widget.notificationPredicate(notification)) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.axisDirection != AxisDirection.down) return false;

    if (_refreshFuture != null ||
        _status == UiRefreshStatus.refreshing ||
        _status == UiRefreshStatus.completed ||
        _status == UiRefreshStatus.failed) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        _atLeadingEdge(metrics)) {
      _motionController.stop();
      _scrollDragActive = true;
      _error = null;
      _setStatus(UiRefreshStatus.dragging);
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null && _scrollDragActive) {
        _releasePull();
        return false;
      }

      final beyondLeadingEdge = metrics.minScrollExtent - metrics.pixels;
      if (beyondLeadingEdge > 0 && notification.dragDetails != null) {
        _motionController.stop();
        _scrollDragActive = true;
        _updatePull(beyondLeadingEdge);
      } else if (!_atLeadingEdge(metrics) && _scrollDragActive) {
        _cancelPull();
      }
      return false;
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        _atLeadingEdge(metrics)) {
      _motionController.stop();
      _scrollDragActive = true;
      _updatePull(
        _pulledExtent + (-notification.overscroll * widget.dragResistance),
      );
      return false;
    }

    if (notification is ScrollEndNotification && _scrollDragActive) {
      _releasePull();
    }
    return false;
  }

  bool _atLeadingEdge(ScrollMetrics metrics) {
    return metrics.extentBefore <= 0 &&
        metrics.pixels <= metrics.minScrollExtent + 0.5;
  }

  void _updatePull(double extent) {
    _setPulledExtent(extent);
    final next = extent >= widget.triggerDistance
        ? UiRefreshStatus.armed
        : UiRefreshStatus.dragging;
    _setStatus(next);
  }

  void _handlePointerUp(PointerEvent event) {
    if (_scrollDragActive) _releasePull();
  }

  void _releasePull() {
    if (!_scrollDragActive) return;
    _scrollDragActive = false;
    if (_status == UiRefreshStatus.armed) {
      unawaited(_requestRefresh().catchError((Object _) {}));
    } else if (_status == UiRefreshStatus.dragging) {
      _cancelPull();
    }
  }

  void _cancelPull() {
    _scrollDragActive = false;
    unawaited(_dismissToIdle());
  }

  Future<void> _requestRefresh() {
    final active = _refreshFuture;
    if (active != null) return active;
    if (!widget.enabled) {
      return Future<void>.error(
        StateError('Cannot refresh while UiRefresher.enabled is false.'),
      );
    }

    final completer = Completer<void>();
    _refreshFuture = completer.future;
    unawaited(_performRefresh(completer));
    return completer.future;
  }

  Future<void> _performRefresh(Completer<void> completer) async {
    _scrollDragActive = false;
    _error = null;
    _setStatus(UiRefreshStatus.refreshing);

    final settle = widget.settleDuration.resolve(context);
    unawaited(
      _animateExtentTo(widget.triggerDistance, settle),
    );

    Object? caughtError;
    StackTrace? caughtStack;
    try {
      await widget.onRefresh();
    } catch (error, stackTrace) {
      caughtError = error;
      caughtStack = stackTrace;
      if (mounted) widget.onError?.call(error, stackTrace);
    }

    if (mounted) {
      _error = caughtError;
      _setStatus(
        caughtError == null
            ? UiRefreshStatus.completed
            : UiRefreshStatus.failed,
      );
    }

    if (caughtError == null) {
      completer.complete();
    } else {
      completer.completeError(caughtError, caughtStack!);
    }

    if (mounted) {
      final feedback =
          widget.feedbackDuration ?? UiThemeTokens.motionOf(context).slow;
      if (!_animationsDisabled && feedback > Duration.zero) {
        await _waitForFeedback(feedback);
      }
      await _dismissToIdle();
    }

    _refreshFuture = null;
  }

  Future<void> _waitForFeedback(Duration duration) {
    _feedbackTimer?.cancel();
    final completer = Completer<void>();
    _feedbackDelay = completer;
    _feedbackTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
      if (identical(_feedbackDelay, completer)) _feedbackDelay = null;
      _feedbackTimer = null;
    });
    return completer.future;
  }

  Future<void> _dismissToIdle() async {
    if (!mounted) return;
    final duration = widget.dismissDuration.resolve(context);
    await _animateExtentTo(0, duration);
    if (!mounted) return;
    _error = null;
    _setStatus(UiRefreshStatus.idle);
  }

  bool get _animationsDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Future<void> _animateExtentTo(double target, Duration duration) async {
    if (!mounted) return;
    _motionController.stop();
    if (_animationsDisabled || duration == Duration.zero) {
      _setPulledExtent(target);
      return;
    }

    _motionController.duration = duration;
    _extentAnimation = Tween<double>(begin: _pulledExtent, end: target).animate(
      CurvedAnimation(
        parent: _motionController,
        curve: UiThemeTokens.motionOf(context).standardCurve,
      ),
    );
    try {
      await _motionController.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A new gesture or lifecycle teardown superseded this transition.
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget scrollable = widget.child;
    if (widget.alwaysScrollable) {
      final behavior = ScrollConfiguration.of(context);
      scrollable = ScrollConfiguration(
        behavior: behavior.copyWith(
          physics: AlwaysScrollableScrollPhysics(
            parent: behavior.getScrollPhysics(context),
          ),
        ),
        child: scrollable,
      );
    }

    final progress = switch (_status) {
      UiRefreshStatus.refreshing ||
      UiRefreshStatus.completed ||
      UiRefreshStatus.failed =>
        1.0,
      _ => (_pulledExtent / widget.triggerDistance).clamp(0.0, 1.0),
    };
    final details = UiRefreshIndicatorDetails(
      status: _status,
      progress: progress,
      pulledExtent: _pulledExtent,
      triggerDistance: widget.triggerDistance,
      error: _error,
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            scrollable,
            _UiRefreshOverlay(
              details: details,
              indicatorExtent: widget.indicatorExtent,
              edgeOffset: widget._effectiveEdgeOffset(context),
              indicatorBuilder:
                  widget.indicatorBuilder ?? _defaultRefreshIndicatorBuilder,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliver-native refresh control for a [CustomScrollView].
///
/// Place this before the first content sliver and give the scroll view
/// [UiRefresher.sliverPhysics] so refresh remains available on every platform
/// and when the content is shorter than the viewport.
class UiSliverRefresher extends StatefulWidget {
  const UiSliverRefresher({
    super.key,
    required this.onRefresh,
    this.indicatorBuilder,
    this.onStatusChanged,
    this.onError,
    this.triggerDistance = 96,
    this.indicatorExtent = 64,
    this.edgeOffset = 0,
  })  : assert(triggerDistance > 0),
        assert(indicatorExtent > 0),
        assert(edgeOffset >= 0),
        assert(triggerDistance >= indicatorExtent);

  final Future<void> Function() onRefresh;
  final UiRefreshIndicatorBuilder? indicatorBuilder;
  final ValueChanged<UiRefreshStatus>? onStatusChanged;
  final UiRefreshErrorCallback? onError;
  final double triggerDistance;
  final double indicatorExtent;

  /// Extra spacing below the safe top inset.
  ///
  /// The system top inset is applied automatically so the refresh indicator
  /// stays below status bars, notches, dynamic islands, and page safe
  /// viewports. Use this to add visual separation from adjacent chrome.
  final double edgeOffset;

  @override
  State<UiSliverRefresher> createState() => _UiSliverRefresherState();
}

class _UiSliverRefresherState extends State<UiSliverRefresher> {
  UiRefreshStatus _terminalStatus = UiRefreshStatus.completed;
  UiRefreshStatus? _reportedStatus;
  Object? _error;

  Future<void> _refresh() async {
    _terminalStatus = UiRefreshStatus.completed;
    _error = null;
    try {
      await widget.onRefresh();
    } catch (error, stackTrace) {
      _terminalStatus = UiRefreshStatus.failed;
      _error = error;
      widget.onError?.call(error, stackTrace);
    }
  }

  UiRefreshStatus _statusFor(_UiRefreshIndicatorMode mode) {
    return switch (mode) {
      _UiRefreshIndicatorMode.inactive => UiRefreshStatus.idle,
      _UiRefreshIndicatorMode.drag => UiRefreshStatus.dragging,
      _UiRefreshIndicatorMode.armed => UiRefreshStatus.armed,
      _UiRefreshIndicatorMode.refresh => UiRefreshStatus.refreshing,
      _UiRefreshIndicatorMode.done => _terminalStatus,
    };
  }

  void _reportStatus(UiRefreshStatus status) {
    if (_reportedStatus == status) return;
    _reportedStatus = status;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onStatusChanged?.call(status);
    });
  }

  @override
  Widget build(BuildContext context) {
    final edgeOffset =
        MediaQuery.viewPaddingOf(context).top + widget.edgeOffset;

    return _UiSliverRefreshControl(
      refreshTriggerPullDistance: widget.triggerDistance,
      refreshIndicatorExtent: widget.indicatorExtent,
      onRefresh: _refresh,
      builder: (
        context,
        mode,
        pulledExtent,
        triggerDistance,
        indicatorExtent,
      ) {
        final status = _statusFor(mode);
        _reportStatus(status);
        final progress = switch (status) {
          UiRefreshStatus.refreshing ||
          UiRefreshStatus.completed ||
          UiRefreshStatus.failed =>
            1.0,
          _ => (pulledExtent / triggerDistance).clamp(0.0, 1.0),
        };
        final details = UiRefreshIndicatorDetails(
          status: status,
          progress: progress,
          pulledExtent: pulledExtent,
          triggerDistance: triggerDistance,
          error: status == UiRefreshStatus.failed ? _error : null,
        );
        return _UiSliverRefreshIndicator(
          details: details,
          edgeOffset: edgeOffset,
          indicatorBuilder:
              widget.indicatorBuilder ?? _defaultRefreshIndicatorBuilder,
        );
      },
    );
  }
}

class _UiRefreshOverlay extends StatelessWidget {
  const _UiRefreshOverlay({
    required this.details,
    required this.indicatorExtent,
    required this.edgeOffset,
    required this.indicatorBuilder,
  });

  final UiRefreshIndicatorDetails details;
  final double indicatorExtent;
  final double edgeOffset;
  final UiRefreshIndicatorBuilder indicatorBuilder;

  @override
  Widget build(BuildContext context) {
    final visible = details.status != UiRefreshStatus.idle;
    final tokens = UiThemeTokens.of(context);
    final animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final reveal = Curves.easeOutCubic.transform(details.progress);
    final translateY = -indicatorExtent +
        edgeOffset +
        reveal * (indicatorExtent + tokens.spacing.x2);

    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      height: indicatorExtent + edgeOffset + tokens.spacing.x2,
      child: UiLayeredOverlayPortal(
        layer: UiOverlayLayer.systemFeedback,
        child: IgnorePointer(
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration:
                    animationsDisabled ? Duration.zero : tokens.motion.fast,
                curve: tokens.motion.standardCurve,
                child: _RefreshSemantics(
                  details: details,
                  child: indicatorBuilder(context, details),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UiSliverRefreshIndicator extends StatelessWidget {
  const _UiSliverRefreshIndicator({
    required this.details,
    required this.edgeOffset,
    required this.indicatorBuilder,
  });

  final UiRefreshIndicatorDetails details;
  final double edgeOffset;
  final UiRefreshIndicatorBuilder indicatorBuilder;

  @override
  Widget build(BuildContext context) {
    if (details.status == UiRefreshStatus.idle) {
      return const SizedBox.shrink();
    }
    return Transform.translate(
      offset: Offset(0, edgeOffset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _RefreshSemantics(
          details: details,
          child: indicatorBuilder(context, details),
        ),
      ),
    );
  }
}

class _RefreshSemantics extends StatelessWidget {
  const _RefreshSemantics({required this.details, required this.child});

  final UiRefreshIndicatorDetails details;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = _refreshLabel(context, details.status);
    final reportsProgress = details.status == UiRefreshStatus.dragging ||
        details.status == UiRefreshStatus.armed;
    return Semantics(
      container: true,
      liveRegion: !reportsProgress,
      label: label,
      value: reportsProgress ? '${(details.progress * 100).round()}%' : null,
      child: ExcludeSemantics(child: child),
    );
  }
}

Widget _defaultRefreshIndicatorBuilder(
  BuildContext context,
  UiRefreshIndicatorDetails details,
) {
  return UiRefreshIndicator(details: details);
}

/// Token-driven default indicator used by both refresher variants.
///
/// The stock visual is glyph-only. Status text is still exposed through
/// semantics by the refresher host, and richer labelled surfaces can be built
/// with a custom [UiRefreshIndicatorBuilder].
class UiRefreshIndicator extends StatelessWidget {
  const UiRefreshIndicator({
    super.key,
    required this.details,
    @Deprecated(
      'UiRefreshIndicator is glyph-only. Use a custom '
      'UiRefreshIndicatorBuilder for labelled surfaces.',
    )
    this.showLabel = false,
  });

  final UiRefreshIndicatorDetails details;

  @Deprecated(
    'UiRefreshIndicator is glyph-only. Use a custom '
    'UiRefreshIndicatorBuilder for labelled surfaces.',
  )
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = UiThemeTokens.of(context);
    final foreground = switch (details.status) {
      UiRefreshStatus.completed => tokens.colors.success,
      UiRefreshStatus.failed => tokens.colors.danger,
      _ => tokens.colors.textPrimary,
    };

    return DecoratedBox(
      key: const Key('refresh_indicator_surface'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tokens.colors.background.withValues(alpha: 0.96),
            blurRadius: tokens.spacing.x3,
            spreadRadius: tokens.spacing.x1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.x1),
        child: _RefreshGlyph(
          status: details.status,
          progress: details.progress,
          color: foreground,
        ),
      ),
    );
  }
}

String _refreshLabel(BuildContext context, UiRefreshStatus status) {
  final strings = UiLocalizations.of(context);
  return switch (status) {
    UiRefreshStatus.idle || UiRefreshStatus.dragging => strings.pullToRefresh,
    UiRefreshStatus.armed => strings.releaseToRefresh,
    UiRefreshStatus.refreshing => strings.refreshing,
    UiRefreshStatus.completed => strings.refreshComplete,
    UiRefreshStatus.failed => strings.refreshFailed,
  };
}

class _RefreshGlyph extends StatefulWidget {
  const _RefreshGlyph({
    required this.status,
    required this.progress,
    required this.color,
  });

  final UiRefreshStatus status;
  final double progress;
  final Color color;

  @override
  State<_RefreshGlyph> createState() => _RefreshGlyphState();
}

class _RefreshGlyphState extends State<_RefreshGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _complete = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _complete.duration = UiThemeTokens.motionOf(context).slow;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_RefreshGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _syncAnimation();
  }

  void _syncAnimation() {
    final animationsDisabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.status == UiRefreshStatus.refreshing && !animationsDisabled) {
      _spin.repeat();
    } else {
      _spin.stop();
      if (widget.status != UiRefreshStatus.completed) _spin.value = 0;
    }

    if (widget.status == UiRefreshStatus.completed) {
      if (animationsDisabled) {
        _complete.value = 1;
      } else {
        _complete.forward(from: 0);
      }
    } else {
      _complete.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _complete.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _complete]),
        builder: (context, _) {
          return CustomPaint(
            painter: _RefreshGlyphPainter(
              status: widget.status,
              progress: widget.progress,
              phase: _spin.value,
              completion: _complete.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _RefreshGlyphPainter extends CustomPainter {
  const _RefreshGlyphPainter({
    required this.status,
    required this.progress,
    required this.phase,
    required this.completion,
    required this.color,
  });

  final UiRefreshStatus status;
  final double progress;
  final double phase;
  final double completion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    switch (status) {
      case UiRefreshStatus.idle:
      case UiRefreshStatus.dragging:
      case UiRefreshStatus.armed:
        _paintCharge(
          canvas,
          size,
          progress: progress,
          armed: status == UiRefreshStatus.armed,
        );
        break;
      case UiRefreshStatus.refreshing:
        _paintOrbit(canvas, size);
        break;
      case UiRefreshStatus.completed:
        _paintCompletion(canvas, size);
        break;
      case UiRefreshStatus.failed:
        final paint = _strokePaint(color);
        canvas.drawCircle(center, 7.5, paint);
        canvas.drawLine(
          Offset(center.dx, center.dy - 4),
          Offset(center.dx, center.dy + 1),
          paint,
        );
        canvas.drawCircle(Offset(center.dx, center.dy + 4.2), 1.1, paint);
        break;
    }
  }

  Paint _strokePaint(Color value) {
    return Paint()
      ..color = value
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Paint _fillPaint(Color value, double opacity) {
    return Paint()
      ..color = value.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
  }

  Path _checkPath(Offset center) {
    return Path()
      ..moveTo(center.dx - 4.2, center.dy)
      ..lineTo(center.dx - 1.1, center.dy + 3.1)
      ..lineTo(center.dx + 4.8, center.dy - 3.6);
  }

  Offset _orbitalPoint(Size size, int index, {double phase = 0}) {
    const count = 6;
    final radius = math.min(size.width, size.height) * 0.36;
    final center = size.center(Offset.zero);
    final angle =
        -math.pi / 2 + phase * math.pi * 2 + index * math.pi * 2 / count;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  void _paintCharge(
    Canvas canvas,
    Size size, {
    required double progress,
    required bool armed,
  }) {
    const count = 6;
    final center = size.center(Offset.zero);
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final eased = Curves.easeOutCubic.transform(clamped);
    final charged = armed ? count.toDouble() : eased * count;

    for (var i = 0; i < count; i++) {
      final point = _orbitalPoint(size, i);
      final fill = (charged - i).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(point, 1.05, _fillPaint(color, 0.1));
      if (fill > 0) {
        canvas.drawCircle(
          point,
          1.0 + fill * 1.0,
          _fillPaint(color, 0.22 + fill * 0.5),
        );
      }
    }

    canvas.drawCircle(
      center,
      1.8 + eased * 1.6,
      _fillPaint(color, armed ? 0.72 : 0.32 + eased * 0.32),
    );

    if (armed) {
      final halo = _strokePaint(color.withValues(alpha: 0.22))
        ..strokeWidth = 1.1;
      canvas.drawCircle(center, 5.4, halo);
    }
  }

  void _paintOrbit(Canvas canvas, Size size) {
    const count = 6;
    final center = size.center(Offset.zero);

    for (var i = 0; i < count; i++) {
      final point = _orbitalPoint(size, i, phase: phase);
      final wave = (1 - ((i / count - phase) % 1.0)).clamp(0.0, 1.0);
      final intensity = Curves.easeOutCubic.transform(wave);
      canvas.drawCircle(
        point,
        1.05 + intensity * 1.15,
        _fillPaint(color, 0.12 + intensity * 0.58),
      );
    }

    canvas.drawCircle(center, 2.3, _fillPaint(color, 0.4));
  }

  void _paintCompletion(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Curves.easeOutCubic.transform(completion.clamp(0.0, 1.0));
    final orbitOpacity = (1 - p).clamp(0.0, 1.0);

    if (orbitOpacity > 0) {
      const count = 6;
      for (var i = 0; i < count; i++) {
        final point = _orbitalPoint(size, i, phase: phase + p * 0.12);
        canvas.drawCircle(
          Offset.lerp(point, center, p * 0.72)!,
          1.2 * orbitOpacity,
          _fillPaint(color, 0.36 * orbitOpacity),
        );
      }
      canvas.drawCircle(center, 2.4 + p * 1.2, _fillPaint(color, 0.3));
    }

    final ringProgress =
        Curves.easeOutCubic.transform((p / 0.58).clamp(0.0, 1.0));
    final checkProgress =
        Curves.easeOutCubic.transform(((p - 0.28) / 0.72).clamp(0.0, 1.0));
    final paint = _strokePaint(color)
      ..strokeWidth = 1.9
      ..color = color.withValues(alpha: p.clamp(0.0, 1.0));

    canvas.drawArc(
      (Offset.zero & size).deflate(2.8),
      -math.pi / 2,
      math.pi * 2 * ringProgress,
      false,
      paint,
    );

    if (checkProgress > 0) {
      final metric = _checkPath(center).computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkProgress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RefreshGlyphPainter oldDelegate) {
    return status != oldDelegate.status ||
        progress != oldDelegate.progress ||
        phase != oldDelegate.phase ||
        completion != oldDelegate.completion ||
        color != oldDelegate.color;
  }
}

enum _UiRefreshIndicatorMode { inactive, drag, armed, refresh, done }

typedef _UiSliverIndicatorBuilder = Widget Function(
  BuildContext context,
  _UiRefreshIndicatorMode mode,
  double pulledExtent,
  double triggerDistance,
  double indicatorExtent,
);

/// Widgets-layer sliver refresh mechanism used by [UiSliverRefresher].
class _UiSliverRefreshControl extends StatefulWidget {
  const _UiSliverRefreshControl({
    required this.refreshTriggerPullDistance,
    required this.refreshIndicatorExtent,
    required this.onRefresh,
    required this.builder,
  });

  final double refreshTriggerPullDistance;
  final double refreshIndicatorExtent;
  final Future<void> Function() onRefresh;
  final _UiSliverIndicatorBuilder builder;

  @override
  State<_UiSliverRefreshControl> createState() =>
      _UiSliverRefreshControlState();
}

class _UiSliverRefreshControlState extends State<_UiSliverRefreshControl> {
  static const _inactiveResetFraction = 0.1;

  _UiRefreshIndicatorMode _mode = _UiRefreshIndicatorMode.inactive;
  Future<void>? _refreshTask;
  double _extent = 0;
  bool _holdsLayoutExtent = false;

  _UiRefreshIndicatorMode _transition() {
    void releaseExtent() {
      void update() {
        if (mounted) setState(() => _holdsLayoutExtent = false);
      }

      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        update();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) => update());
      }
    }

    switch (_mode) {
      case _UiRefreshIndicatorMode.inactive:
        if (_extent <= 0) return _UiRefreshIndicatorMode.inactive;
        _mode = _UiRefreshIndicatorMode.drag;
        return _transition();
      case _UiRefreshIndicatorMode.drag:
        if (_extent <= 0) return _UiRefreshIndicatorMode.inactive;
        if (_extent < widget.refreshTriggerPullDistance) {
          return _UiRefreshIndicatorMode.drag;
        }
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _refreshTask != null) return;
          setState(() => _holdsLayoutExtent = true);
          _refreshTask = widget.onRefresh();
          _refreshTask!.whenComplete(() {
            if (!mounted) return;
            setState(() {
              _refreshTask = null;
              _mode = _transition();
            });
          });
        });
        return _UiRefreshIndicatorMode.armed;
      case _UiRefreshIndicatorMode.armed:
        if (_refreshTask == null) {
          releaseExtent();
          _mode = _UiRefreshIndicatorMode.done;
          return _transition();
        }
        return _extent > widget.refreshIndicatorExtent
            ? _UiRefreshIndicatorMode.armed
            : _UiRefreshIndicatorMode.refresh;
      case _UiRefreshIndicatorMode.refresh:
        if (_refreshTask != null) return _UiRefreshIndicatorMode.refresh;
        releaseExtent();
        _mode = _UiRefreshIndicatorMode.done;
        return _transition();
      case _UiRefreshIndicatorMode.done:
        return _extent >
                widget.refreshTriggerPullDistance * _inactiveResetFraction
            ? _UiRefreshIndicatorMode.done
            : _UiRefreshIndicatorMode.inactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _UiRefreshSliver(
      refreshIndicatorLayoutExtent: widget.refreshIndicatorExtent,
      hasLayoutExtent: _holdsLayoutExtent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _extent = constraints.maxHeight;
          _mode = _transition();
          if (_extent <= 0) return const SizedBox.shrink();
          return widget.builder(
            context,
            _mode,
            _extent,
            widget.refreshTriggerPullDistance,
            widget.refreshIndicatorExtent,
          );
        },
      ),
    );
  }
}

class _UiRefreshSliver extends SingleChildRenderObjectWidget {
  const _UiRefreshSliver({
    required this.refreshIndicatorLayoutExtent,
    required this.hasLayoutExtent,
    required super.child,
  });

  final double refreshIndicatorLayoutExtent;
  final bool hasLayoutExtent;

  @override
  _RenderUiRefreshSliver createRenderObject(BuildContext context) =>
      _RenderUiRefreshSliver(
        refreshIndicatorExtent: refreshIndicatorLayoutExtent,
        hasLayoutExtent: hasLayoutExtent,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderUiRefreshSliver renderObject,
  ) {
    renderObject
      ..refreshIndicatorLayoutExtent = refreshIndicatorLayoutExtent
      ..hasLayoutExtent = hasLayoutExtent;
  }
}

class _RenderUiRefreshSliver extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderUiRefreshSliver({
    required double refreshIndicatorExtent,
    required bool hasLayoutExtent,
  })  : _refreshIndicatorExtent = refreshIndicatorExtent,
        _hasLayoutExtent = hasLayoutExtent;

  double _refreshIndicatorExtent;
  double get refreshIndicatorLayoutExtent => _refreshIndicatorExtent;
  set refreshIndicatorLayoutExtent(double value) {
    if (value == _refreshIndicatorExtent) return;
    _refreshIndicatorExtent = value;
    markNeedsLayout();
  }

  bool _hasLayoutExtent;
  bool get hasLayoutExtent => _hasLayoutExtent;
  set hasLayoutExtent(bool value) {
    if (value == _hasLayoutExtent) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  double _layoutExtentCompensation = 0;

  @override
  void performLayout() {
    final layoutExtent = _hasLayoutExtent ? _refreshIndicatorExtent : 0.0;
    if (layoutExtent != _layoutExtentCompensation) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: layoutExtent - _layoutExtentCompensation,
      );
      _layoutExtentCompensation = layoutExtent;
      return;
    }

    final overscroll = constraints.overlap < 0 ? -constraints.overlap : 0.0;
    final active = overscroll > 0 || layoutExtent > 0;
    child!.layout(
      constraints.asBoxConstraints(maxExtent: layoutExtent + overscroll),
      parentUsesSize: true,
    );
    if (!active) {
      geometry = SliverGeometry.zero;
      return;
    }
    final extent = math.max(child!.size.height, layoutExtent);
    geometry = SliverGeometry(
      scrollExtent: layoutExtent,
      paintOrigin: -overscroll - constraints.scrollOffset,
      paintExtent: math.max(extent - constraints.scrollOffset, 0),
      maxPaintExtent: math.max(extent - constraints.scrollOffset, 0),
      layoutExtent: math.max(layoutExtent - constraints.scrollOffset, 0),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (constraints.overlap < 0 ||
        constraints.scrollOffset + child!.size.height > 0) {
      context.paintChild(child!, offset);
    }
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}
