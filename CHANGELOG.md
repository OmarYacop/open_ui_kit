# Changelog

## 0.8.1 - 2026-09-05

### Added

- Added light and dark visual overviews and component usage screenshots to the
  README, captured from the package's public widgets.
- Added a responsive example showcase, component previews, and documentation
  capture tooling with guidance for maintaining the visual assets.
- Added product and design system documentation for contributors.

### Compatibility

- No public API or dependency changes.

## 0.8.0 - 2026-08-20

### Added

- Added `UiFormSubmitController` to gate a form's submit button on whether
  it's dirty (a field changed from its baseline) combined with validity.
  Pass `UiFormControllerField`s (field key + `TextEditingController` +
  optional validator) to `controllers` to seed a field's baseline directly
  from an existing controller and validate it on every edit, with no
  separate listener to hand-write; `bindController` covers binding one
  after construction, and `setValue`/`setValid` cover fields without a
  controller or validity that isn't per-field. For confirm-style actions
  with pre-filled valid defaults, read `isValid` directly instead of
  `canSubmit` so the form doesn't require dirtying before it can be
  confirmed.
- Added `UiSlider` for a single continuous/discrete value in a range, with
  drag, tap-to-jump, and arrow-key interaction.
- Added `UiRating` for star (or other icon) ratings, with half-rating
  support and a read-only display mode.
- Added `UiFileUpload`, a presentational file-selection dropzone that stays
  dependency-light by delegating the actual file pick to the host app.
- Added `UiMediaGallery` and `UiMediaPreview` for gallery browsing and
  full-screen media presentation.
- Added `UiSliverDataTable.lazy` for virtualized tables that participate
  directly in an ancestor `CustomScrollView`.
- Added the Contour motion and interaction language, including coordinated
  morph, crossfade, presence, action-release, and accessory-release primitives.
- Added page-route, edge-swipe, and navigation-history APIs for custom
  back-navigation experiences.

### Changed

- `UiSpinner` now uses the refresher's orbital charge visual for determinate
  progress and rotates that same visual for indeterminate work. Refreshers,
  loading buttons, menus, and async states now share this primitive.
- Reduced the published package to the plugin essentials by excluding local
  test artifacts and internal engineering files.

### Fixed

- Fixed `UiFormSubmitController` notifications when validator or external
  validity changes alter `canSubmit`, including after unbinding a controller.
- Fixed the navigation-history flyout when used inside `UiPageScaffold`.

## 0.7.0 - 2026-08-14

### Added

- Added `UiAdaptiveSheetScope` for token-driven phone sheets and constrained
  tablet/desktop modal surfaces.
- Added section-aware `UiSliverCollection` support and exposed it through
  `UiCollectionPage` for adaptive full-width headers and grid rows.
- Added `UiContentPage` for token-spaced, titled, refreshable content pages.
- Added `UiDismissKeyboard` for reusable page-level focus dismissal.

### Changed

- `UiWavatar` now supports one-to-four-shape group compositions through
  `UiWavatarParticipant`, with an independent seed and characteristics for
  each participant.
- Transparent `UiPageScaffold` surfaces now use their opaque scroll-fade
  backing color to keep status and navigation bar icons legible in dark mode.
- Refined `UiTypingIndicator` into a compact incoming ellipsis bubble with
  the active participant avatar, while retaining localized live-region
  announcements. `UiMessageScroller` now distinguishes real tail arrivals
  from loaded history and queues arrivals correctly when auto-follow is off.

## 0.6.0 - 2026-08-05

### Added

- Added calendar and schedule time-grid components with overlapping-event
  layout support.
- Added `UiTimeline` for structured chronological data display.
- Added `UiTypingIndicator` with animated multi-user presence, stacked avatars,
  localized labels, live-region semantics, RTL support, and reduced motion.
- Added reusable `UiComponentShadow` and `UiLegibilityShadow` effects for
  component clearance and foreground legibility.

### Changed

- Anchored dropdowns, selects, comboboxes, and time pickers are now non-modal:
  parent scrolling keeps them open and attached to their trigger, while a
  genuine outside tap dismisses without blocking the tapped control.
- Dropdown menus now use the semantic floating overlay layer, below modal
  surfaces and bottom navigation chrome.
- Refined data-table layout, refresh feedback, navigation chrome, safe-area
  handling, and responsive page behavior.

## 0.5.0 - 2026-08-01

### Breaking

- Removed Open UI Kit's production dependency on Flutter Material and
  Cupertino libraries. `UiThemeTokens` is now a plain immutable token object,
  and `UiThemeData.light()`, `.dark()`, and `.fromBrand()` return token objects
  for `UiApp`/`UiTheme` rather than Material `ThemeData`.
- Back-swipe gestures are disabled unless explicitly enabled, and their visual
  style is selected explicitly with `UiBackSwipeTransition.slide` or
  `.layered`; platform-derived `auto` and `cupertino` styles were removed.
- Adaptive effects now resolve to an Open UI-owned budget independent of the
  host operating system. Native floating-window chrome is opt-in through
  `UiNavigationRail.enableFloatingWindowChrome`.

### Added

- Promoted `UiIntent` and `UiIntentPalette` to the public foundation API. New
  code should import `package:open_ui_kit/foundation.dart` or the main
  `package:open_ui_kit/open_ui_kit.dart` barrel.
- Added a documented deprecation lifecycle with explicit removal versions.

### Deprecated

- Importing `UiIntent` or `UiIntentPalette` through
  `package:open_ui_kit/components/forms.dart` or the internal `button.dart`
  library is deprecated. This compatibility export remains available through
  all `0.x` releases and will be removed in `1.0.0`. Dart cannot annotate an
  export directive as deprecated without incorrectly deprecating the canonical
  declaration, so this migration is enforced through documentation and API
  compatibility tests.

## 0.4.0 - 2026-07-29

- Added adaptive visual-effects budgets with reduced Android defaults, full
  iOS/macOS glass effects, compile-time backdrop-filter exclusion, theme
  overrides, accessibility reduction, and coverage across kit-owned blur
  surfaces.
- Added `UiRadioGroup<T>` and `UiRadioGroupOption<T>` for typed grouped radio
  selection with labels, helper text, error text, disabled state, and
  horizontal or vertical layout.
- Added `UiTimeGridPicker` and `UiTimePickerField` for compact column-based
  time selection in drawers, forms, and anchored popovers.
- Deprecated legacy `UiTimePicker` in favor of `UiTimeGridPicker` and
  `UiTimePickerField`.
- Added picker chrome controls for suppressing nested borders and adjusted date
  picker month navigation to use `UiIconButton` chevrons instead of text glyphs.
- Made compact navigation back labels adapt to wider tablet and desktop
  navigation bars while preserving the tighter phone cap.
- Added experimental `UiSmartActionGroup` for inline "More" action groups that
  morph into additional buttons without opening a sheet, now using a coordinated
  group-level layout animation with equal expanded slots by default.
- Added experimental `UiConfirmActionGroup` for two-button save/delete
  confirmation rows with coordinated width and label morphs.
- Added AI-agent guidance through `AGENTS.md`, `doc/ai_usage_guide.md`, README
  quick-start rules, public Dartdoc, and `example/lib/ai_usage_examples.dart`
  so tools like Codex can follow package conventions and best practices.

## 0.3.1 - 2026-07-22

- Added `UiButton.showBorder` so bordered button variants can opt out when used
  as elevated floating actions.

## 0.3.0 - 2026-07-22

- Fixed page bodies and generated title bars being placed beneath iPhone
  status-bar and Dynamic Island insets.
- **Breaking:** `UiPageScaffold`, `UiPageLayout`, `UiCollectionPage`, and
  `UiAppShell` now apply safe insets by default. Intentional edge-to-edge pages
  must opt out explicitly.
- Preserved vertical edge-to-edge page surfaces while independently applying
  physical left/right protection for landscape display cutouts.
- Added reduced-motion support, reusable fade-scale and slide-fade transition
  primitives, and migrated structural transitions in menus, dialogs, drawers,
  toasts, tabs, app routes, navigation chrome, and sheets to resolve motion
  from the theme.

## 0.2.0 - 2026-07-17

- Added pull-to-refresh widgets, programmatic refresh control, and collection
  page integration.
- Added dual-pane layouts, sticky sliver regions, numeric navigation badges,
  and navigation chrome that adapts to persistent rails.
- Improved navigation rail and drawer sizing, mobile landscape navigation,
  floating-window chrome handling, and component spacing and radii.
- Corrected navigation examples and Markdown formatting across the package
  documentation.
- **Breaking:** Removed `UiSliverNavigationBar.bodyTopPadding`. Add any desired
  gap to the content sliver that follows the navigation bar.

## 0.1.0 - 2026-07-17

- Added the initial publication-ready release of the token-driven Flutter UI
  kit.
- Added reusable components for forms, feedback, navigation, overlays, data
  display, and responsive page layouts.
- Added theme foundations, platform capabilities, accessibility behavior, and
  golden coverage.
