<repository-workflow>

# Open UI Kit repository workflow

- Read `doc/development_workflow.md` before material work. It is authoritative for issues,
  labels, branches, pull requests, CI, stacked PRs, ADRs, and release tags.
- Use `<type>/<issue>-<short-kebab-description>` branches and Conventional Commit subjects.
- Plan dependent work as a native GitHub stacked PR: foundations at the bottom, one reviewable
  outcome per layer, `Part of #issue` on intermediate layers, and `Closes #issue` only on the
  layer that completes all acceptance criteria.
- Keep every stack branch in this repository. Put fixes on the layer where they belong, then run
  `gh stack rebase` and `gh stack push` to cascade them upward.
- Run `./scripts/ci changed` before handoff. `./scripts/ci all` is the release-level check and
  includes macOS golden verification.
- Apply exactly one `type:*`, one or more `area:*`, and exactly one `priority:*` label to every
  material issue.
- Never update golden baselines or create, move, reuse, or push a release tag unless the user
  explicitly requests that action.

</repository-workflow>

# Open UI Kit Agent Guide

This file is for AI coding agents working in apps that use `open_ui_kit`.
Follow it before introducing custom Flutter UI.

## First Choices

- Import the kit through `package:open_ui_kit/open_ui_kit.dart` unless the app
  already uses focused barrels such as `components/forms.dart`.
- Use `UiApp` at the app root and pass `UiThemeData.light()` /
  `UiThemeData.dark()` as its token sets when customization is needed.
- Read tokens with `UiThemeTokens.of(context)`. Prefer token colors, spacing,
  radii, shadows, motion, and typography over hard-coded design values.
- Prefer existing kit components before writing app-specific widgets.
- Keep Material/Cupertino dependencies outside the kit. Use widgets-layer
  Flutter APIs at platform-integration boundaries.

## Component Selection

- Page shell: `UiPageScaffold`, `UiPageLayout`, `UiCollectionPage`,
  `UiFormPage`, `UiSafeViewport`.
- Top navigation: `UiSliverNavigationBar` with `UiNavigationSpec`; use
  `UiNavigationBackConfig` for back behavior.
- Actions: `UiButton` for labeled actions, `UiIconButton` for icon-only
  actions, and experimental `UiSmartActionGroup` for inline overflow actions
  that should expand without opening a sheet.
- Text: `UiText`; choose semantic variants instead of raw `TextStyle`.
- Forms: `UiInput`, `UiSelect`, `UiCombobox`, `UiCheckbox`, `UiRadioGroup`,
  `UiSwitch`, `UiFilterChip`.
- Pickers: `UiDatePicker`, `UiTimePickerField`, `UiTimeGridPicker`,
  `UiDateRangePicker`, `UiTimeRangePicker`, `UiDateTimePicker`.
- Feedback: `UiAlert`, `UiToast`, `UiAsyncState`, `UiRefresher`, skeletons.
- Overlays and surfaces: `UiSheetScope`, `UiDrawerScope`, `UiDialogScope`,
  `UiDropdownMenu`.
- Data display: `UiCard`, `UiBadge`, `UiAvatar`, `UiDataTable`,
  `UiPagination`, `UiMediaPreview`.

## Important Semantics

- `UiButton()` defaults to primary. Use `intent: UiIntent.neutral` for a
  low-emphasis outlined button.
- Secondary and neutral buttons show a border by default. For floating buttons
  inside an already elevated surface, pass `showBorder: false`.
- `UiSmartActionGroup` is experimental. Use it when a "More" button should
  expand inline into additional actions. Wide layouts use a coordinated
  group-level morph and equal expanded slots by default; set
  `expandedLayout: UiSmartActionGroupExpandedLayout.actionFlex` only when custom
  expanded ratios are required. Verify the target screen for overflow, animation
  smoothness, and accidental taps before publishing. Action presses keep the
  group expanded by default; set `collapseOnAction: true` only when the screen
  should close the expanded set after a command.
- `UiConfirmActionGroup` is experimental. Use it for two-button confirmation
  rows such as Save/Cancel or Delete/Cancel; do not model confirmation as a
  generic "More" action group.
- `UiTimePicker` is legacy/deprecated. Prefer `UiTimePickerField` for form
  inputs and `UiTimeGridPicker` for inline drawer or sheet content.
- Date and time picker wrappers have chrome controls. Use `showBorder: false`
  and `chromePadding: EdgeInsets.zero` when embedding inside a drawer, sheet, or
  card that already provides the surface.
- Use `UiRadioGroup<T>` for grouped choices. Use bare `UiRadio<T>` only when a
  custom group layout genuinely owns the surrounding semantics and spacing.

## Layout Rules

- Do not put cards inside cards for page sections. Use cards for repeated items,
  framed tools, and modals.
- Let page patterns own page spacing and safe insets; avoid stacking `SafeArea`,
  `Scaffold`, and custom status-bar handling around kit page widgets.
- Use `LayoutBuilder`, `UiAdaptive`, or kit page patterns for responsive
  decisions. Avoid fixed widths unless a component requires a stable control
  size.
- Preserve text fitting with `maxLines` and `TextOverflow.ellipsis` in compact
  rows, buttons, and navigation bars.
- Use `UiDirectionalIcons` for back/forward/chevron icons so RTL stays correct.

## Accessibility

- Give every icon-only control a semantic label.
- Keep labels visible for form fields and grouped controls where possible.
- Preserve disabled/loading semantics by passing `enabled`, `loading`, and
  callbacks through the kit APIs instead of wrapping with `IgnorePointer`.
- Prefer kit overlays and sheets because they already include focus, semantics,
  dismissal, and motion behavior.

## Verification

- After UI kit changes, run `dart format`, `flutter analyze`, and focused
  widget tests.
- For shared behavior, run `flutter test`.
- Add tests for semantics, adaptive layout, overflow, and disabled/loading
  states when changing public components.
- Do not update golden files unless the visual change is intentional and the
  user asked for it.

## API deprecations

- Follow `doc/deprecation_policy.md` for public API migrations.
- Every deprecation must name its replacement and scheduled removal version in
  `CHANGELOG.md`.
- Do not remove a compatibility API before its announced breaking release.
- Keep compatibility coverage for deprecated export paths that Dart cannot
  annotate with `@Deprecated`.

For more detail, read `doc/ai_usage_guide.md`.
