import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef UiStateUpdater<TState> = TState Function(TState state);
typedef UiStateSelector<TState, TSlice> = TSlice Function(TState state);
typedef UiSelectorShouldRebuild<TSlice> = bool Function(
  TSlice previous,
  TSlice next,
);
typedef UiSelectedStateBuilder<TSlice> = Widget Function(
  BuildContext context,
  TSlice value,
  Widget? child,
);

/// Small generic state container for Open UI Kit patterns.
///
/// It intentionally owns only reactive mechanics. Feature code should keep
/// API calls, resource semantics, and domain side effects outside the UI kit.
class UiStore<TState> extends ChangeNotifier
    implements ValueListenable<TState> {
  UiStore(TState initialState) : _state = initialState;

  TState _state;

  TState get state => _state;

  @override
  TState get value => _state;

  void setState(TState nextState) {
    if (identical(_state, nextState) || _state == nextState) return;
    _state = nextState;
    notifyListeners();
  }

  void update(UiStateUpdater<TState> updater) {
    setState(updater(_state));
  }

  TSlice select<TSlice>(UiStateSelector<TState, TSlice> selector) {
    return selector(_state);
  }
}

/// Exposes a [UiStore] to descendants without coupling them to app state tools.
class UiStoreScope<TState> extends InheritedNotifier<UiStore<TState>> {
  const UiStoreScope({
    super.key,
    required UiStore<TState> store,
    required super.child,
  }) : super(notifier: store);

  static UiStore<TState>? maybeOf<TState>(
    BuildContext context, {
    bool listen = true,
  }) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<UiStoreScope<TState>>()
        : context.getInheritedWidgetOfExactType<UiStoreScope<TState>>();
    return scope?.notifier;
  }

  static UiStore<TState> of<TState>(
    BuildContext context, {
    bool listen = true,
  }) {
    final store = maybeOf<TState>(context, listen: listen);
    if (store == null) {
      throw FlutterError(
        'UiStoreScope<$TState> was not found in this context. '
        'Wrap the subtree in UiStoreScope<$TState> or pass a store directly.',
      );
    }
    return store;
  }

  static TState stateOf<TState>(
    BuildContext context, {
    bool listen = true,
  }) {
    return of<TState>(context, listen: listen).state;
  }
}

/// Rebuilds only when the selected slice changes.
class UiSelector<TState, TSlice> extends StatefulWidget {
  const UiSelector({
    super.key,
    this.store,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
    this.child,
  });

  final UiStore<TState>? store;
  final UiStateSelector<TState, TSlice> selector;
  final UiSelectedStateBuilder<TSlice> builder;
  final UiSelectorShouldRebuild<TSlice>? shouldRebuild;
  final Widget? child;

  @override
  State<UiSelector<TState, TSlice>> createState() =>
      _UiSelectorState<TState, TSlice>();
}

class _UiSelectorState<TState, TSlice>
    extends State<UiSelector<TState, TSlice>> {
  UiStore<TState>? _store;
  late TSlice _selected;
  bool _hasSelected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(widget.store ?? UiStoreScope.of<TState>(context, listen: false));
  }

  @override
  void didUpdateWidget(UiSelector<TState, TSlice> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextStore =
        widget.store ?? UiStoreScope.of<TState>(context, listen: false);
    if (!identical(_store, nextStore)) {
      _attach(nextStore);
      return;
    }
    _syncSelected();
  }

  @override
  void dispose() {
    _store?.removeListener(_handleStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _selected, widget.child);
  }

  void _attach(UiStore<TState> store) {
    if (identical(_store, store)) return;
    _store?.removeListener(_handleStoreChanged);
    _store = store;
    _selected = widget.selector(store.state);
    _hasSelected = true;
    store.addListener(_handleStoreChanged);
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    _syncSelected();
  }

  void _syncSelected() {
    final store = _store;
    if (store == null) return;

    final next = widget.selector(store.state);
    if (_hasSelected && !_shouldRebuild(_selected, next)) return;

    setState(() {
      _selected = next;
      _hasSelected = true;
    });
  }

  bool _shouldRebuild(TSlice previous, TSlice next) {
    final custom = widget.shouldRebuild;
    if (custom != null) return custom(previous, next);
    return !(identical(previous, next) || previous == next);
  }
}
