# Form composition

`UiFormSubmitController` remains the lightweight dirty/valid submit gate.
Use `UiFormController` when a form also needs field errors, touched state, async
validation, focus-first-invalid, and coordinated submission. It builds on the
existing gate without changing its notification or ownership contract.

```dart
final form = UiFormController();
late final name = form.registerField<String>(
  'name',
  label: 'Name',
  initialValue: '',
  validator: (value) => value.trim().isEmpty ? 'Enter a name' : null,
);

// In the widget tree:
UiFormErrorSummary(controller: form);
UiFormTextField(field: name, helper: 'Visible to your team');

// Submission validates every field and focuses the first invalid field.
await form.submit((values) async => repository.save(values));
```

Register fields once outside build. The form owns field controllers and any
focus nodes it creates. A focus node supplied to registration remains caller-owned.
Remove adapter widgets before disposing their form. The text adapter owns its
internal text controller and synchronizes form resets; external text controllers
remain application-owned.

`setValue` runs synchronous validation and invalidates in-flight async results.
Errors stay visually hidden until `markTouched` or `validate`; leaving a field
adapter marks it touched. Async validation runs on explicit `field.validate()` or
form validation/submission, not on every keystroke. Handle thrown validator or
save exceptions in the application (for example, show a retry alert); they are
not silently converted to an arbitrary validation message. Pending state clears
on failure. Validators should return localized error strings.

Submission rejects overlapping requests. Editing a field while validation is
pending invalidates that attempt. Submission receives an unmodifiable map snapshot;
field values themselves must be immutable. A successful save marks clean only
when no field was changed, removed, registered, or reset during the save. Use
`requireDirty: false` for initially valid confirmation forms. A field's async
validity is provisional until explicitly validated; `canSubmit` is a UI gate,
not permission to bypass `submit` validation.

For non-text controls, `UiFormFieldView<T>` supplies label/helper/error chrome.
Bind the child to `field.value`, `field.setValue`, and `field.focusNode`, and leave
its own label/helper/error slots empty. Use the controller's `isSubmitting` to
disable controls during saving when that fits the screen. The kit does not own
networking, persistence, authentication, or application navigation.

Use immutable new collections for multi-selection values. Collection equality
follows the value type's equality; set/list mutation in place is unsupported.

## Searchable multi-selection

`UiMultiSelect<T>` uses `UiSelectOption<T>` and a controlled `Set<T>`:

```dart
UiMultiSelect<String>(
  label: 'Teams',
  options: const [
    UiSelectOption(value: 'design', label: 'Design'),
    UiSelectOption(value: 'engineering', label: 'Engineering'),
  ],
  value: selectedTeams,
  onChanged: (values) => setState(() => selectedTeams = values),
);
```

The popup stays open after a selection. Up/Down moves through enabled options,
Enter toggles the active option, Escape closes, and Backspace on an empty query
removes the last removable selection. Removable selections have explicit localized
labels. Active-option announcements and selection counts are localized.

`disabledValues` prevents both choosing and removing those values. `maxSelections`
limits new additions without discarding selections already supplied by the caller.
Changing options never removes selections; use `selectedLabelBuilder` to name values
that are temporarily absent from the options. Use stable unique option values.

Rows are built lazily. Filtering runs against the supplied option models; remote
search, paging, and cancellation of network requests stay application-owned.
Option label, value, and leading content are supported; rich subtitles and custom
row builders remain features of the single-select APIs.

Run the full composition from the example directory with:

```sh
flutter run -t lib/forms_main.dart
```

`example/lib/form_workflow.dart` demonstrates text and multi-select adapters, an
error summary, a save callback, failure recovery, and disabled submission states.

### Compact input text scaling

Standard single-line `UiInput` controls preserve their normal-size text insets
when accessibility text grows. Their normal-size compact heights are unchanged;
parents must allow their height to grow at larger text sizes. Insets apply to the
text slot, so trailing controls do not receive extra padding. Multiline inputs
keep their existing padding, and embedded inputs leave spacing to their containing
surface (for example, an LMS search accessory or chat composer).

This is separate from touch-target sizing. Compact input visuals do not certify
44-point iOS or 48-dp Android hit regions. Changes to shared touch sizes, page
gutters, or radii need review in LMS before adoption.
