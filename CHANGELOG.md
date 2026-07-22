# Changelog

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
