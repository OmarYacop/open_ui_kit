## Linear tracking (primary work tracker)

Use the connected Linear plugin for features, bug fixes, improvements, tasks,
refactoring, documentation, maintenance, and release work in this repository.

- Repository: `open_ui_kit`
- Linear project: [Open UI Kit](https://linear.app/omar-yacop/project/open-ui-kit-a2ac6baa8107)
- Project ID: `3dbd6f88-49a2-4228-ba9d-bfb1ab62219f`
- Team: `Omar Yacop` (`OMA`), ID `9e2ee7cb-679a-4403-b156-e6ca4f8d69ec`

### Working agreement

1. Before material work, search this Linear project for an existing issue. Reuse
   the matching issue; otherwise create one in the project above. One issue tracks
   one coherent outcome, not every edit, command, or conversation. Read-only questions
   need no issue unless they produce actionable follow-up work.
2. Record the problem, scope, observable acceptance criteria, affected repository
   and platforms/clients, dependencies, and verification plan. For bugs, include
   reproduction, expected/actual behavior, and impact. Never include secrets or
   customer data. Do not invent priority, deadlines, or completion evidence.
3. Use the existing Linear labels: `Feature`, `Bug`, `Improvement`, `Maintenance`,
   or `Documentation`. Use native priority and milestone fields where appropriate;
   record affected areas in the description. GitHub's `type:*`, `area:*`, and
   `priority:*` taxonomy still applies to GitHub artifacts, not to Linear issues.
4. Move planned work through `Backlog` or `Todo` to `In Progress` when it starts.
   Record meaningful scope changes, blockers, verification results, and PR links
   on the issue using the plugin. Use `Blocked` and explicit dependency relations
   when blocked; remove the label when resolved. Avoid repetitive status updates.
5. Move implemented work awaiting review/merge to `In Review`. Mark `Done` only
   after acceptance criteria and required verification pass and the change is
   merged, or the user explicitly accepts local-only delivery. Documentation edits
   left in a working tree are still awaiting review. Report skipped/failed checks
   accurately and keep unfinished work open.
6. Include the full `OMA-123` identifier and Linear issue URL in the PR description
   and final handoff. Link the PR back to Linear. Keep existing branch validators:
   use the numeric part of the Linear identifier in `<type>/<number>-<description>`,
   e.g. `fix/123-login-retry` for `OMA-123`. The full identifier and URL disambiguate
   it from a GitHub issue. Preserve Conventional Commits and existing stack rules.
7. In stacks, identify partial work with `Part of OMA-123` and its URL. Record
   completion only after all required layers are merged and verified. Do not use
   `Closes #123` for a Linear issue or assume GitHub/Linear auto-sync is configured;
   explicitly verify and update Linear through the plugin.
8. For work spanning repositories, create or reuse an issue in each affected
   Linear project and link them with dependencies/related issues. Do not create
   duplicate records for the same outcome within one project.
9. Existing GitHub issues and historical `#N` references remain valid. When continuing
   one, search Linear for a linked counterpart, create it only if absent, and retain
   the GitHub URL and acceptance criteria. Do not bulk import, close, or rewrite the
   legacy backlog. Existing GitHub PR links remain intact.
10. If the plugin is unavailable, continue independent local work, report the
    tracking failure and pending update in the handoff, and retry when available.
    Never claim an issue was created or updated without a successful tool result.

This section supersedes older GitHub-Issues-only instructions, issue-number examples,
and issue-label requirements for new work. Existing architecture/scope, CI, review,
privacy, merge, and release-authorization rules continue to apply. Historical plan
files remain reference material; do not run legacy GitHub backlog sync in apply mode
to track new work. Linear is the source of current work status and acceptance criteria.

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
