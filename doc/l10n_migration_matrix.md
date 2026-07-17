# Open UI Kit Localization Migration Matrix

The `UiLocalizations` contract (see
`lib/src/foundation/intl/ui_localizations.dart`) is the single place
every user-facing string the kit needs is declared. This document
tracks the per-component migration status from inline English
literals into that contract, and is updated with every PR that
touches localization.

## Migration recipe

For a typical component with hard-coded strings:

1. Add the missing getters to `UiLocalizations` (abstract), to
   `UiLocalizationsEn` (defaults), and to `UiLocalizationsAr` (built-in
   RTL sample). Exhaustive-switch callers are rare in the kit so the
   change is almost always additive.
2. In the component build method:

   ```dart
   final strings = UiLocalizations.of(context);
   // ...use `strings.someKey`
   ```

3. Drop any inline `'English Literal'` at the call site.
4. Add a test asserting the component picks up a non-English
   `UiLocalizations` when installed via `Localizations.override`. See
   `test/foundation/l10n_migration_test.dart` for the canonical
   fixture (works without needing `GlobalMaterialLocalizations`).
5. Update the row in this matrix.

## Status

| Component | Status | Strings | Notes |
|---|---|---|---|
| `UiPagination` | ✅ migrated | `previous`, `next`, `loading`, `pageSemanticsLabel(n)` | Uses direction-aware padding. |
| `UiSliverNavigationBar` | ✅ migrated, 🌐 audited | `back` (default fallback) | Explicit `spec.back.label` still takes precedence. The hero title uses `PositionedDirectional` for RTL correctness. |
| `UiDrawer` | ✅ migrated, 🌐 audited | `drawer` (semanticsLabel) | Pass `''` to suppress the optional semantics label. `UiDrawerSide.start` is the direction-aware default; `left` and `right` remain absolute. |
| `UiNavigationBackButton` | 🌐 audited | — | The history flyout uses direction-aware anchors so it opens on the trigger's reading-start edge. |
| `UiButton` | ⏳ pending | none today | No default label — caller always supplies. Nothing to migrate. |
| `UiAlertDialog` / `UiDialogScope.confirm` | 🚧 follow-up | `cancel`, `confirm` defaults | Currently inline; low risk because callers usually override. |
| `UiDataTable` (Retry button) | 🚧 follow-up | `retry` | Follow-up: migrate the inline `'Retry'` label. |
| `UiLoadingState` | 🚧 follow-up | `loading` | Default `semanticsLabel: 'Loading'`. |
| `UiDatePicker` | 🚧 follow-up | `today`, `selected`, `disabled`, `rangeStart`, `rangeEnd`, `opensMonthPicker`, `opensYearPicker`, `backToMonthGrid` | A11y-visible; worth a dedicated PR. |
| `UiTimePicker` | 🚧 follow-up | `selected`, `disabled` | Part of the picker PR. |
| `UiDropdownMenu` | 🚧 follow-up | `disabled` | Trivial swap. |
| `UiCheckbox` / `UiRadio` / `UiSwitch` | 🚧 follow-up | `disabled` | Trivial swap. |

Legend:
- ✅ migrated — component reads from `UiLocalizations.of(context)`.
- 🌐 RTL-audited — directional safety is locked by a focused
  regression test. Components carrying both markers have been
  migrated twice: once for strings and once for directionality.
- 🚧 follow-up — tracked, not yet done. Next component PR in the
  localization track picks the highest-signal entry.
- ⏳ pending — confirmed no strings to migrate.

## Why batch-by-batch, not one megafix

Every migration either nudges layout by a pixel (different string
width) or shifts a golden baseline when the test fixture renders
against the Arabic locale. Reviewing one component at a time keeps
the visual diff legible. The matrix above is the contract between
PRs — each migration PR updates it and references the row it flipped
to ✅.
