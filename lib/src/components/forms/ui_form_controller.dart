import 'dart:async';

import 'package:flutter/widgets.dart';

import 'ui_form_submit_controller.dart';

typedef UiFieldValidator<T> = String? Function(T value);
typedef UiAsyncFieldValidator<T> = Future<String?> Function(T value);

/// State owned by [UiFormController] for one typed field.
/// Values should be immutable; use a new collection when changing selections.
class UiFormFieldController<T> extends ChangeNotifier {
  UiFormFieldController._(
    this.name,
    this.label,
    T initialValue,
    this._validator,
    this._asyncValidator,
    FocusNode? focusNode,
  ) : _value = initialValue,
      _baseline = initialValue,
      focusNode = focusNode ?? FocusNode(),
      _ownsFocus = focusNode == null {
    _error = _validator?.call(_value);
  }

  final String name;
  final String label;
  final FocusNode focusNode;
  final bool _ownsFocus;
  final UiFieldValidator<T>? _validator;
  final UiAsyncFieldValidator<T>? _asyncValidator;
  T _value;
  T _baseline;
  String? _error;
  bool _touched = false;
  bool _validating = false;
  bool _disposed = false;
  int _revision = 0;

  T get value => _value;
  String? get error => _error;
  String? get visibleError => _touched ? _error : null;
  bool get touched => _touched;
  bool get isValidating => _validating;
  bool get isValid => _error == null && !_validating;
  bool get isDirty => _value != _baseline;

  /// Invalidates in-flight validation; stale results never overwrite new input.
  void setValue(T value) {
    if (_disposed || value == _value) return;
    _revision++;
    _value = value;
    _validating = false;
    _error = _validator?.call(value);
    notifyListeners();
  }

  void markTouched() {
    if (_disposed || _touched) return;
    _touched = true;
    notifyListeners();
  }

  /// Validator exceptions propagate to the caller; pending state always clears.
  Future<bool> validate() async {
    if (_disposed) return false;
    final revision = ++_revision;
    _touched = true;
    _error = _validator?.call(_value);
    _validating = _error == null && _asyncValidator != null;
    notifyListeners();
    if (!_validating) return _error == null;
    try {
      final result = await _asyncValidator!(_value);
      if (_disposed || revision != _revision) return false;
      _error = result;
      return result == null;
    } finally {
      if (!_disposed && revision == _revision) {
        _validating = false;
        notifyListeners();
      }
    }
  }

  void _markClean() {
    _baseline = _value;
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    _revision++;
    _value = _baseline;
    _touched = false;
    _validating = false;
    _error = _validator?.call(_value);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    if (_ownsFocus) focusNode.dispose();
    super.dispose();
  }
}

/// Coordinates field validation and submission over [UiFormSubmitController].
///
/// Register fields once, bind controls to their value and focus node, and dispose
/// this controller with the form. Field controllers are owned here; externally
/// supplied focus nodes and text controllers remain application-owned.
class UiFormController extends ChangeNotifier {
  final UiFormSubmitController _gate = UiFormSubmitController();
  final Map<String, UiFormFieldController<dynamic>> _fields = {};
  final Map<String, VoidCallback> _listeners = {};
  bool _submitting = false;
  bool _disposed = false;
  bool _batching = false;
  int _structureRevision = 0;

  Iterable<UiFormFieldController<dynamic>> get fields =>
      List.unmodifiable(_fields.values);
  Map<String, Object?> get values => Map.unmodifiable({
    for (final field in _fields.values) field.name: field.value,
  });
  Map<String, String> get errors => Map.unmodifiable({
    for (final field in _fields.values)
      if (field.visibleError != null) field.name: field.visibleError!,
  });
  bool get isDirty => _gate.isDirty;
  bool get isValid => _fields.values.every((field) => field.isValid);
  bool get isValidating => _fields.values.any((field) => field.isValidating);
  bool get isSubmitting => _submitting;
  bool get canSubmit => !_submitting && !isValidating && _gate.canSubmit;

  UiFormFieldController<T> registerField<T>(
    String name, {
    required T initialValue,
    String? label,
    UiFieldValidator<T>? validator,
    UiAsyncFieldValidator<T>? asyncValidator,
    FocusNode? focusNode,
  }) {
    if (_disposed) throw StateError('The form has been disposed.');
    if (_fields.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'Already registered');
    }
    final field = UiFormFieldController<T>._(
      name,
      label ?? name,
      initialValue,
      validator,
      asyncValidator,
      focusNode,
    );
    _fields[name] = field;
    _structureRevision++;
    void listener() => _sync();
    _listeners[name] = listener;
    field.addListener(listener);
    _rebuildGate();
    _sync();
    return field;
  }

  void unregisterField(String name) {
    final field = _fields.remove(name);
    if (field == null) return;
    _structureRevision++;
    field.removeListener(_listeners.remove(name)!);
    field.dispose();
    _rebuildGate();
    _sync();
  }

  void _rebuildGate() {
    _gate.reset({
      for (final field in _fields.values) field.name: field._baseline,
    });
    for (final field in _fields.values) {
      _gate.setValue(field.name, field.value);
    }
  }

  void _sync() {
    if (_disposed || _batching) return;
    for (final field in _fields.values) {
      _gate.setValue(field.name, field.value);
    }
    _gate.setValid(isValid);
    notifyListeners();
  }

  /// Touch and validate all fields. Concurrent edits make this attempt invalid.
  Future<bool> validate({bool focusFirstInvalid = true}) async {
    if (_disposed) return false;
    final structure = _structureRevision;
    final snapshot = List.of(_fields.values);
    final expectedRevisions = {
      for (final field in snapshot) field.name: field._revision + 1,
    };
    final results = await Future.wait(
      snapshot.map((field) => field.validate()),
    );
    final valid =
        !_disposed &&
        structure == _structureRevision &&
        results.every((value) => value) &&
        snapshot.every(
          (field) => expectedRevisions[field.name] == field._revision,
        ) &&
        isValid;
    if (!valid && !_disposed && focusFirstInvalid) this.focusFirstInvalid();
    return valid;
  }

  void focusFirstInvalid() {
    for (final field in _fields.values) {
      if (field.error != null) {
        field.focusNode.requestFocus();
        return;
      }
    }
  }

  /// Returns false for duplicate submits, unchanged forms, or failed validation.
  /// Changes made while saving remain dirty; a successful save never erases them.
  /// Application callback and validator exceptions are propagated to the caller.
  Future<bool> submit(
    Future<void> Function(Map<String, Object?> values) onSubmit, {
    bool requireDirty = true,
  }) async {
    if (_disposed || _submitting || (requireDirty && !isDirty)) return false;
    _submitting = true;
    notifyListeners();
    try {
      if (!await validate()) return false;
      final snapshot = values;
      final revisions = {
        for (final field in _fields.values) field.name: field._revision,
      };
      final structure = _structureRevision;
      await onSubmit(snapshot);
      if (!_disposed &&
          structure == _structureRevision &&
          _fields.values.every(
            (field) => revisions[field.name] == field._revision,
          )) {
        markClean();
      }
      return true;
    } finally {
      if (!_disposed) {
        _submitting = false;
        notifyListeners();
      }
    }
  }

  void markClean() {
    _batching = true;
    for (final field in _fields.values) {
      field._markClean();
    }
    _batching = false;
    _gate.markClean();
    _sync();
  }

  void reset() {
    _batching = true;
    for (final field in _fields.values) {
      field.reset();
    }
    _batching = false;
    _rebuildGate();
    _sync();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final field in _fields.values) {
      field.removeListener(_listeners[field.name]!);
      field.dispose();
    }
    _fields.clear();
    _gate.dispose();
    super.dispose();
  }
}
