# Open UI Kit Responsive Component Map

This map classifies every Open UI Kit component for phone vs tablet/desktop behavior,
and records adaptive actions for components that can feel awkward on wide layouts.

## Responsive Strategies

- **Mode switch**: dynamic switch between two component modes (phone vs tablet).
- **Visual variant**: same component, alternate wide-screen look.
- **Section visibility**: show/hide extra sections per form factor.

## Components Map

### Navigation

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiBottomTabBar` | Full-width bottom bar | Adaptive floating dock | Updated | Mode switch + visual variant |
| `UiBottomTabScaffold` | Tabs + page body | Tabs can use floating dock via pass-through config | Updated | Mode switch |
| `UiTabs` | Fill segmented control | Adaptive intrinsic-width segmented control | Updated | Mode switch |
| `UiResponsiveNavigationScaffold` | Body + bottom bar | Sidebar/secondary/bottom visibility toggles by form factor | Updated | Section visibility |
| `UiSidebar` | Optional/usually hidden | Primary tablet/desktop navigation | Good | Host composition |
| `UiSliverNavigationBar` | Good as compact/large title | Good; host controls title density/actions | Good | Host composition |

### Forms

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiButton` | Good | Good | Good | No change |
| `UiInput` | Good | Good (host controls width) | Good | Host composition |
| `UiSelect` | Good | Good (overlay width capped) | Good | Host composition |
| `UiCheckbox` | Good | Good | Good | No change |
| `UiRadio` | Good | Good | Good | No change |
| `UiSwitch` | Good | Good | Good | No change |

### Data Display

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiCard` | Good | Good | Good | No change |
| `UiPagination` | Good | Good (better with centered layouts) | Good | Host composition |
| `UiDataTable` | Good baseline | Good baseline | Good | Future: column features |

### Surfaces / Overlay

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiSheet` modal | Edge-to-edge | Adaptive max-width centering | Updated | Visual variant |
| `UiPersistentSheet` | Good | Good | Good | Host composition |
| `UiDrawer` | Good | Good | Good | Host composition |
| `UiDropdownMenu` | Good | Good | Good | No change |
| `UiDialog` | Good | Good | Good | No change |
| `UiToast` | Good | Good | Good | No change |

### Pickers

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiDatePicker` | Good | Good | Good | No change |
| `UiTimePicker` | Good | Good | Good | No change |
| `UiDateTime*` / `Range*` | Good | Good | Good | No change |

### Pattern Components

| Component | Phone | Tablet/Desktop | Status | Strategy |
| --- | --- | --- | --- | --- |
| `UiAppShell` / `UiAppBar` | Good | Good | Good | Host composition |
| `UiPageScaffold` / `UiSafeViewport` | Good | Good | Good | No change |
| Chat patterns (`UiChatComposer`, `UiMessageBubble`) | Good | Good with host max-width | Good | Host composition |

## New Adaptive APIs

- `UiSheetScope.show(maxWidth: double?)`: when non-null, the modal
  sheet is centred horizontally and clamped to that width. Leave
  null (default) for the legacy phone-style edge-to-edge layout.
- `UiSheetScope.adaptiveMaxWidth(context)`: returns `null` on
  phone, `560` on tablet, `720` on desktop. Drop-in one-liner for
  form-factor-aware sheets:

  ```dart
  UiSheetScope.show<T>(
    context,
    maxWidth: UiSheetScope.adaptiveMaxWidth(context),
    builder: (_, c) => UiSheet(...),
  );
  ```

- `UiBottomTabBar.layout`: `edgeToEdge`, `floatingDock`, `adaptive`
- `UiBottomTabBar` floating-dock sizing knobs:
  - `adaptiveBreakpoint`
  - `floatingMaxWidth`
  - `floatingHorizontalMargin`
  - `floatingBottomMargin`
- `UiBottomTabScaffold` forwards the same tab-bar adaptive options.
- `UiTabs.layout`: `fill`, `intrinsic`, `adaptive`
- `UiTabs` knobs:
  - `adaptiveBreakpoint`
  - `intrinsicMaxWidth`
- `UiResponsiveNavigationScaffold` visibility toggles:
  - `showSidebarOnPhone/tablet/desktop`
  - `showBottomBarOnTablet/desktop`
  - `showSecondaryOnTablet/desktop`
  - `tabletSecondary`

## Recommended Defaults

- For app-level navigation: use `UiBottomTabBarLayout.adaptive`.
- For section tabs inside tablet pages: use `UiTabsLayout.adaptive`.
- For shell composition: use `UiResponsiveNavigationScaffold` with
  `showSecondaryOnTablet: true` on data-dense tablet screens.
- For modal sheets: pass
  `maxWidth: UiSheetScope.adaptiveMaxWidth(context)` so the sheet
  stays a phone-sized card on tablet/desktop instead of spanning
  the full canvas.

## Adaptation Guidance

Classification used during the responsive component audit:

- **Good** — component already behaves correctly across form
  factors because it sizes to its parent, the host composes it
  inside a form-factor-aware layout (e.g.
  `UiResponsiveNavigationScaffold`), or it's a primitive with no
  intrinsic width/height bias.
- **Needs adaptation** — the component has phone-first assumptions
  that break on tablet/desktop. Fixed in this PR:
  - `UiSheet` modal: added opt-in `maxWidth` + `adaptiveMaxWidth`
    helper so the presentation centres on wide layouts.
- **Host composition required** — correct result depends on
  surrounding layout choices (max-width column for chat, sidebar
  wiring for drawers). Documented in this map; no component-level
  fix is appropriate.

Items that were reviewed and left unchanged because existing APIs
already cover the use case:

- `UiDialog` / `UiAlertDialog` — already clamp at `maxWidth: 420`,
  which reads correctly at all form factors.
- `UiDrawer` — `UiResponsiveNavigationScaffold` handles the
  phone-drawer / tablet-sidebar split.
- `UiTabs`, `UiBottomTabBar`, `UiBottomTabScaffold` — already
  expose adaptive layout enums.
- Pickers — card-sized components that sit inside host-owned
  columns; width is the caller's concern.
