import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum UiMutationStatus { idle, pending, success, failure }

class UiMutationState {
  const UiMutationState({
    this.status = UiMutationStatus.idle,
    this.error,
    this.stackTrace,
  });

  final UiMutationStatus status;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isIdle => status == UiMutationStatus.idle;
  bool get isPending => status == UiMutationStatus.pending;
  bool get isSuccess => status == UiMutationStatus.success;
  bool get isFailure => status == UiMutationStatus.failure;

  UiMutationState copyWith({
    UiMutationStatus? status,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return UiMutationState(
      status: status ?? this.status,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UiMutationState &&
        other.status == status &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(status, error, stackTrace);
}

/// Tracks the lifecycle of a UI-triggered mutation.
class UiMutationController extends ChangeNotifier
    implements ValueListenable<UiMutationState> {
  UiMutationState _state = const UiMutationState();

  @override
  UiMutationState get value => _state;

  UiMutationState get state => _state;

  Future<T> run<T>(
    Future<T> Function() mutation, {
    bool allowConcurrent = false,
  }) async {
    if (_state.isPending && !allowConcurrent) {
      throw StateError('A mutation is already pending.');
    }

    _setState(const UiMutationState(status: UiMutationStatus.pending));

    try {
      final result = await mutation();
      _setState(const UiMutationState(status: UiMutationStatus.success));
      return result;
    } catch (error, stackTrace) {
      _setState(
        UiMutationState(
          status: UiMutationStatus.failure,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      rethrow;
    }
  }

  void reset() {
    _setState(const UiMutationState());
  }

  void _setState(UiMutationState nextState) {
    if (_state == nextState) return;
    _state = nextState;
    notifyListeners();
  }
}

typedef UiMutationWidgetBuilder = Widget Function(
  BuildContext context,
  UiMutationState state,
  Widget? child,
);

class UiMutationBuilder extends StatelessWidget {
  const UiMutationBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.child,
  });

  final UiMutationController controller;
  final UiMutationWidgetBuilder builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiMutationState>(
      valueListenable: controller,
      builder: builder,
      child: child,
    );
  }
}
