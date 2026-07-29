import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _keyboardGeometryChannel = EventChannel(
  'dev.open_ui_kit/keyboard_geometry',
);
const _iosKeyboardDurationFactor = 0.65;

enum UiKeyboardAnimationCurve {
  platform,
  easeInOut,
  easeIn,
  easeOut,
  linear,
}

/// Independently tracked parts of [UiKeyboardGeometry].
enum UiKeyboardGeometryAspect {
  currentInset,
  reservedInset,
  followerTranslation,
  visibility,
  animation,
}

@immutable
class UiKeyboardGeometry {
  const UiKeyboardGeometry({
    this.currentInset = 0,
    this.sourceInset = 0,
    this.targetInset = 0,
    this.progress = 1,
    this.duration = Duration.zero,
    this.curve = UiKeyboardAnimationCurve.platform,
    this.isAnimating = false,
    this.isVisible = false,
  });

  final double currentInset;
  final double sourceInset;
  final double targetInset;
  final double progress;
  final Duration duration;
  final UiKeyboardAnimationCurve curve;
  final bool isAnimating;
  final bool isVisible;

  /// Height held by stable keyboard-aware layouts while an IME transition is
  /// running. Reserving the larger endpoint prevents per-frame relayout.
  double get reservedInset =>
      isAnimating ? math.max(sourceInset, targetInset) : currentInset;

  double get followerTranslation => reservedInset - currentInset;

  static UiKeyboardGeometry of(BuildContext context) {
    return _maybeOf(context) ?? _fallbackOf(context);
  }

  static double currentInsetOf(BuildContext context) =>
      (_maybeOf(context, UiKeyboardGeometryAspect.currentInset) ??
              _fallbackOf(context))
          .currentInset;

  static double reservedInsetOf(BuildContext context) =>
      (_maybeOf(context, UiKeyboardGeometryAspect.reservedInset) ??
              _fallbackOf(context))
          .reservedInset;

  static double followerTranslationOf(BuildContext context) =>
      (_maybeOf(context, UiKeyboardGeometryAspect.followerTranslation) ??
              _fallbackOf(context))
          .followerTranslation;

  static bool isVisibleOf(BuildContext context) =>
      (_maybeOf(context, UiKeyboardGeometryAspect.visibility) ??
              _fallbackOf(context))
          .isVisible;

  static UiKeyboardGeometry animationOf(BuildContext context) =>
      _maybeOf(context, UiKeyboardGeometryAspect.animation) ??
      _fallbackOf(context);

  static UiKeyboardGeometry? _maybeOf(
    BuildContext context, [
    UiKeyboardGeometryAspect? aspect,
  ]) {
    return InheritedModel.inheritFrom<_UiKeyboardGeometryData>(
      context,
      aspect: aspect,
    )?.geometry;
  }

  static UiKeyboardGeometry _fallbackOf(BuildContext context) {
    final inset = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
    return UiKeyboardGeometry(
      currentInset: inset,
      sourceInset: inset,
      targetInset: inset,
      isVisible: inset > 0,
    );
  }
}

/// App-level host for native keyboard geometry.
///
/// Android supplies frame-by-frame IME insets. iOS supplies UIKit's source,
/// target, duration, and curve; this host interpolates those values with a
/// vsynced controller. Window metrics remain the fallback on unsupported
/// platforms and in tests.
class UiKeyboardGeometryScope extends StatefulWidget {
  const UiKeyboardGeometryScope({
    super.key,
    required this.child,
    this.eventStream,
    this.reduceMotionOverride,
  });

  final Widget child;
  final Stream<dynamic>? eventStream;
  final bool? reduceMotionOverride;

  @override
  State<UiKeyboardGeometryScope> createState() =>
      _UiKeyboardGeometryScopeState();
}

/// Overrides keyboard geometry for previews, tests, and embedded platform
/// surfaces that already own an IME integration.
class UiKeyboardGeometryOverride extends StatelessWidget {
  const UiKeyboardGeometryOverride({
    super.key,
    required this.geometry,
    required this.child,
  });

  final UiKeyboardGeometry geometry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _UiKeyboardGeometryData(geometry: geometry, child: child);
  }
}

class _UiKeyboardGeometryScopeState extends State<UiKeyboardGeometryScope>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_handleAnimationTick)
    ..addStatusListener(_handleAnimationStatus);
  StreamSubscription<dynamic>? _nativeSubscription;
  UiKeyboardGeometry _geometry = const UiKeyboardGeometry();
  double _animationSource = 0;
  double _animationTarget = 0;
  bool _nativeAnimationActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readWindowMetrics();
    _nativeSubscription = (widget.eventStream ??
            _keyboardGeometryChannel.receiveBroadcastStream())
        .listen(_handleNativeEvent, onError: (_) {});
  }

  @override
  void didChangeMetrics() {
    if (!_nativeAnimationActive) _readWindowMetrics();
  }

  void _readWindowMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    if (!mounted) {
      _geometry = UiKeyboardGeometry(
        currentInset: inset,
        sourceInset: inset,
        targetInset: inset,
        isVisible: inset > 0,
      );
      return;
    }
    setState(() {
      _geometry = UiKeyboardGeometry(
        currentInset: inset,
        sourceInset: inset,
        targetInset: inset,
        isVisible: inset > 0,
      );
    });
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final values = Map<Object?, Object?>.from(event);
    final platform = values['platform']?.toString();
    final current = _number(values['currentInset'], _geometry.currentInset);
    final source = _number(values['sourceInset'], current);
    final target = _number(values['targetInset'], current);
    final progress = _number(values['progress'], 1).clamp(0.0, 1.0);
    final platformDuration = Duration(
      milliseconds: _number(values['durationMs'], 0).round(),
    );
    final duration = platform == 'ios'
        ? Duration(
            milliseconds:
                (platformDuration.inMilliseconds * _iosKeyboardDurationFactor)
                    .round(),
          )
        : platformDuration;
    final animating = values['isAnimating'] == true;
    final visible = values['isVisible'] == true || target > 0 || current > 0;
    final curve = _curve(values['curve']);
    final startedAtEpochMs = _number(values['startedAtEpochMs'], 0);
    final transitMs = startedAtEpochMs <= 0
        ? 0.0
        : math
            .max(
              0,
              DateTime.now().millisecondsSinceEpoch - startedAtEpochMs,
            )
            .toDouble();
    final reduceMotion = widget.reduceMotionOverride ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;

    if (platform == 'ios' &&
        animating &&
        duration > Duration.zero &&
        !reduceMotion) {
      _nativeAnimationActive = true;
      _animationSource = source;
      _animationTarget = target;
      final elapsedProgress =
          (progress + transitMs / duration.inMilliseconds).clamp(0.0, 1.0);
      _controller
        ..stop()
        ..duration = duration
        ..value = elapsedProgress;
      final visualProgress = _flutterCurve(curve).transform(elapsedProgress);
      _geometry = UiKeyboardGeometry(
        currentInset: source + (target - source) * visualProgress,
        sourceInset: source,
        targetInset: target,
        progress: elapsedProgress,
        duration: duration,
        curve: curve,
        isAnimating: true,
        isVisible: visible,
      );
      _controller.animateTo(
        1,
        curve: Curves.linear,
      );
      if (mounted) setState(() {});
      return;
    }

    _controller.stop();
    if (platform == 'ios') {
      _nativeAnimationActive = false;
      if (mounted) {
        setState(() {
          _geometry = UiKeyboardGeometry(
            currentInset: target,
            sourceInset: target,
            targetInset: target,
            isVisible: target > 0,
          );
        });
      }
      return;
    }

    _nativeAnimationActive = animating;
    if (mounted) {
      setState(() {
        _geometry = UiKeyboardGeometry(
          currentInset: current,
          sourceInset: source,
          targetInset: target,
          progress: progress,
          duration: duration,
          curve: curve,
          isAnimating: animating,
          isVisible: visible,
        );
      });
    }
  }

  void _handleAnimationTick() {
    if (!mounted || !_nativeAnimationActive) return;
    final rawProgress = _controller.value;
    final t = _flutterCurve(_geometry.curve).transform(rawProgress);
    setState(() {
      _geometry = UiKeyboardGeometry(
        currentInset:
            _animationSource + (_animationTarget - _animationSource) * t,
        sourceInset: _animationSource,
        targetInset: _animationTarget,
        progress: rawProgress,
        duration: _controller.duration ?? Duration.zero,
        curve: _geometry.curve,
        isAnimating: true,
        isVisible: _animationTarget > 0 || t < 1,
      );
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _nativeAnimationActive = false;
    setState(() {
      _geometry = UiKeyboardGeometry(
        currentInset: _animationTarget,
        sourceInset: _animationTarget,
        targetInset: _animationTarget,
        isVisible: _animationTarget > 0,
      );
    });
  }

  double _number(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  UiKeyboardAnimationCurve _curve(Object? value) {
    return switch (value?.toString()) {
      'easeInOut' => UiKeyboardAnimationCurve.easeInOut,
      'easeIn' => UiKeyboardAnimationCurve.easeIn,
      'easeOut' => UiKeyboardAnimationCurve.easeOut,
      'linear' => UiKeyboardAnimationCurve.linear,
      'keyboard' => UiKeyboardAnimationCurve.platform,
      _ => UiKeyboardAnimationCurve.platform,
    };
  }

  Curve _flutterCurve(UiKeyboardAnimationCurve curve) {
    return switch (curve) {
      UiKeyboardAnimationCurve.easeInOut => Curves.easeInOut,
      UiKeyboardAnimationCurve.easeIn => Curves.easeIn,
      UiKeyboardAnimationCurve.easeOut => Curves.easeOut,
      UiKeyboardAnimationCurve.linear => Curves.linear,
      UiKeyboardAnimationCurve.platform => Curves.ease,
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nativeSubscription?.cancel();
    _controller
      ..removeListener(_handleAnimationTick)
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UiKeyboardGeometryData(
      geometry: _geometry,
      child: widget.child,
    );
  }
}

class _UiKeyboardGeometryData extends InheritedModel<UiKeyboardGeometryAspect> {
  const _UiKeyboardGeometryData({
    required this.geometry,
    required super.child,
  });

  final UiKeyboardGeometry geometry;

  @override
  bool updateShouldNotify(_UiKeyboardGeometryData oldWidget) =>
      geometry != oldWidget.geometry;

  @override
  bool updateShouldNotifyDependent(
    _UiKeyboardGeometryData oldWidget,
    Set<UiKeyboardGeometryAspect> dependencies,
  ) {
    final old = oldWidget.geometry;
    return dependencies.any(
      (aspect) => switch (aspect) {
        UiKeyboardGeometryAspect.currentInset =>
          geometry.currentInset != old.currentInset,
        UiKeyboardGeometryAspect.reservedInset =>
          geometry.reservedInset != old.reservedInset,
        UiKeyboardGeometryAspect.followerTranslation =>
          geometry.followerTranslation != old.followerTranslation,
        UiKeyboardGeometryAspect.visibility =>
          geometry.isVisible != old.isVisible,
        UiKeyboardGeometryAspect.animation =>
          geometry.sourceInset != old.sourceInset ||
              geometry.targetInset != old.targetInset ||
              geometry.progress != old.progress ||
              geometry.duration != old.duration ||
              geometry.curve != old.curve ||
              geometry.isAnimating != old.isAnimating,
      },
    );
  }
}

/// Keeps [child] visually attached to the keyboard while holding the larger
/// endpoint as fixed layout space for the duration of the transition.
class UiKeyboardDock extends StatelessWidget {
  const UiKeyboardDock({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final followerTranslation =
        enabled ? UiKeyboardGeometry.followerTranslationOf(context) : 0.0;
    final reservedInset =
        enabled ? UiKeyboardGeometry.reservedInsetOf(context) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, followerTranslation),
          child: child,
        ),
        SizedBox(height: reservedInset),
      ],
    );
  }
}
