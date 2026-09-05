import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;

/// Validates a single form field's current text. Returns `null` when valid,
/// otherwise an error message — same shape as `UiInput.validator`, so
/// factories like an `emailField(msg)` helper work as either.
typedef UiFormFieldValidator = String? Function(String value);

/// A [TextEditingController]-backed field to track, with an optional
/// validator run on every edit.
///
/// Passed to [UiFormSubmitController.new] via `controllers` instead of a
/// bare `{field: controller}` map so a validator can travel alongside the
/// controller it applies to.
class UiFormControllerField {
  const UiFormControllerField(this.field, this.controller, {this.validator});

  /// Key this field is tracked under — matches what [setValue]/
  /// [UiFormSubmitController.isFieldDirty] would use for the same field.
  final String field;
  final TextEditingController controller;

  /// Runs on every edit; when it returns non-null, [UiFormSubmitController]
  /// reads as invalid until the text satisfies it again. Leave null for a
  /// field with no validation of its own (validity then depends only on
  /// [UiFormSubmitController.setValid] and any other bound field).
  final UiFormFieldValidator? validator;
}

/// Gates a form's submit button behind a single `canSubmit` signal, so a
/// button doesn't read as active before the form is actually ready.
///
/// [canSubmit] — also exposed as [value] so this can drive a
/// `ValueListenableBuilder` directly — is the AND of two things:
///
/// - **Dirty**: at least one tracked field differs from its baseline. On an
///   edit/update form the baseline is the record's persisted value, so this
///   reads naturally as "don't enable Save until something actually
///   changed." On a creation form (login, register, an empty report) the
///   baseline is just empty, so "dirty" collapses to "the user has started
///   filling this in" — still the right behavior (a blank form's submit
///   button shouldn't look active), just not literally about edits to a
///   record. [isDirty]/[isFieldDirty] describe this half.
/// - **Valid**: every bound [UiFormControllerField.validator] currently
///   passes, ANDed with whatever was last reported through [setValid] (for
///   cross-field checks or fields with no controller). [isValid] describes
///   this half; if a form should be submittable as soon as it's valid even
///   with no baseline to diff against (e.g. a confirm-with-prefilled-valid-
///   defaults action), read [isValid] directly instead of [canSubmit].
///
/// Text fields usually already own a [TextEditingController] seeded with the
/// field's current value — pass those straight into [controllers] and this
/// reads each one's current text as that field's baseline, keeps tracking
/// it, and runs its validator on every edit, instead of asking the caller to
/// restate the initial value separately and wire up its own listener to
/// recompute validity. The controllers stay entirely owned by the caller —
/// this class never creates, disposes, or otherwise controls them beyond
/// adding a listener; dispose them (and this controller) however you
/// normally would:
///
/// ```dart
/// final email = TextEditingController(text: actor.email);
/// late final submitGate = UiFormSubmitController(
///   controllers: [
///     UiFormControllerField('email', email, validator: emailField('Invalid email')),
///   ],
/// );
///
/// // ...
/// UiInput(controller: email, validator: emailField('Invalid email'));
///
/// ValueListenableBuilder<bool>(
///   valueListenable: submitGate,
///   builder: (context, canSubmit, _) => UiButton(
///     onPressed: canSubmit ? _save : null,
///     ...
///   ),
/// );
///
/// @override
/// void dispose() {
///   submitGate.dispose(); // before disposing any controller it's bound to
///   email.dispose();
///   super.dispose();
/// }
/// ```
///
/// Fields without a controller (switches, selects, image paths, …) still go
/// through [setValue] directly, and their validity — if any — through
/// [setValid]. [bindController]/[unbindController] cover binding a
/// controller after construction, e.g. one created later than the form
/// controller itself.
class UiFormSubmitController extends ChangeNotifier
    implements ValueListenable<bool> {
  UiFormSubmitController({
    Map<String, Object?> initialValues = const {},
    List<UiFormControllerField> controllers = const [],
  }) : _initial = Map.of(initialValues),
       _current = Map.of(initialValues) {
    _dirty = _computeDirty();
    _canSubmit = _dirty && isValid;
    for (final f in controllers) {
      bindController(f.field, f.controller, validator: f.validator);
    }
  }

  final Map<String, Object?> _initial;
  final Map<String, Object?> _current;
  final Map<String, TextEditingController> _boundControllers = {};
  final Map<String, VoidCallback> _boundListeners = {};
  final Map<String, UiFormFieldValidator> _validators = {};

  late bool _dirty;
  late bool _canSubmit;
  bool _externalValid = true;

  /// Whether any tracked field differs from its initial value.
  bool get isDirty => _dirty;

  /// Whether [field]'s current value differs from its initial value.
  ///
  /// Fields never reported through [setValue] read as clean. Useful for
  /// per-field "changed" affordances without maintaining separate state.
  bool isFieldDirty(String field) =>
      _current.containsKey(field) && _current[field] != _initial[field];

  /// Whether the form is valid: every bound [UiFormControllerField]'s
  /// validator currently passes, and the last value reported through
  /// [setValid] (`true` by default). A field with no validator always
  /// passes.
  bool get isValid => _externalValid && _validatorsPass;

  bool get _validatorsPass => _validators.entries.every(
    (entry) => entry.value(_current[entry.key] as String? ?? '') == null,
  );

  /// Whether the form should accept submission: dirty and valid.
  bool get canSubmit => _canSubmit;

  @override
  bool get value => canSubmit;

  /// Records the current value for [field] and recomputes [isDirty] (and,
  /// if [field] has a bound validator, [isValid]).
  void setValue(String field, Object? fieldValue) {
    if (_current.containsKey(field) && _current[field] == fieldValue) return;
    _current[field] = fieldValue;
    _sync();
  }

  /// Tracks [field] against [controller]: the controller's current text
  /// becomes the field's baseline, and every subsequent edit is reported
  /// through [setValue] automatically and checked against [validator] (if
  /// given). Rebinding the same [field] first calls [unbindController] on
  /// whatever was bound to it.
  ///
  /// The controller isn't disposed here — it's still owned by whoever
  /// created it. Call [unbindController] (or [dispose] this controller)
  /// before disposing a bound [TextEditingController].
  void bindController(
    String field,
    TextEditingController controller, {
    UiFormFieldValidator? validator,
  }) {
    _unbindController(field);
    _initial[field] = controller.text;
    _current[field] = controller.text;
    if (validator != null) _validators[field] = validator;
    void listener() => setValue(field, controller.text);
    controller.addListener(listener);
    _boundControllers[field] = controller;
    _boundListeners[field] = listener;
    _sync();
  }

  /// Stops tracking [field]'s bound controller and validator, if any. Its
  /// last known value stays in the snapshot until overwritten by [setValue]
  /// or cleared by [reset].
  void unbindController(String field) {
    _unbindController(field);
    _sync();
  }

  void _unbindController(String field) {
    final controller = _boundControllers.remove(field);
    final listener = _boundListeners.remove(field);
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    _validators.remove(field);
  }

  /// Sets validity contributed from outside a bound controller's own
  /// validator — cross-field checks, fields with no controller, an
  /// async/server-side check, etc. Combined with every bound validator via
  /// [isValid].
  void setValid(bool valid) {
    if (_externalValid == valid) return;
    _externalValid = valid;
    _sync();
  }

  /// Re-baselines every tracked field as clean against its current value,
  /// e.g. after a successful save.
  void markClean() {
    _initial
      ..clear()
      ..addAll(_current);
    _sync();
  }

  /// Replaces both the initial and current snapshots, e.g. when the form is
  /// reloaded with fresh data.
  void reset(Map<String, Object?> values) {
    _initial
      ..clear()
      ..addAll(values);
    _current
      ..clear()
      ..addAll(values);
    _sync();
  }

  bool _computeDirty() {
    if (_current.length != _initial.length) return true;
    for (final entry in _current.entries) {
      if (!_initial.containsKey(entry.key) ||
          _initial[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

  void _sync() {
    _dirty = _computeDirty();
    final nextCanSubmit = _dirty && isValid;
    if (nextCanSubmit == _canSubmit) return;
    _canSubmit = nextCanSubmit;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final field in _boundControllers.keys.toList()) {
      _unbindController(field);
    }
    super.dispose();
  }
}
