# Changelog

## Unreleased

- Add optional `UiIconButton.iconSize` to size glyphs independently of the surface while preserving the accessible touch target. Keep Contour action surfaces at 36px with their original glyph sizing.

- Keep bottom navigation accessories sharp when switching pages with the same icon. `UiBottomTabAccessory.contentKey` identifies custom content independently of the destination; changed content retains its dissolve.

- `UiDialog` gains `headerAction` (a trailing title-row control such as a close button), `maxWidth`, and `scrollable`, so compact pickers and tall content no longer need a hand-built dialog shell around `UiDialogScope.show`.

- `UiSystemBarsStyle.light`/`dark` now disable Android's status and navigation bar contrast enforcement, matching their transparent bars, and `UiSystemBarsStyle.forBrightness` picks the style for an already-resolved app appearance.

- Give every `UiNavigationBackButton` the long-press history menu by default: with no explicit `history` it now lists the routes behind the page from `UiNavigationControllerScope` or `UiNavigatorHistoryScope`, and picking an entry pops back to it. `UiNavigationBackButton.historyOf` and `popToHistoryItem` expose that resolution and pop-to-route logic (previously private to `UiSliverNavigationBar`) for custom chrome; pass `history: const []` to opt out. `UiChatHeader` now publishes its title to the history observer, `UiNavigatorHistoryScope.registerPageTitle` shares that guarded registration, and `UiDualPane` marks inline detail panes as inactive pages so their chrome never renames the primary pane's history entry.

- Add scrollable media caption overlays and coordinated player chrome to `UiMediaViewerPage`; refine captioned chat media insets and provide `UiChatMessage.mediaBorderRadius`.

- Align chat headers with compact sliver navigation using shared row geometry and text measurement, including status insets and accessibility text sizes.

- Balance the shared reply-return/latest-message pill around its visible controls, accounting for touch-target space without resizing the button surfaces.

- Keep large-title navigation spacing independent of the viewport fade boundary and status-bar height; content pages no longer add a residual fade spacer after their navigation header.

- Match chat attachment and selection-primary button surfaces to the composer control extent on all platforms. Add optional `UiIconButton.visualExtent` for parent-sized controls; default toolbar sizes remain unchanged.

- Increase medium navigation/menu icon surfaces to 44px and back chevrons to 32px, restoring 6px chevron inset and matching class-card primary action height.

- Use a shared fixed 40px medium icon-button surface and 22px action icon across text settings; keep the back chevron at 30px with room around it. Restore progressive top scroll blur on Android alongside Apple platforms, retaining the blur opt-out and preserving live page state when the shader loads.

- Slightly enlarge the navigation back chevron and scale it with its button chrome consistently across iOS and Android.

- Soften progressive blur onset with smoothstep easing and restore the original 128px phone fade region; Android remains gradient-only.


- Keep root menu action targets at their final positions while opening content appears, so selection and submenu navigation do not wait for the spring to settle.

- Restore historical Apple progressive blur and Android gradient-only scroll edges, remove header tint plateaus, and keep icon-button painted sizes stable inside tight navigation slots.


- Fix translucent scroll-edge protection, reduce phone fade clearance, preserve header/scroll state when search toggles keyboard avoidance, retain compact navigation columns with one-line labels, and align unread counts with truncated conversation titles. Tighten back-button surfaces with directional optical alignment.


- Address the family Android audit: protect fixed headers independently of blur support, keep large-title origins consistent, adapt expanded navigation columns to whole-word label widths, and refine back controls, compact titles, menus, and chat scroll controls.
- Distant message reveals use one interruptible fade-through instead of repeated estimated scroll animations, and settle clear of floating controls. Composer transitions reuse input/deck subtrees; reply-return count updates do not restart entrance motion. Add optional `UiScrollEdgeFade.topProtectionExtent` for fixed chrome over bright content.

- Add `UiMediaViewerPage` for canonical overlay navigation and edge-to-edge content, with tap-to-hide chrome, safe-area controls and keyboard dismissal; `UiMediaGallery.showChrome` supports embedding without duplicate toolbars. `UiSliverNavigationBar.useOverlay` lets enclosing media chrome own visibility and input.

- Keep the same large-title/action origin across custom slivers and page patterns; fade clearance remains below that shared anchor.

- Reduce bottom-dock accessory spring overshoot by 80% and expand the shared outer fill/border on press, keeping the icon and touch target stationary.

- Add `UiChatAttachmentTray` and `UiChatComposer.conversation.attachmentShelf` for inline draft media, bounded photo batches, compact file rows, accessible removal, and caller-owned inspection.

- Match the light-mode scroll-to-bottom control to the chat reply-return (@) button with the same border and no individual shadow.

- Fix hidden bottom-tab pages throwing Flutter relayout-boundary assertions after repeated controller updates or rotation. Preserved pages now use standard IndexedStack layout while retaining active-page history scoping.

- Restore conversation tile borders and unread fills, and fluid open-container closed surfaces, so migrated Chat and Library items retain their light-mode boundaries.
- Expanding bottom navigation hugs the bottom edge with inset-aware expanded bottom corners and honors landscape side insets. Secondary-page selection only substitutes the last compact slot temporarily; persisted order changes only in edit mode.

- Preserve drawer content state when an open adaptive drawer switches between portrait side placement and landscape bottom placement.

- Reduce unused space below title-only sliver headers with title-following actions, preserving their alignment with subtitle headers and bottom action clearance.

- Keep expanded sliver titles at the same vertical anchor with or without a subtitle or title-following action, reserving a consistent subtitle line.

- Lift sliver navigation titles/subtitles and actions above the bottom edge, with shared expanded positioning, 12px expanded clearance and 8px compact clearance. Header/action heights accommodate text and chrome scaling.

- Refine conversation spacing above the keyboard and live edge, round message quotes and tighten their content gap, compact failed-send recovery, and use neutral history controls. Inbox previews use remaining width. `UiChatComposerActions` adds Contour selection-deck transitions with a persistent close control and an opaque destructive primary action; `onAttachmentMenuOpened` supports preserving draft focus through native attachment flows.

- Navigation titles use measured side-control widths; chat headers default to equal, text-scaled 44px back/avatar slots (`controlExtent`). Page body insets now clear active scroll fades as well as system safe areas, with `scrollFadeTopClearance` / `scrollFadeBottomClearance` overrides on `UiPageScaffold`. Custom scrollables must consume `UiPageBodyInsets`.

- Add `UiChatComposer.conversation`, measured `UiChatScaffold`, compact `UiChatHeader`, grouped `UiChatTimeline.messages`, `UiChatMessage`, and `UiChatWorkspace`. Preserve the LMS attachment/input/reply design, formatted controller ownership, selection/recording mode slots, RTL reply gestures and latest-outgoing receipt policy. Existing chat constructors remain available.

- Refine chat presentation: compact message/composer reply variants without arrows, configurable inset corner radii, full-width conversation titles and trailing preview-line timestamps.

- Message-scroller controllers expose `isMessageVisible`, `isScrolling`, and opt-in `jumpToMessage(onlyIfNeeded: true)` for reply navigation that leaves readable targets in place. Incoming arrivals preserve active drags/flings near the live edge.

- `UiMessageScroller` now uses a standard lazy Flutter `ListView.builder` with platform physics, retaining message-ID jumps, unread/live-edge controls and history preservation without scroll-end reanchoring.

- Add `UiMessageReceipt` / `UiMessageDeliveryStatus`, `UiReplyPreview`, `UiConversationTile`, and `UiConversationLayout` for reusable delivery/retry, quoted replies, inbox rows and floating conversation chrome. Existing chat APIs remain compatible. See `doc/chat_presentation.md` and `example/lib/chat_main.dart`.

- Message scrolling preserves active swipes and fling momentum across rebuilds; queued reading anchors no longer swallow the first swipe when reversing direction.

- **Behavior change:** `UiBottomNavigationTokens` defaults shrink the expanding dock from 76 to 64 (`compactHeight`) with a 44 icon area; icon tiles stay vertically centered and the drawer handle, accessory source and body inset derive from the tokens.
- `UiApp` installs an app-wide `IconTheme` using the token foreground, and `UiSettingsItem.trailing` inherits a themed icon color like `leading`, so bare icons no longer render opaque black in dark mode.
- Back history: only the active tab page publishes its title, and pages without a large title fall back to `compactTitle`, so a page pushed from a tab lists that tab (not a previously visited sibling) in the long-press menu.
- Icons follow the system text scale: `UiApp` sets `applyTextScaling` on its root `IconTheme`, chrome (icon buttons, tab bars, settings tiles, timeline markers, smart action groups) grows up to 1.3x via `uiChromeScale`, and `UiApp.maxTextScale` can clamp text and icons together.
- Expanding bottom navigation: the whole compact dock (and the strip above the expanded grid) is a translucent drag surface for the deck, so users no longer need to hit the 32pt pill; taps and hold-to-reorder on tiles still win. Destination labels get side padding and ellipsize instead of touching neighbouring cells.
- Text inputs on Android (and any platform without `SystemContextMenu`) show a widgets-layer port of the standard Material selection toolbar with localized actions instead of the kit's custom action sheet; OTP inputs share it.
- Fluid page routes can be dragged to dismiss: a free-form drag anywhere on the page (a sideways pull on a list, or an over-scroll past its top) carries the page with the finger in any direction while it shrinks. Releasing hands the page's position and velocity to a spring, so past the threshold it flies straight back into the source and otherwise springs back in place, never restarting from rest (`UiFluidPageRoute.dragToDismissEnabled`, `UiFluidDismissRegion`). `UiFluidOpenContainer` makes its closed surface pressable like `UiOpenContainer`.
- Experimental fluid route choreography: `UiContainerTransformStyle.fluidZoom`, `UiFluidPageRoute` / `UiFluidOpenContainer` / `context.pushUiFluidPage`, and `showUiFluidSheet` / `UiFluidSheetAnchor` morph a tapped surface into a page or bottom sheet using the fluid sampler, with monotonic reversal under back-swipe and drag (ADR 0006).
- Menus opened while a soft keyboard is up keep the field's focus and follow their anchor when the keyboard retreats instead of dismissing; without a keyboard they still take focus for arrow-key navigation.

- Add `UiMenuTokens.borderColor` for exact per-menu outline matching; icon-button press growth preserves the configured stroke width.

- Normalize captured pill radii before menu morphs and synchronize corner-radius/stroke-width progression without spring overshoot.

- Fluid surfaces paint the outline outside the content clip, preventing double antialiasing and border halos at fractional animated bounds.

- Button-to-menu transitions capture kit trigger fill, border, corners and visual bounds, start from the pressed frame, and return to the resting button without substituting menu styling at the compact endpoint.

- `UiDropdownMenu` and `UiFluidMenuButton` expose `destinationOffset`, `transitionDurationScale`, and per-instance `menuTokens` for lower-level placement, motion and surface control while preserving existing defaults and reduced motion.

- Chat composers contain text and send/record actions in one input surface. Icon buttons support `surfaceMargin` to inset a smaller painted action without enlarging the input or reducing the touch target.
- Message scrolling uses stable item boundaries for media/history pagination and direct distant jumps; asynchronous initial content is positioned correctly. Latest positioning respects composer padding, kept-alive message jumps settle on the requested ID, and newer scroll commands supersede initialization.
- Search inputs and combobox filtering debounce for 300 ms; `UiInput.debounceDuration` allows explicit control.
- Back history preserves replacement order, uses stable route targets, and no longer invents destinations from labels.
- Released bottom-dock accessory buttons retain their growing press surface.


- **Behavior change:** `UiBottomTabScaffold` now defaults to expanding navigation with four compact slots. Use `overflowBehavior: UiBottomTabOverflowBehavior.drawer, maxVisibleBottomItems: 3` to retain the previous More behavior; explicit paged navigation and low-level tab bars remain supported.
- Add `UiBottomNavigationTokens` through `UiThemeData` / `UiThemeTokens.bottomNavigation` for drawer cell geometry and motion. Separate drawer state from paging and share accessory contour rendering without allocating paging controllers in the default path.
- Hold a destination to enter customization and lift it in the same gesture. Reordering inserts at the target position, animates intervening cells, commits only on drop, and restores ordering on cancellation without a source ghost. Editing wiggle defaults to a 240ms cycle and honors Reduce Motion (OMA-46 / OMA-48).
- Add optional `UiDraggable.childWhenDragging` / `decorateFeedback` and `UiDropRegion.showDecoration` to support surface-owned drag feedback; existing generic drag defaults remain unchanged.

- Add composable typed drag sources/drop regions, accessible sortable lists and opt-in `UiDataTable` row reordering. Ordinary tables retain their original rendering path; lazy sorting reads row identity separately from cell construction. Include a runnable drag-and-drop workbench and keyboard, rejection, cancellation and lazy-build coverage (OMA-54).

- Give paged navigation one continuous dock/accessory border through split and merge. Reduce redundant fluid repaint/filter work without changing choreography.
- Enable progressive scroll-edge blur on shader-filter-capable Android renderers. Capture only the full-resolution edge plus the Gaussian sampling apron, retain renderer/accessibility fallbacks, share in-flight shader loads, and dispose temporary scenes.

- Add `UiDropdownMenu.sourceBorderRadius` (also accepted by its compatibility adapter) so custom trigger corners persist through opening and closing. Full directional/asymmetric corner geometry is interpolated and clipped consistently; omitted radius retains the pill default.

- Add platform-adaptive corner treatment through `UiRadiusTokens.cornerStyle`: continuous rounded superellipses on iOS/macOS and circular rounded corners elsewhere, with explicit overrides. Shared boxes, button focus outlines, menu surfaces and blur/hit clips agree on the shape; motion remains unchanged. Native platform selection uses Flutter's compiler-constant default.

- Animate small icon-button press growth and release using theme fast/standard timing. Interrupted presses retarget continuously, icons retain their size, hit bounds remain fixed, and reduced motion disables scaling. Activation never waits for the visual return.

- Let builder menu buttons own their painted press/hover/focus surface and their long-press recognizer. Remove the enclosing fixed chrome and extra activation target; disabled controls and surrounding padding no longer open menus. Add optional `UiIconButton.borderWidth` and `UiButton.borderRadius` styling controls.

- Add `UiDropdownMenu.triggerBuilder` for interactive normal/icon buttons while retaining existing `trigger:` compatibility. Navigation Back now uses kit buttons with a larger 24px direction-aware chevron and a 44px minimum target; hold/drag history remains supported.

- Unify navigation back/history and action menus: round/pill triggers share chrome and source radius, Back taps retain single-pop behavior, and long-press history uses the shared morph/drag/keyboard menu implementation. History subtitles and selection values remain supported.
- Render action/history menus in the modal overlay above navigation titles, anchored at the trigger edge. Add bounded bowed travel to root menu morphs; translation follows expansion progress and returns exactly to the destination edge with no independent settling timer. General fluid primitives retain straight travel unless configured.

- Compact menus to 36px minimum single-line rows with 8px horizontal/6px vertical padding and content-sized 180–280px default widths. Root menus omit their heading; submenu return titles remain selectable. Above-anchor and nested menus use their measured height to remain attached and visible near screen edges.
- Start menu travel directly on release, reduce press expansion and spring overshoot through menu tokens, and match neutral kit trigger fill/outline to the menu with one chrome owner. Existing general-purpose fluid motion keeps its defaults.

- Fix anchored menus overlapping navigation titles: open below the trigger with a token gap, using the space above when needed. `UiMenuStack.rootMenuBounds` separates expanded layout from the trigger animation area (OMA-42).

- Consolidate all menu rendering behind `UiDropdownMenu`, `UiMenuStack` and `UiMenuTransition`. Existing `UiDropdownMenu` constructors, models and imports require no edits; `UiFluidMenuButton`, `UiFluidMenuStack`, `UiFluidMenuTransition` and their import paths remain compatibility adapters/aliases.
- Add `UiMenuTokens` through `UiThemeData` and `UiThemeTokens` for menu surface opacity, outline, blur, parent scale/scrim, size, icon size and submenu timing. Shared surface blur honors the effects budget. Menu icons inherit the label's normal, destructive or disabled token color in both themes.

- Fix fluid submenu header taps accidentally triggering outside dismissal; keep closing geometry above the trigger's minimum dimensions to prevent title clipping (OMA-42).

- Normalize menu dismissal: outside taps consume by default, ancestor scrolling dismisses by default, nested actions dismiss before callbacks, and Back/keyboard navigation are supported. Use `consumeOutsideTap: false` and `UiMenuScrollBehavior.followAnchor` for intentional non-modal/persistent menus.
- Fix rapid fluid-menu Back reopening closing pages; shorten menu-only closing to 280 ms and remove the touch-restored trigger highlight (OMA-42).

- Added a dedicated fluid menu transition with content-sized geometry, stable-size clipped rows, and coordinated merging into the parent (OMA-42).

- Fixed fluid submenu reversal exposing a duplicate trigger: row content now has one rendering owner throughout the closing spring (OMA-42).
- Deprecate `UiFluidMenuStack.blurSigma` in favor of `scrimOpacity`; removal scheduled for 1.0.0. Nested menus now use a semi-transparent black shade over covered parents.

- Added experimental stacked fluid nested menus with 96% parent scale, scoped parent scrims, clipped background blur, and immediately reversible navigation (OMA-42).

- Added experimental fluid surface morph and split/merge primitives with shared clipped content rendering (OMA-38).

- Add `UiOtpInput` with grouped code slots, numeric/alphanumeric editing, paste and one-time-code autofill, token-driven states, and accessible single-field semantics.

## 0.9.0 - 2026-09-05

### Form capabilities
- Add `UiMultiSelect<T>` with searchable lazy options, removable selections, keyboard controls, limits, disabled values, and localized announcements. Add a runnable form composition example.
- Add `UiFormController`, typed field controllers, text/custom field adapters, and error summaries. Async validation rejects stale results and submission preserves edits made during saving. Existing `UiFormSubmitController` remains compatible.

### Fixed
- Preserve compact single-line input text insets as text scales. Embedded and multiline controls retain their existing spacing contracts.
- Input, slider, and rating share field presentation with a single localized live error announcement.
- Tooltips follow their anchors and remain within narrow overlays; date-picker navigation and mode announcements are localized.
- Preserve the selected gallery item when media changes, keep empty galleries dismissible,
  and constrain double-tap zoom to the configured range.
- Report the final slider value consistently and support RTL pointer, paint, and keyboard input.
- Suppress button press scaling when reduced motion is enabled.
- Give alerts one spoken copy owner, localize alert/date/table defaults, and expose tooltips on focus.
- Use 48-pixel rating targets and mirror partial star fills in RTL.
- Stack optional page panes when they would crowd out the body; reflow showcase actions and schedule details at large text sizes.
- Run example tests, including the light/dark responsive text-scale matrix, in the required CI gate.


### Compatibility

- Correct the supported SDK floor to the verified Flutter 3.47.0 / Dart 3.13.0
  toolchain. CI checks this minimum and current stable. Earlier declared SDK
  versions do not support APIs already used by the package. See ADR 0001.
- Retain all compatibility APIs through 0.x, with removal scheduled for 1.0.0:
  `UiTimePicker` → `UiTimeGridPicker` / `UiTimePickerField`;
  `components/schedule.dart` → `components/calendar.dart`;
  `UiNavigationSurface.blurred` and `UiNavigationSpec.blurSigma` → `edgeFade`;
  `UiStickyRegionSurface.glass` → `edgeFade`;
  `UiOpenContainer.backdropBlurSigma` → `backdrop` / `UiContainerBackdropSpec`;
  `UiRefreshIndicator.showLabel` → a custom `UiRefreshIndicatorBuilder`;
  omit the ignored `UiStackedOverlaySurface.implicitScaleAnimation` flag.

### Added

- Separate success/warning foreground color tokens for readable tinted surfaces.
- Compatible English/Arabic localization hooks for alert, table, rating, slider,
  and calendar text.

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
