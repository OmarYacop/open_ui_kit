import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/ui_theme_extensions.dart';

typedef UiNowProvider = DateTime Function();

enum UiClockTickMode {
  manual,
  second,
  minute,
}

enum UiTimeGateTransition {
  none,
  fade,
  fadeScale,
}

class UiClockController extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<DateTime> {
  UiClockController({
    UiNowProvider? nowProvider,
    UiClockTickMode tickMode = UiClockTickMode.minute,
    Duration? tickInterval,
    DateTime? initialNow,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        _tickMode = tickMode,
        _tickInterval = tickInterval,
        _now = initialNow ?? (nowProvider ?? DateTime.now)() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleNext();
  }

  final UiNowProvider _nowProvider;
  UiClockTickMode _tickMode;
  Duration? _tickInterval;
  DateTime _now;
  Timer? _timer;
  bool _disposed = false;
  final Map<Object, Set<DateTime>> _watchTimes = <Object, Set<DateTime>>{};

  @override
  DateTime get value => _now;

  DateTime get now => _now;

  UiClockTickMode get tickMode => _tickMode;

  void configure({
    UiClockTickMode? tickMode,
    Duration? tickInterval,
  }) {
    var changed = false;
    if (tickMode != null && tickMode != _tickMode) {
      _tickMode = tickMode;
      changed = true;
    }
    if (tickInterval != _tickInterval) {
      _tickInterval = tickInterval;
      changed = true;
    }
    if (!changed) return;
    _scheduleNext();
  }

  void refresh() {
    if (_disposed) return;
    final next = _nowProvider();
    if (_sameMoment(next, _now)) {
      _scheduleNext();
      return;
    }
    _now = next;
    notifyListeners();
    _scheduleNext();
  }

  @visibleForTesting
  void setNow(DateTime value) {
    if (_disposed || _sameMoment(value, _now)) return;
    _now = value;
    notifyListeners();
    _scheduleNext();
  }

  void registerWatchTimes(Object owner, Iterable<DateTime> times) {
    if (_disposed) return;
    final next = times.where((time) => time.isAfter(_now)).toSet();
    if (next.isEmpty) {
      unregisterWatchTimes(owner);
      return;
    }
    _watchTimes[owner] = next;
    _scheduleNext();
  }

  void unregisterWatchTimes(Object owner) {
    if (_watchTimes.remove(owner) == null) return;
    _scheduleNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchTimes.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        refresh();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _timer?.cancel();
        return;
    }
  }

  void _scheduleNext() {
    if (_disposed) return;
    _timer?.cancel();
    final delay = _nextDelay();
    if (delay == null) return;
    _timer = Timer(delay, refresh);
  }

  Duration? _nextDelay() {
    final candidates = <DateTime>[];
    final nextTick = _nextTickTime(_now);
    if (nextTick != null) candidates.add(nextTick);
    for (final times in _watchTimes.values) {
      for (final time in times) {
        if (time.isAfter(_now)) candidates.add(time);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort();
    final delay = candidates.first.difference(_now);
    if (!delay.isNegative && delay > Duration.zero) return delay;
    return const Duration(milliseconds: 16);
  }

  DateTime? _nextTickTime(DateTime from) {
    final custom = _tickInterval;
    if (custom != null) return from.add(custom);
    return switch (_tickMode) {
      UiClockTickMode.manual => null,
      UiClockTickMode.second => DateTime(
          from.year,
          from.month,
          from.day,
          from.hour,
          from.minute,
          from.second + 1,
        ),
      UiClockTickMode.minute => DateTime(
          from.year,
          from.month,
          from.day,
          from.hour,
          from.minute + 1,
        ),
    };
  }

  bool _sameMoment(DateTime left, DateTime right) =>
      left.microsecondsSinceEpoch == right.microsecondsSinceEpoch;
}

class UiClockScope extends StatefulWidget {
  const UiClockScope({
    super.key,
    required this.child,
    this.controller,
    this.tickMode = UiClockTickMode.minute,
    this.tickInterval,
    this.nowProvider,
  });

  final Widget child;
  final UiClockController? controller;
  final UiClockTickMode tickMode;
  final Duration? tickInterval;
  final UiNowProvider? nowProvider;

  static UiClockController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_UiClockInherited>();
    return scope?.controller ?? _UiClockFallback.instance;
  }

  static UiClockController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_UiClockInherited>()
        ?.controller;
  }

  @override
  State<UiClockScope> createState() => _UiClockScopeState();
}

class _UiClockScopeState extends State<UiClockScope> {
  UiClockController? _owned;

  UiClockController get _controller =>
      widget.controller ??
      (_owned ??= UiClockController(
        nowProvider: widget.nowProvider,
        tickMode: widget.tickMode,
        tickInterval: widget.tickInterval,
      ));

  @override
  void didUpdateWidget(UiClockScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _owned?.dispose();
      _owned = null;
    }
    _controller.configure(
      tickMode: widget.tickMode,
      tickInterval: widget.tickInterval,
    );
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _UiClockInherited(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _UiClockInherited extends InheritedNotifier<UiClockController> {
  const _UiClockInherited({
    required UiClockController controller,
    required super.child,
  })  : controller = controller,
        super(notifier: controller);

  final UiClockController controller;
}

class _UiClockFallback {
  static final UiClockController instance = UiClockController(
    tickMode: UiClockTickMode.manual,
  );
}

class UiNowBuilder extends StatefulWidget {
  const UiNowBuilder({
    super.key,
    required this.builder,
    this.controller,
    this.watchTimes = const [],
  });

  final UiClockController? controller;
  final Iterable<DateTime> watchTimes;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<UiNowBuilder> createState() => _UiNowBuilderState();
}

class _UiNowBuilderState extends State<UiNowBuilder> {
  UiClockController? _controller;
  final Object _watchOwner = Object();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(UiNowBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(forceWatchSync: true);
  }

  @override
  void dispose() {
    _controller?.unregisterWatchTimes(_watchOwner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller ?? UiClockScope.of(context);
    return ValueListenableBuilder<DateTime>(
      valueListenable: controller,
      builder: (context, now, _) => widget.builder(context, now),
    );
  }

  void _syncController({bool forceWatchSync = false}) {
    final next = widget.controller ?? UiClockScope.of(context);
    if (!identical(next, _controller)) {
      _controller?.unregisterWatchTimes(_watchOwner);
      _controller = next;
      forceWatchSync = true;
    }
    if (forceWatchSync) {
      _controller?.registerWatchTimes(_watchOwner, widget.watchTimes);
    }
  }
}

class UiTimeGate extends StatelessWidget {
  const UiTimeGate({
    super.key,
    required this.builder,
    this.placeholder,
    this.visibleFrom,
    this.visibleUntil,
    this.controller,
    this.transition = UiTimeGateTransition.fadeScale,
    this.duration,
  });

  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
  final UiClockController? controller;
  final WidgetBuilder builder;
  final WidgetBuilder? placeholder;
  final UiTimeGateTransition transition;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return UiNowBuilder(
      controller: controller,
      watchTimes: [
        if (visibleFrom != null) visibleFrom!,
        if (visibleUntil != null) visibleUntil!,
      ],
      builder: (context, now) {
        final visible = (visibleFrom == null || !now.isBefore(visibleFrom!)) &&
            (visibleUntil == null || now.isBefore(visibleUntil!));
        final child = KeyedSubtree(
          key: ValueKey<bool>(visible),
          child: visible
              ? builder(context)
              : placeholder?.call(context) ?? const SizedBox.shrink(),
        );
        return switch (transition) {
          UiTimeGateTransition.none => child,
          UiTimeGateTransition.fade => AnimatedSwitcher(
              duration: duration ?? UiThemeTokens.of(context).motion.fast,
              child: child,
            ),
          UiTimeGateTransition.fadeScale => AnimatedSwitcher(
              duration: duration ?? UiThemeTokens.of(context).motion.fast,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: child,
            ),
        };
      },
    );
  }
}
