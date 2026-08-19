# AI Usage Guide

This guide helps AI coding agents and developer assistants use Open UI Kit
consistently in Flutter apps.

## Mental Model

Open UI Kit is a token-driven Flutter UI kit inspired by shadcn/ui. Components
use Flutter's widgets layer without relying on Material or Cupertino widgets.

Start with these principles:

- Use kit components before inventing custom UI.
- Use design tokens instead of raw colors, dimensions, typography, shadows, and
  animation timings.
- Compose small widgets from kit primitives instead of copying large component
  implementations into an app.
- Preserve accessibility, keyboard behavior, and RTL behavior already built into
  the kit.
- Keep app-specific business logic outside the UI kit.

## Imports

Use the public package API:

```dart
import 'package:open_ui_kit/open_ui_kit.dart';
```

Focused barrels are also public and useful in larger apps:

```dart
import 'package:open_ui_kit/foundation.dart';
import 'package:open_ui_kit/components/forms.dart';
import 'package:open_ui_kit/components/pickers.dart';
import 'package:open_ui_kit/patterns/layout.dart';
```

Do not import from `package:open_ui_kit/src/...` in application code.

## Theme And Tokens

Install the theme at the app root:

```dart
UiApp(
  lightTokens: UiThemeData.light(),
  darkTokens: UiThemeData.dark(),
  home: const AppHome(),
);
```

`UiApp` installs the token host, neutral route motion, localization plumbing,
and an overscroll-decoration-free scroll configuration. For another app root,
wrap its content in `UiTheme` and `UiScrollConfiguration`.

Resolve tokens inside widgets:

```dart
final tokens = UiThemeTokens.of(context);

return Padding(
  padding: EdgeInsets.all(tokens.spacing.x4),
  child: UiText(
    'Invoices',
    variant: UiTextVariant.heading,
    style: TextStyle(color: tokens.colors.textPrimary),
  ),
);
```

Prefer token values:

- `tokens.colors.*` for color.
- `tokens.spacing.*` for layout gaps and padding.
- `tokens.radius.*` for corner radius.
- `tokens.shadows.*` for elevation.
- `tokens.motion.*` for durations and curves.
- `tokens.typography.*` or `UiText` variants for text.

Avoid arbitrary one-off values unless they are data-driven, platform-required,
or necessary for a stable fixed-format control.

## Page And Layout Patterns

Use semantic page patterns when available:

```dart
UiCollectionPage<Invoice>(
  title: 'Invoices',
  items: invoices,
  loading: loading,
  error: hasError,
  errorTitle: "Couldn't load invoices",
  emptyTitle: 'No invoices yet',
  onRefresh: reload,
  itemBuilder: (context, invoice, index) => InvoiceCard(invoice: invoice),
);
```

Use:

- `UiPageScaffold` for page root, safe viewport, background, and bars.
- `UiPageLayout` for common page sections with filters/actions/secondary panes.
- `UiCollectionPage<T>` for list/grid pages with loading, empty, error, and
  refresh states.
- `UiFormPage` for centered forms with consistent footer/actions.
- `UiSettingsList` for grouped settings and split-view menus.
- `UiSafeViewport` for embedded page-like regions that need their own inset
  policy.

Avoid rebuilding page chrome with raw `Scaffold`, nested `SafeArea`, and custom
status-bar annotations when a kit page pattern already covers it.

## Navigation

Use `UiSliverNavigationBar` for top navigation inside scroll views:

```dart
CustomScrollView(
  slivers: [
    UiSliverNavigationBar(
      spec: UiNavigationSpec(
        title: 'Session details',
        back: UiNavigationBackConfig(
          label: 'Sessions',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    ),
    SliverToBoxAdapter(child: content),
  ],
);
```

Use `UiNavigationBackConfig` instead of hand-building a back row. The compact
back label adapts to available width, keeps the title centered, supports RTL
chevrons, and can expose history on long press.

Use `UiDirectionalIcons` for directional icons:

```dart
Icon(UiDirectionalIcons.chevronBack(context));
```

## Buttons

`UiButton` defaults to the primary action:

```dart
UiButton(
  label: 'Save',
  onPressed: save,
);
```

Use explicit intent for lower-emphasis actions:

```dart
UiButton(
  label: 'Cancel',
  intent: UiIntent.neutral,
  onPressed: close,
);
```

Secondary and neutral buttons show borders by default. For floating actions on
an elevated surface, opt out:

```dart
UiButton(
  label: 'View classes',
  intent: UiIntent.secondary,
  showBorder: false,
  boxShadow: tokens.shadows.md,
  onPressed: openClasses,
);
```

Use `UiIconButton` for icon-only actions and always provide `semanticsLabel`.

Use experimental `UiSmartActionGroup` when a primary action and hidden
secondary actions should stay inline instead of opening a sheet. It renders a
collapsed set plus a "More" control, then morphs into the full action set with
one group-level layout animation, faded content changes, equal expanded slots
by default, and compact vertical fallback.

```dart
UiSmartActionGroup(
  expandedLayout: UiSmartActionGroupExpandedLayout.equal, // default
  actions: [
    UiSmartActionGroupAction(
      id: 'enter',
      label: 'Enter',
      onPressed: enterClass,
    ),
    UiSmartActionGroupAction(
      id: 'end',
      label: 'End class',
      intent: UiIntent.danger,
      onPressed: endClass,
    ),
    UiSmartActionGroupAction(
      id: 'absent',
      label: 'Mark absent',
      intent: UiIntent.neutral,
      onPressed: markAbsent,
    ),
  ],
  collapsedCount: 1,
  moreLabel: 'More',
  collapseLabel: 'Close',
  collapseOnAction: true, // optional; defaults to keeping actions expanded
);
```

Use experimental `UiConfirmActionGroup` for two-button confirmation rows. The
primary button enters a confirmation state, expands, and changes label; the
secondary button shrinks and becomes the cancel action.

```dart
UiConfirmActionGroup(
  actionLabel: 'Save',
  confirmLabel: 'Confirm save',
  secondaryLabel: 'Cancel',
  cancelLabel: 'Keep editing',
  onConfirm: saveChanges,
);
```

Treat this component as screen-sensitive until it has been profiled in the
target app. Verify compact widths, RTL, reduced motion, repeated expand/collapse
cycles, and the exact callbacks that replace any previous sheet actions.

## Forms

Use controlled values and typed callbacks:

```dart
UiRadioGroup<AccountType>(
  label: 'Account type',
  value: accountType,
  options: const [
    UiRadioGroupOption(value: AccountType.student, label: 'Student'),
    UiRadioGroupOption(value: AccountType.teacher, label: 'Teacher'),
  ],
  onChanged: (value) => setState(() => accountType = value),
);
```

Prefer:

- `UiInput` for text entry with labels, helper text, errors, and validators.
- `UiSelect<T>` for small option sets.
- `UiCombobox<T>` for searchable option sets.
- `UiCheckbox` for independent booleans.
- `UiRadioGroup<T>` for single-choice groups.
- `UiSwitch` for immediate on/off settings.
- `UiFilterChip` for filter toggles.
- `UiSlider` for a single continuous/discrete value in a range.
- `UiRating` for star (or other icon) ratings, including read-only display.
- `UiFileUpload` for a file-selection dropzone; it never opens a picker
  itself — wire `onTap` to the host app's own file-picking package and feed
  the result back in via `fileName`/`fileSizeLabel`.

### Gating submit on "ready to submit"

Gate a submit button on whether the form is actually ready rather than
always enabling it (or gating on a loading flag alone). `UiFormSubmitController`
combines two signals into one `canSubmit`: **dirty** (a tracked field differs
from its baseline — on an edit form that's the persisted value, on a
creation form the baseline is just empty, so this reads as "the user has
started filling it in") and **valid** (every bound field's validator
passes). If a form should be submittable purely on validity with no baseline
to diff against — e.g. a confirm action that's pre-filled with valid
defaults — read `isValid` directly instead of `canSubmit`; see the second
example below.

```dart
final email = TextEditingController(text: actor.email);
late final submitGate = UiFormSubmitController(
  controllers: [
    UiFormControllerField('email', email, validator: emailField('Invalid email')),
  ],
);

// ...
UiInput(controller: email, validator: emailField('Invalid email'));

ValueListenableBuilder<bool>(
  valueListenable: submitGate,
  builder: (context, canSubmit, _) => UiButton(
    onPressed: canSubmit ? _save : null,
    ...
  ),
);

@override
void dispose() {
  submitGate.dispose(); // before disposing any controller it's bound to
  email.dispose();
  super.dispose();
}
```

Each `UiFormControllerField` pairs a field key with a `TextEditingController`
the caller already owns — its current text becomes that field's baseline,
and the same `validator` you'd pass `UiInput` gates `isValid`/`canSubmit` as
the user types, so there's no separate "recompute validity on every
keystroke" listener to hand-write. The controller itself is still owned and
disposed by the caller (dispose `submitGate` first). `bindController` covers
binding one later, after construction. Fields without a controller
(switches, selects, image paths, …) report through `submitGate.setValue(field,
value)` directly, and any validity that isn't captured by a bound field's
own validator — cross-field checks, an async/server-side check, … — through
`submitGate.setValid(bool)`. `UiFormSubmitController` itself validates
nothing; it only combines "changed" with every validity signal it's given
into one gate. After a successful save, call `submitGate.markClean()` to
re-baseline.

For a confirm-style action that starts pre-filled with valid defaults (e.g.
"Cancel class" with a sensible default already selected), requiring the user
to touch something first would be a regression — they should be able to
confirm immediately. Track validity only, and read `isValid` instead of
`canSubmit`:

```dart
late final submitGate = UiFormSubmitController(); // no controllers/baseline
// ...
submitGate.setValid(_isSelectionValid()); // call from every field's onChanged

AnimatedBuilder(
  animation: submitGate,
  builder: (context, _) => UiButton(
    onPressed: submitGate.isValid ? _confirm : null,
    ...
  ),
);
```

## Feedback Effects And Indicators

Use `UiComponentShadow` when a compact control needs the same theme-aware
clearance treatment as the stock refresh indicator. This is a separation
effect, not elevation; use `tokens.shadows.*` when a surface should appear
raised.

```dart
UiComponentShadow(
  shape: BoxShape.circle,
  child: permissionControl,
);
```

Use `UiLegibilityShadow` for text, icons, or controls floating directly over
scrolling content. Its alpha-following shadow stays compact by default; raise
`spreadRadius` and `blurSigma` only for high-overlap chrome such as a title
that collapses into the center of a navigation bar.

```dart
UiLegibilityShadow(
  blurSigma: 4,
  spreadRadius: 2.5,
  child: title,
);
```

The `UiRefreshIndicator` visual can also be reused independently of a
pull-to-refresh host:

```dart
const UiRefreshIndicator.refreshing();
const UiRefreshIndicator.completed();
UiRefreshIndicator.failed(error: error);
```

This is useful for short waits that should share refresh feedback styling,
such as waiting for record permission. Keep the surrounding status label or
live-region semantics owned by the feature so it describes the actual task.

Do not wrap enabled controls in `IgnorePointer` or `Opacity` to fake disabled
state. Use the component's `enabled`, `loading`, and callback parameters.

## Pickers

Use the compact time picker APIs for new work:

```dart
UiTimePickerField(
  label: 'Start time',
  value: time,
  minuteStep: 15,
  onChanged: (value) => setState(() => time = value),
);
```

Use `UiTimeGridPicker` directly inside drawers or sheets:

```dart
UiTimeGridPicker(
  value: time,
  minuteStep: 15,
  showBorder: false,
  boxShadow: const [],
  onChanged: (value) => setState(() => time = value),
);
```

`UiTimePicker` is legacy/deprecated. Do not introduce it in new screens.

Date pickers expose wrapper chrome controls:

```dart
UiDatePicker(
  value: date,
  min: DateTime.now(),
  showBorder: false,
  chromePadding: EdgeInsets.zero,
  onChanged: (value) => setState(() => date = value),
);
```

Use `showBorder: false` and `chromePadding: EdgeInsets.zero` when a picker is
already inside a drawer, sheet, card, or another framed surface. This avoids
nested borders while preserving the internal day/week/time structure.

## Feedback And Loading

Use kit-provided states:

- `UiAsyncState` for loading/empty/error/content branches.
- `UiCardSkeleton`, `UiSkeletonBar`, and `UiSkeletonText` for skeleton loading.
- `UiAlert` for inline notices.
- `UiToast` / `UiToaster` for transient feedback.
- `UiSpinner` for compact indeterminate work or determinate interaction
  progress. Switching `value` from a number to null preserves the same orbital
  indicator and starts its rotation.
- `UiPageScaffold.onRefresh` for page-level pull-to-refresh whose feedback
  must remain above navigation chrome.
- `UiRefresher` and `UiSliverRefresher` for pull-to-refresh inside standalone
  surfaces or sliver layouts not owned by `UiPageScaffold`.

Prefer skeletons for content reloads when preserving layout matters. Use a
refresh indicator only when the existing content remains visible and the action
is clearly a pull-to-refresh interaction.

## Surfaces And Overlays

Use kit scopes and surfaces:

```dart
final confirmed = await UiDialogScope.confirm(
  context,
  title: 'Delete invoice?',
  description: 'This cannot be undone.',
  confirmIntent: UiIntent.danger,
);
```

Use:

- `UiSheetScope.show` for modal sheets.
- `UiDrawerScope.show` for drawers.
- `UiDialogScope` for dialogs.
- `UiDropdownMenu` for anchored command menus.

These components already handle overlay placement, dismissal behavior, motion,
and core semantics.

## Visual Quality Rules

- Do not nest cards inside cards for ordinary page sections.
- Avoid one-off rounded boxes when a kit component exists.
- Keep repeated item cards compact, scannable, and token-driven.
- Keep button and chip text single-line with ellipsis in dense rows.
- Prefer `Wrap` for action groups that can overflow.
- Avoid hard-coded colors, gradients, and shadows that fight the theme.
- Do not add decorative backgrounds to operational screens unless the product
  explicitly calls for them.

## Accessibility Checklist

Before finishing UI changes:

- Icon-only controls have semantic labels.
- Form controls expose labels, helper text, disabled state, and error text.
- Loading buttons use `loading`, not a manually swapped child.
- Directional icons come from `UiDirectionalIcons`.
- Text does not overlap or overflow at phone and tablet widths.
- Tap targets stay usable. Use kit components instead of shrinking gesture
  detectors manually.

## Testing Guidance

For app changes using the kit, run focused widget tests for the edited feature.
For UI kit changes, run:

```bash
dart format .
flutter analyze
flutter test
```

Add tests when changing:

- Public component API.
- Layout behavior across phone/tablet/desktop widths.
- Disabled/loading/error states.
- Semantics labels and keyboard behavior.
- Overlay placement or dismissal.

Golden files should be updated only for intentional visual changes.

## Common Mistakes To Avoid

- Importing `src` paths from apps.
- Using `Text`, `Container`, or `GestureDetector` for controls that already
  exist as kit components.
- Hard-coding colors instead of using `UiThemeTokens`.
- Adding a second bordered surface around a picker, sheet, drawer, or card.
- Introducing `UiTimePicker` in new code; use `UiTimePickerField` or
  `UiTimeGridPicker`.
- Using glyph strings for back/next controls instead of `UiDirectionalIcons`
  and `UiIconButton`.
- Replacing skeleton reload states with generic progress indicators when the
  layout should remain stable.
