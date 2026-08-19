import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A [PageRoute] mixin that adds iOS-style interactive edge-swipe-to-go-back
/// support to a route while leaving the visual page transition entirely up
/// to the mixing class's own [ModalRoute.buildTransitions] override.
///
/// This is deliberately independent from Flutter's
/// `CupertinoRouteTransitionMixin` (which bundles the gesture together with
/// the iOS slide transition): the gesture is wanted, but the visuals should
/// stay whatever [UiNavigationTransition] style the route already uses —
/// there's no reason an interactive drag should look like a different
/// transition than a tap-triggered pop of the same route.
///
/// The mechanism is simpler than it might look: dragging directly moves the
/// route's own [ModalRoute.controller] value, the exact `Animation<double>`
/// that already drives [ModalRoute.buildTransitions] for a normal push/pop.
/// So the interactive drag *is* the same transition, frame for frame — not
/// a separately-tracked progress value driving a hand-built preview. It
/// also means Flutter's own `Navigator`/`Overlay` machinery paints both
/// routes correctly while the gesture is active, the same as any other
/// in-flight transition; nothing needs to be snapshotted or recomposited
/// by hand to reveal the page underneath.
///
/// The gesture is only attached on iOS ([defaultTargetPlatform]); other
/// platforms (Android predictive back, desktop, web) are unaffected.
mixin UiCupertinoBackGestureMixin<T> on PageRoute<T> {
  /// Wraps [child] with the iOS edge-swipe-back gesture area, when enabled
  /// for the current platform and route state.
  ///
  /// Call this from [buildTransitions] around the already-transitioned
  /// child:
  /// ```dart
  /// Widget buildTransitions(...) {
  ///   final transitioned = MyCustomTransition(animation: animation, child: child);
  ///   return wrapWithBackGesture(context, transitioned);
  /// }
  /// ```
  @protected
  Widget wrapWithBackGesture(BuildContext context, Widget child) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return child;
    }
    return _UiCupertinoBackGestureDetector<T>(
      enabledCallback: () => popGestureEnabled,
      onStartPopGesture: () => _UiCupertinoBackGestureController<T>(
        navigator: navigator!,
        controller: controller!,
        getIsActive: () => isActive,
        getIsCurrent: () => isCurrent,
      ),
      child: child,
    );
  }
}

/// Detects an edge drag near the leading (start) screen edge and starts an
/// iOS-style interactive pop gesture.
///
/// This mirrors `_CupertinoBackGestureDetector` from the Flutter SDK
/// (`flutter/lib/src/cupertino/route.dart`), reimplemented here because
/// that class is private and specific to `CupertinoPageTransition`. It only
/// relies on public [PageRoute] / [NavigatorState] / [AnimationController]
/// API, so it can be layered on top of any custom page transition.
class _UiCupertinoBackGestureDetector<T> extends StatefulWidget {
  const _UiCupertinoBackGestureDetector({
    super.key,
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_UiCupertinoBackGestureController<T>> onStartPopGesture;

  @override
  State<_UiCupertinoBackGestureDetector<T>> createState() =>
      _UiCupertinoBackGestureDetectorState<T>();
}

class _UiCupertinoBackGestureDetectorState<T>
    extends State<_UiCupertinoBackGestureDetector<T>> {
  _UiCupertinoBackGestureController<T>? _backGestureController;

  late HorizontalDragGestureRecognizer _recognizer;

  static const double _kBackGestureWidth = 20.0;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_backGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_backGestureController?.navigator.mounted ?? false) {
          _backGestureController?.navigator.didStopUserGesture();
        }
        _backGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(_backGestureController == null);
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(_backGestureController != null);
    _backGestureController!.dragUpdate(
      _convertToLogical(details.primaryDelta! / context.size!.width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(_backGestureController != null);
    _backGestureController!.dragEnd(
      _convertToLogical(
        details.velocity.pixelsPerSecond.dx / context.size!.width,
      ),
    );
    _backGestureController = null;
  }

  void _handleDragCancel() {
    _backGestureController?.dragEnd(0.0);
    _backGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  double _convertToLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final double dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0.0,
          width: math.max(dragAreaWidth, _kBackGestureWidth),
          top: 0.0,
          bottom: 0.0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

/// Drives the route's [AnimationController] in response to drag events from
/// [_UiCupertinoBackGestureDetector].
///
/// Mirrors `_CupertinoBackGestureController` from the Flutter SDK.
class _UiCupertinoBackGestureController<T> {
  _UiCupertinoBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  static const double _kMinFlingVelocity = 1.0;
  static const Duration _kDroppedSwipePageAnimationDuration = Duration(
    milliseconds: 350,
  );

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.fastEaseInToSlowEaseOut;
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kDroppedSwipePageAnimationDuration,
        curve: animationCurve,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _kDroppedSwipePageAnimationDuration,
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
