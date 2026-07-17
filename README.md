# Open UI Kit

Foundation-first Flutter UI kit inspired by shadcn/ui. Neutral defaults,
selective brand color use, and composable primitives that stay decoupled
from Material/Cupertino styling.

Created and maintained by [Omar Yacop](https://github.com/OmarYacop).

## Installation

```bash
flutter pub add open_ui_kit
```

Then import the public library:

```dart
import 'package:open_ui_kit/open_ui_kit.dart';
```

## Structure

- `lib/src/foundation` — design tokens, theme extension, low-level primitives.
- `lib/src/components` — reusable forms, feedback, overlay, data display, navigation widgets.
- `lib/src/patterns` — feature-level compositions (chat, layout).

## Concepts

### Tokens

All colors, spacing, radii, typography, and motion are token-driven.
Tokens live in `lib/src/foundation/tokens` and are aggregated into the
`UiThemeTokens` theme extension.

### Variants

Interactive components share a three-axis variant model:

- **intent** — `UiIntent.defaultIntent`, `neutral`, `primary`, `secondary`, `danger`, `ghost`, `link`.
- **size** — `UiSize.sm`, `md`, `lg`.
- **state** — resolved internally via `UiPressable` (hovered, focused, pressed, disabled, loading).

Only `primary`, `secondary`, and `danger` surface brand color; everything
else stays neutral by default.

#### Button intent semantics

For `UiButton`, `UiIntent.defaultIntent` is a **button-local alias of
`UiIntent.primary`** — an unspecified button intent renders as the
primary call-to-action. This matches the convention used by shadcn/ui
and most modern design systems: the "default" button is the primary
action, not a neutral chip.

If you need the previous neutral / outlined look (surface fill +
border, muted foreground), use the explicit `UiIntent.neutral` variant:

```dart
UiButton(
  label: 'Dismiss',
  intent: UiIntent.neutral, // surface + 1pt border, muted fg
  onPressed: () => Navigator.of(context).maybePop(),
);
```

This alias is **button-local**. `UiBadge` and `UiToast` still resolve
`UiIntent.defaultIntent` to a neutral surface — their "default" stays
calm on purpose.

##### Migration notes

- Existing `UiButton(label: 'x')` (no intent) call sites will flip
  from a neutral/outlined look to a primary fill. Audit and pick:
  - keep it (it was probably the primary action anyway), or
  - pass `intent: UiIntent.neutral` to preserve the old visual.
- No enum values were removed — all existing code compiles.
- `UiBadge` and `UiToast` defaults are unchanged.

## Usage

### 1. Apply the theme extension

```dart
import 'package:flutter/material.dart';
import 'package:open_ui_kit/open_ui_kit.dart';

void main() {
  runApp(
    MaterialApp(
      theme: UiThemeData.light(),
      darkTheme: UiThemeData.dark(),
      home: const MyHome(),
    ),
  );
}
```

Resolve tokens anywhere:

```dart
final tokens = UiThemeTokens.of(context);
final primary = tokens.colors.primary;
final gap = tokens.spacing.x4;
```

### 2. Render a button

```dart
UiButton(
  label: 'Save changes',
  intent: UiIntent.primary,
  size: UiSize.md,
  leading: Icon(Icons.check),
  onPressed: () => save(),
);
```

Loading, disabled, hover, and focus states are handled automatically.

Icon-only actions use `UiIconButton` so the visible icon still has a
semantic label:

```dart
UiIconButton(
  icon: const Icon(Icons.more_vert_rounded),
  semanticsLabel: 'More actions',
  borderRadius: BorderRadius.circular(999),
  onPressed: openMenu,
)
```

### 3. Render an input with validation

```dart
final emailKey = GlobalKey<UiInputState>();

UiInput(
  key: emailKey,
  label: 'Email',
  hint: 'you@example.com',
  helper: 'We never share this.',
  validator: (v) => v.contains('@') ? null : 'Invalid email',
);

// Later:
if (emailKey.currentState!.validate()) submit();
```

Selectable filter chips use the same tokens and keyboard handling as other
form controls:

```dart
UiFilterChip(
  label: 'Completed',
  selected: selectedStatuses.contains('completed'),
  onSelected: (selected) => toggleStatus('completed'),
)
```

### 4. Render a card

```dart
UiCard(
  variant: UiCardVariant.elevated,
  header: const UiCardHeader(
    title: 'Weekly summary',
    subtitle: 'Past 7 days',
  ),
  child: const UiText('Everything looks healthy.'),
);
```

### 4b. Render an avatar

```dart
UiAvatar(
  name: 'Ada Lovelace',
  imageUrl: user.imageLink,
  size: 40,
);

UiAvatarGroup(
  items: [
    UiAvatarEntry(name: 'Ada Lovelace', imageUrl: ada.imageLink),
    UiAvatarEntry(name: 'Grace Hopper', imageUrl: grace.imageLink),
  ],
  maxVisible: 3,
)
```

Media previews centralize remote image fallback surfaces:

```dart
UiMediaPreview(
  imageUrl: item.thumbnail,
  backgroundColor: itemColor.withAlpha(26),
  fallbackBackgroundColor: itemColor.withAlpha(46),
  fallback: Icon(itemIcon, color: itemColor),
)
```

### 4c. Render a status badge

```dart
UiBadge(
  label: 'Active',
  color: statusColor,
  leading: const Icon(Icons.check_rounded),
)

UiBadge(
  label: '42.00',
  backgroundColor: Colors.white.withAlpha(52),
  foregroundColor: Colors.white,
  borderRadius: BorderRadius.circular(6),
)
```

### 5. Compose a chat surface

```dart
UiAppShell(
  topBar: const UiAppBar(title: 'Chat'),
  bottomBar: UiChatComposer(onSend: controller.send),
  body: ListView(
    children: const [
      UiMessageBubble(
        author: UiMessageAuthor.incoming,
        text: 'Hey!',
      ),
      UiMessageBubble(
        author: UiMessageAuthor.outgoing,
        text: 'Hi',
      ),
    ],
  ),
);
```

### 5b. Top-nav logo integration

```dart
const brand = UiBrand(
  id: 'acme',
  displayName: 'Acme Learning',
  primary: Color(0xFF2451FF),
  onPrimary: Color(0xFFFFFFFF),
  logo: Image(image: AssetImage('assets/brand/logo_light.png')),
  darkLogo: Image(image: AssetImage('assets/brand/logo_dark.png')),
);

UiAppBar(
  title: 'Courses',
  brand: brand, // resolves logo/darkLogo by brightness
);

UiSliverNavigationBar(
  spec: UiNavigationSpec(
    title: 'Library',
    brand: brand,
  ),
);
```

### 6. Show a toast or dialog

```dart
UiToastOverlay.show(
  context,
  toast: const UiToast(
    message: 'Saved',
    intent: UiIntent.primary,
  ),
);

final ok = await UiDialogScope.confirm(
  context,
  title: 'Delete file?',
  description: 'This cannot be undone.',
  confirmIntent: UiIntent.danger,
);
```

## Environment Widgets

Environment widgets own page-level concerns: safe insets, soft-keyboard
handling, background surface, and OS status/navigation bar icon
contrast. Prefer them at the page root instead of reaching for a
`Scaffold` + `SafeArea` + `AnnotatedRegion` combo by hand — the kit
keeps the wiring consistent across screens.

| Widget | Use it for |
|---|---|
| `UiPageScaffold` | Page root. Background, top/bottom bars, safe viewport, system bars. |
| `UiSafeViewport` | Embedded page-like subtrees (sheets, cards) that need their own inset policy. |
| `UiSystemBars` | Scope that wants to control status/navigation icon contrast without a new page. |
| `UiSurfaceRegion` | Sectional surface (hero header, banner) that optionally syncs system bars. |

### 7. `UiPageScaffold` basic usage

```dart
UiPageScaffold(
  topBar: const UiAppBar(title: 'Inbox'),
  body: ListView(children: items),
)
```

### 7b. Semantic page layout

Use `UiPageLayout` when a screen is made from common page parts and the
kit should own their responsive placement. Actions stay in the page
chrome, filters move from a compact top section to a wide left pane, and
secondary content becomes a wide right pane.

```dart
UiPageLayout(
  title: 'Sessions',
  actions: [
    UiButton(label: 'Refresh', onPressed: refresh),
  ],
  filters: SessionFilters(onChanged: applyFilters),
  body: SessionList(sessions: sessions),
  secondary: SessionInspector(session: selected),
)
```

### 7c. Semantic form page

Use `UiFormPage` for common centered forms. The page owns the chrome,
max-width form column, field spacing, footer copy, and bottom actions.

```dart
UiFormPage(
  title: 'Reset password',
  hero: ResetPasswordIllustration(),
  children: [
    UiInput(label: 'Phone', controller: phoneController),
  ],
  footer: UiText('The verification code expires soon.'),
  actions: [
    UiButton(label: 'Send code', expand: true, onPressed: sendCode),
  ],
)
```

### 7d. Semantic collection page

Use `UiCollectionPage<T>` for list/grid screens with standard loading,
empty, and error states. The caller owns data fetching; the kit owns page
chrome and collection placement.

```dart
UiCollectionPage<SessionCard>(
  title: 'Sessions',
  onRefresh: refresh,
  items: sessions,
  loading: loading,
  loadingTitle: 'Loading sessions',
  error: failed,
  errorTitle: "Couldn't load sessions",
  errorDescription: failureMessage,
  emptyTitle: 'No sessions yet',
  itemBuilder: (context, session, index) {
    return SessionCardTile(session: session);
  },
)
```

### 7e. Pull to refresh

`UiRefresher` wraps any vertical scrollable, works with short content, and
uses the kit's color, radius, shadow, typography, and motion tokens. The
default indicator exposes pull, armed, refreshing, success, and failure
feedback; replace it through `indicatorBuilder` when a product needs a custom
visual. A controller makes the same refresh path available to buttons and
keyboard shortcuts.

```dart
final refreshController = UiRefresherController();

UiRefresher(
  controller: refreshController,
  onRefresh: repository.reload,
  child: ListView.builder(
    itemCount: items.length,
    itemBuilder: (_, index) => ItemTile(item: items[index]),
  ),
)

// Optional programmatic entry point; concurrent calls are coalesced.
await refreshController.refresh();
```

For sliver layouts, put `UiSliverRefresher` first and opt into the portable
refresh physics:

```dart
CustomScrollView(
  physics: UiRefresher.sliverPhysics,
  slivers: [
    UiSliverRefresher(onRefresh: repository.reload),
    const UiSliverNavigationBar(
      spec: UiNavigationSpec(title: 'Library'),
    ),
    SliverList.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => ItemTile(item: items[index]),
    ),
  ],
)
```

### 7f. Semantic settings list

Use `UiSettingsList` for grouped settings or account action menus. The
pattern owns section labels, row spacing, selected state for split-view
layouts, leading icon treatment, trailing labels, and footer copy.

```dart
UiSettingsList(
  selectedItemId: selected,
  onItemSelected: select,
  groups: [
    UiSettingsGroup(
      title: 'Account',
      items: [
        UiSettingsItem(
          id: 'devices',
          leading: Icon(Icons.devices_rounded),
          label: 'My devices',
        ),
        UiSettingsItem(
          leading: Icon(Icons.notifications_active_rounded),
          label: 'Notifications',
          description: 'Allow in-app notification delivery.',
          trailing: UiSwitch(value: enabled, onChanged: setEnabled),
          actions: [
            UiButton(label: 'System settings', onPressed: openSettings),
          ],
        ),
      ],
    ),
  ],
)
```

### 7g. Profile summary

Use `UiProfileSummary` for account headers, profile drawers, and person
detail summaries. It owns the tokenized avatar surface, image fallback,
name/subtitle typography, and optional action row.

```dart
UiProfileSummary(
  name: user.getFullName(context),
  subtitle: user.roleLabel,
  imageUrl: user.imageLink,
  actions: [
    UiButton(label: 'Edit profile', onPressed: editProfile),
  ],
)
```

Defaults are production-safe:

- Background comes from `UiThemeTokens.colors.background`.
- `safeViewportMode: UiSafeViewportMode.all` consumes top + bottom insets.
- `syncSystemBars: true` installs a `UiSystemBars` so the OS icons match
  the theme brightness.

### 8. Keyboard-aware form screen

Use `UiSafeViewportMode.keyboardAware` for screens that show the soft
keyboard — the home-indicator inset is added when the keyboard is down,
and the keyboard height replaces it when the keyboard is up (no double
stacking).

```dart
UiPageScaffold(
  topBar: const UiAppBar(title: 'New message'),
  safeViewportMode: UiSafeViewportMode.keyboardAware,
  body: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        UiInput(label: 'Subject'),
        SizedBox(height: 12),
        UiInput(label: 'Body', maxLines: 6),
      ],
    ),
  ),
  bottomBar: UiChatComposer(onSend: send),
)
```

### 9. Surface-driven system bars

Pass a `backgroundColor` — or just rely on the theme default — and
`UiSystemBars` picks icon brightness automatically so the OS icons stay
legible. For a full-bleed dark hero, `UiSurfaceRegion` scopes the
annotation to the region so the rest of the page keeps its own style.

```dart
UiPageScaffold(
  body: Column(
    children: [
      UiSurfaceRegion(
        background: tokens.colors.surfaceInverse,
        padding: EdgeInsets.all(24),
        syncSystemBars: true, // dark hero → light status icons
        child: UiText(
          'Today',
          variant: UiTextVariant.displayMd,
          tone: UiTextTone.inverse,
        ),
      ),
      Expanded(child: contentList),
    ],
  ),
)
```

If you need full control of the overlay style — say for a full-bleed
photo where auto-contrast would be wrong — pass an explicit
`systemOverlayStyle`:

```dart
UiPageScaffold(
  systemOverlayStyle: UiSystemBarsStyle.dark, // light icons
  body: fullBleedHero,
)
```

## Platform Components

V1 of the platform components program brings five production-ready
subsystems on top of the foundation + environment layers.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  UiPageScaffold / UiSafeViewport / UiSystemBars             │  environment
├─────────────────────────────────────────────────────────────┤
│  UiNavigationController  →  UiNavigationHost                │  navigation
│       ↑ UiRouteSpec<TArgs,TResult>                          │
├─────────────────────────────────────────────────────────────┤
│  UiBottomTabBar / UiSidebar / UiNavigationRail              │  navigation
├─────────────────────────────────────────────────────────────┤
│  UiSheet / UiDropdownMenu / UiDrawer                        │  surfaces
│  UiDatePicker / UiTimePicker / ...                          │  pickers
└─────────────────────────────────────────────────────────────┘
```

- **Navigation** is router-agnostic. `UiNavigationController` lives
  alongside go_router — host the kit inside a single route and keep
  route-level navigation in go_router until you're ready to migrate.
- **Navigation** components include bottom tabs, sidebars, and floating
  rails. They are app-shell primitives, not automatic Material/Cupertino
  adaptive switching.
- **Surfaces** (sheets, menus, drawers) use the root `Overlay`, so they
  work inside any `MaterialApp`/`WidgetsApp`.
- **Pickers** are sheet-friendly but plain widgets — drop them anywhere.

### Platform capabilities channel

Open UI Kit includes a small optional platform-capabilities layer for shell chrome
decisions such as floating-window mode. Native hosts that need this should
implement the `dev.open_ui_kit/platform_capabilities` method channel and return a
map compatible with `UiPlatformSnapshot`.

Current method names:

- `getPlatformSnapshot`
- `getWindowMode`

If the channel is absent or unsupported, Open UI Kit falls back to safe defaults so
components remain usable in tests, web, and basic Flutter hosts.

## Common Component Mappings

When replacing ad-hoc widgets with `open_ui_kit`, these mappings are useful
starting points:

- **Settings forms**: use `UiCheckbox`, `UiRadio<T>`, and
  `UiSwitch` for boolean/single-choice inputs.
- **Tabular pages**: use `UiDataTable` for token-driven layouts and row
  interactions.
- **Large list pages**: add `UiPagination` for predictable page
  navigation and loading transitions.

Example composition:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    UiCheckbox(
      label: 'Enable automatic updates',
      value: automaticUpdates,
      onChanged: (v) => setState(() => automaticUpdates = v),
    ),
    UiSwitch(
      label: 'Email notifications',
      value: notificationsEnabled,
      onChanged: (v) => setState(() => notificationsEnabled = v),
    ),
    UiDataTable(
      columns: const [
        UiDataColumn(label: 'Name'),
        UiDataColumn(label: 'Status'),
        UiDataColumn(label: 'Value', numeric: true),
      ],
      rows: dataRows,
      loading: isLoading,
      errorText: loadError,
      onRetry: refetch,
    ),
    UiPagination(
      currentPage: page,
      totalPages: totalPages,
      loading: isPageLoading,
      onPageChanged: (next) => setState(() => page = next),
    ),
  ],
)
```

### 10. Typed navigation with `UiNavigationController`

```dart
final home = UiRouteSpec<void, void>(
  id: 'home',
  title: 'Home',
  builder: (_, __) => const HomePage(),
);
final detail = UiRouteSpec<int, String>(
  id: 'detail',
  title: 'Detail',
  builder: (_, id) => DetailPage(id: id),
);

final controller = UiNavigationController(routes: [home, detail]);

// In your widget tree:
UiNavigationHost(controller: controller);

#### Edge-swipe-to-pop

`UiNavigationStack` is an `AnimatedSwitcher` — it intentionally does
**not** sit on Flutter's `Navigator`/`Route` system, so the iOS
edge-drag back gesture that ships with `CupertinoPageRoute` is NOT
available out of the box.

`UiNavigationHost` fills this gap. When the ambient platform is
**iOS or macOS** (default), a narrow leading-edge strip listens for
a horizontal drag and calls `controller.pop()` once the release
passes either a 64pt distance or a 400 pts/sec velocity threshold.
On other platforms the gesture is off by default (matching native
conventions — Android uses the back button/system back gesture).

```dart
// Force on/off regardless of platform:
UiNavigationHost(
  controller: controller,
  enableEdgeSwipePop: true,     // or false
);

// Tune the detection window:
UiNavigationHost(
  controller: controller,
  edgeSwipeWidth: 22,           // matches Cupertino default
  edgeSwipeMinDistance: 64,
  edgeSwipeMinVelocity: 400,
);
```

The gesture is **stack-aware**: at the stack root the edge strip is
inert, so a root-page list or horizontally-scrollable hero keeps
the full width for its own gestures. The strip is also **RTL-aware**
— in Arabic/Hebrew hosts the detector moves to the right edge and
inward-drag is measured leftward, so users get the same "drag from
the start edge" gesture without a separate code path.

#### Back-swipe transition style

The back-swipe gesture has two visual treatments, selected by
`backSwipeTransition` on `UiNavigationHost`:

- `UiBackSwipeTransition.cupertino` — full parallax: the outgoing
  page translates under the finger while the **previous route** is
  revealed underneath, starting offset by `-0.30 × viewportWidth`
  (reading-start edge) and settling at zero as the gesture
  completes. A leading-edge shadow on the outgoing page cues the
  elevation; a subtle scrim fades on the incoming page. Both routes
  are painted on an opaque backdrop (theme's page-background token)
  so pages that don't install their own `Scaffold`/`UiPageScaffold`
  still read as a slide rather than a cross-fade. Matches
  `CupertinoPageTransition` from Flutter's Cupertino library.
- `UiBackSwipeTransition.slide` — the outgoing page translates with
  the finger; the previous page is **not** rendered. Matches the
  native expectation on Android, where a Cupertino-style reveal
  would read as Apple-specific.
- `UiBackSwipeTransition.auto` (default) — resolves to `cupertino`
  on iOS/macOS and `slide` everywhere else.

```dart
// Platform-correct defaults — Cupertino on iOS/macOS, slide on
// Android/web/desktop:
UiNavigationHost(
  controller: controller,
  // backSwipeTransition: UiBackSwipeTransition.auto, // default
);

// Force Cupertino parallax regardless of platform (useful for
// demos or iPadOS-leaning apps on Android):
UiNavigationHost(
  controller: controller,
  backSwipeTransition: UiBackSwipeTransition.cupertino,
);

// Force slide-only (no parallax reveal):
UiNavigationHost(
  controller: controller,
  backSwipeTransition: UiBackSwipeTransition.slide,
);
```

**Interactive lifecycle**:

- No visual jump at gesture start — the gesture recogniser stops
  any in-flight release animation before taking over.
- Cancel (below distance + velocity threshold) — both pages
  animate back to their pre-gesture positions with the theme's
  standard motion curve.
- Complete (above threshold) — the outgoing page finishes its
  translate-off animation with the theme's fast motion curve, then
  `controller.pop()` commits the stack change. The drive resets
  silently so the new top page (the previously-revealed one)
  renders at its natural position with no snap-back.

Gesture tuning (`edgeSwipeWidth`, `edgeSwipeMinDistance`,
`edgeSwipeMinVelocity`) and platform gating (`enableEdgeSwipePop`)
apply to both visual treatments.

### 10b. Adaptive navigation for tablet/desktop

```dart
UiBottomTabBar(
  items: items,
  currentIndex: index,
  onChanged: onTabChanged,
  layout: UiBottomTabBarLayout.adaptive, // phone=edge, tablet=dock
);

UiTabs(
  tabs: tabs,
  value: selectedTab,
  onChanged: onTabSelected,
  layout: UiTabsLayout.adaptive, // phone=fill, tablet=intrinsic
);

UiResponsiveNavigationScaffold(
  body: body,
  sidebar: sidebar,
  secondary: desktopInspector,
  tabletSecondary: tabletInspector,
  bottomBar: bottomBar,
  showSecondaryOnTablet: true,
  showBottomBarOnTablet: false,
);
```

Full responsive audit and component-by-component guidance:
`doc/responsive_component_map.md`.

// From anywhere with access to the controller:
final note = await controller.push(detail, args: 42);
controller.popUntil('home');
controller.go(home);
```

The controller's stack is a `ValueListenable`, so widgets rebuild
declaratively. Its `historyItems()` feeds directly into a
`UiNavigationBackConfig.history` — long-pressing the back button on a
`UiSliverNavigationBar` pops a menu that lets the user jump back to any
prior screen.

### 11. Bottom sheets

```dart
final result = await UiSheetScope.show<bool>(
  context,
  snap: const UiSheetSnap.half(),
  builder: (ctx, controller) => UiSheet(
    header: const UiSheetHeader(title: 'Confirm'),
    child: const UiText('Are you sure?'),
    footer: UiSheetFooter(children: [
      UiButton(
        label: 'Cancel',
        intent: UiIntent.ghost,
        onPressed: () => controller.dismiss(false),
      ),
      UiButton(
        label: 'Delete',
        intent: UiIntent.danger,
        onPressed: () => controller.dismiss(true),
      ),
    ]),
  ),
);
```

Snap options: `fit` (natural), `half`, `full`, or
`UiSheetSnap.fraction(0.42)`. Drag-to-dismiss is on by default and
respects the soft keyboard.

#### 11b. Persistent (map/filter) sheets

For map- or list-overlay UIs (filter panels, search-results sheets)
where the host content must stay visible *and* interactive, use
`UiPersistentSheet`. It is **not** a Navigator route and installs **no
modal barrier** — background taps and gestures flow through to the
host as long as they land outside the sheet bounds.

```dart
final sheet = UiPersistentSheetController(initialIndex: 0);

Stack(
  children: [
    MapView(),                    // stays interactive under the sheet
    Positioned.fill(
      child: UiPersistentSheet(
        controller: sheet,
        snaps: const [
          UiSheetSnap.fraction(0.20), // peek
          UiSheetSnap.fraction(0.50), // half
          UiSheetSnap.fraction(0.92), // full
        ],
        allowClose: false,
        child: UiSheet(
          header: const UiSheetHeader(title: 'Filters'),
          child: FilterForm(),
        ),
      ),
    ),
  ],
)

// Drive it imperatively:
sheet.expand();              // jump to last snap
sheet.collapse();            // back to first (peek)
sheet.snapTo(1);             // half
sheet.isExpanded;            // true when snapIndex > 0
```

**Snap behavior.** `snaps` is a non-empty list of fraction-based
`UiSheetSnap`s. Dragging past the midpoint between two neighbours
snaps to the further one; a fast fling (> 600 px/s) biases one snap
further. `UiSheetSnap.fit` is rejected at this API — `fit` has no
drag-destination.

**Dismiss.** Set `allowClose: true` and pass `onClose` to let the
user swipe below the first snap to dismiss. The sheet does not
self-remove — the host owns the visibility flag (mount/unmount the
widget yourself).

**Blocking host interaction at large snaps.** If the sheet covers
most of the screen at its largest snap and you want to prevent
misclicks in the (now tiny) background strip, wrap your host body in
an `AbsorbPointer` gated on `controller.isExpanded`. The kit does
not impose a scrim — that decision is host-specific.

**Lifecycle.** Either pass a controller you dispose yourself, or omit
it and let the sheet create + dispose an internal one. Do not mix
the two.

### 11c. Collapsible primitive

`UiCollapsible` is a composable expand/collapse primitive. Use it
for expandable menu sections, "Advanced options" panels, FAQ
accordions, inline filter drilldowns — anywhere you need to reveal
content in response to an action.

Three control modes are supported; pick whichever fits the caller:

```dart
// Uncontrolled — the widget owns state. Tap the header to toggle.
UiCollapsible(
  header: _MyRow(label: 'Advanced options'),
  initiallyExpanded: false,
  child: AdvancedOptionsForm(),
)

// Controlled — parent owns state; UiCollapsible fires the callback.
UiCollapsible(
  expanded: _open,
  onExpandedChanged: (v) => setState(() => _open = v),
  header: _Header(),
  child: _Panel(),
)

// Controller-driven — imperatively drive from outside.
final collapsible = UiCollapsibleController(initiallyExpanded: false);

UiCollapsible(
  controller: collapsible,
  header: _Header(),
  child: _Panel(),
)
// ...
collapsible.expand();     // or .collapse() / .toggle()
collapsible.addListener(() => log(collapsible.isExpanded));
```

**Composition.** The [header] is optional — omit it to animate a
region driven by an *external* trigger (tapping a button elsewhere
on the screen, a menu item, etc.). When a header is provided, the
widget wraps it in a `UiPressable`, so keyboard (Enter/Space),
focus ring, hover/press state, and a button-shaped semantics node
all come for free. Pass a `focusNode` to integrate with the host's
focus traversal.

**Semantics.** The header exposes the `expanded` accessibility
flag matching the current state, so VoiceOver/TalkBack announces
"Show details, collapsed / expanded." Pass `semanticsLabel` to
override the announced text.

**Lifecycle.** Either pass a `UiCollapsibleController` you dispose
yourself, or omit it and let the widget create + dispose an
internal one. Passing both `expanded` and `controller` is rejected
at construction time.

**maintainState.** By default the child is dropped from the tree
when fully collapsed, so form inputs and scroll offsets start
fresh next time. Pass `maintainState: true` to preserve the
subtree across collapse — useful when the child holds work-in-progress.

### 12. Dropdown menus

```dart
UiDropdownMenu(
  trigger: UiButton(label: 'More'),
  items: [
    UiMenuGroup(label: 'Actions', items: [
      UiMenuItem(
        label: 'Edit',
        leading: Icon(LucideIcons.pencil),
        shortcut: UiMenuShortcut('⌘E'),
        onPressed: () => edit(),
      ),
      UiMenuItem(
        label: 'Delete',
        destructive: true,
        onPressed: deletePost,
      ),
    ]),
    const UiMenuSeparator(),
    UiMenuItem(label: 'Report…', onPressed: report),
  ],
);
```

Keyboard-navigable (`↑`/`↓`/`Enter`/`Esc`), supports `loading`
spinners for async actions, and `closeOnSelect: false` for multi-pick
flows.

### 13. Bottom tabs

```dart
UiBottomTabScaffold(
  items: const [
    UiBottomTabItem(label: 'Home', icon: Icon(LucideIcons.house)),
    UiBottomTabItem(label: 'Inbox', icon: Icon(LucideIcons.inbox), badge: 3),
    UiBottomTabItem(label: 'Me', icon: Icon(LucideIcons.user)),
  ],
  pages: [HomePage(), InboxPage(), MePage()],
  currentIndex: index,
  onChanged: (i) => setState(() => index = i),
)
```

State is preserved across tab switches by default (IndexedStack). Pass
`preserveState: false` to rebuild tabs on activation.

### 14. Sidebar + responsive scaffold

```dart
UiResponsiveNavigationScaffold(
  sidebar: UiSidebar(items: [
    UiSidebarGroup(label: 'Main', items: [
      UiSidebarItem(label: 'Inbox', icon: Icon(LucideIcons.inbox),
          active: true, onPressed: () {}),
      UiSidebarItem(label: 'Archive', icon: Icon(LucideIcons.archive),
          onPressed: () {}),
    ]),
  ]),
  bottomBar: UiBottomTabBar(/* phone only */),
  body: content,
)
```

- `< 600dp` — phone layout (bottom bar only).
- `600–900dp` — tablet layout (sidebar + body).
- `>= 900dp` — desktop layout (sidebar + body + optional `secondary`).

For touch platforms, push a modal drawer via `UiDrawerScope.show`.

## Form factor + RTL + localization

### Form-factor classifier

`UiFormFactor` is the kit-wide classifier for `phone` / `tablet` /
`desktop`. It replaces per-widget re-implementations of the same
breakpoint logic. Defaults match Material 3 / HIG:

- `< 600dp` → phone
- `600..900dp` → tablet
- `>= 900dp` → desktop

Read it from any build context:

```dart
final form = uiFormFactorOf(context);
if (form == UiFormFactor.tablet) { /* ... */ }

// Custom breakpoints:
final form = uiFormFactorOf(
  context,
  breakpoints: const UiBreakpoints(phone: 480, desktop: 1024),
);
```

### Adaptation strategies via `UiAdaptive`

`UiAdaptive` is the declarative form of the three adaptation
strategies the kit uses:

```dart
// 1. Mode switching — different subtree per form factor.
UiAdaptive.mode(
  phone:   (_) => const _PhoneDrawer(),
  tablet:  (_) => const _TabletSidebar(),
  desktop: (_) => const _DesktopSidebar(),
);

// 2. Variant — same widget, different value.
UiAdaptive.variant<double>(
  phone: 16, tablet: 24, desktop: 32,
  builder: (_, pad) => Padding(padding: EdgeInsets.all(pad), child: body),
);

// 3. Section visibility — hide a subtree on a given form factor.
UiAdaptive.visible(
  phone: false, tablet: true, desktop: true,
  child: const _DetailPanel(),   // NOT built on phone
);
```

Missing entries in the `.mode` and `.variant` forms fall back to
smaller form factors, so a `phone:`-only builder still renders on
tablet/desktop.

### Localization

All user-facing strings inside the kit flow through `UiLocalizations`.
To localize, register the delegate:

```dart
MaterialApp(
  localizationsDelegates: const [
    ...GlobalMaterialLocalizations.delegates,
    UiLocalizations.delegate,          // ← kit strings
  ],
  supportedLocales: const [
    Locale('en'),
    Locale('ar'),
    // add your app's locales
  ],
)
```

Read from inside a component:

```dart
final s = UiLocalizations.of(context);
UiButton(label: s.back, onPressed: nav.pop);
```

`UiLocalizations.of(context)` never returns null — when no delegate
is installed, English defaults (`UiLocalizationsEn`) are used. This
keeps components working during bring-up and in minimal test
harnesses. Host apps extending the kit's string catalogue should
subclass `UiLocalizations`, ship their own delegate, and register it
**after** `UiLocalizations.delegate`; Flutter resolves to the most
specific match.

Two built-in locales ship with the kit so the RTL story is testable
out of the box: `UiLocalizationsEn` and `UiLocalizationsAr`.

### RTL helpers

Components should use `EdgeInsetsDirectional`, `AlignmentDirectional`,
and `Directionality.of(context)` rather than branching on locale
tags. Two conveniences live in `package:open_ui_kit/open_ui_kit.dart`:

```dart
if (uiIsRtl(context)) { /* ... */ }

// Direction-aware chevrons: "forwards in reading direction" rather
// than "right arrow"
Text(UiDirectionalGlyphs.forwards(context));
Text(UiDirectionalGlyphs.backwards(context));
```

### Localization follow-ups

The package provides the localization contract, form-factor helpers,
and direction-aware primitives. Remaining component-level string and
directionality work is tracked in
`doc/l10n_migration_matrix.md`.

### 15. Pickers

```dart
UiDatePicker(
  value: selectedDate,
  min: DateTime(2024, 1, 1),
  max: DateTime(2026, 12, 31),
  disabled: (d) => d.weekday == DateTime.sunday,
  onChanged: (d) => setState(() => selectedDate = d),
);

UiTimePicker(
  value: UiTimeValue(hour: 9, minute: 0),
  minuteStep: 5,
  onChanged: (t) => setState(() => time = t),
);
```

Ranges (`UiDateRangePicker`, `UiTimeRangePicker`, `UiDateTimeRangePicker`)
are composites of the above and emit typed `UiDateRange` /
`UiTimeRange` / `UiDateTimeRange` values.

#### Date picker — direct month/year selection

Tapping the header label on `UiDatePicker` cycles the visible grid:

```
days ──tap──▶ months ──tap──▶ years ──tap──▶ days
```

- The **month grid** shows a 3×4 layout of `Jan…Dec`; tapping a cell
  returns to the day grid on that month.
- The **year grid** shows a 3×4 layout of 12 years at a time; the
  header arrows paginate ±12 years while this view is active.
  Tapping a year returns to the month grid with the new year set.

The header label also works with VoiceOver/TalkBack — its semantics
node announces the current label plus the affordance hint
(`"April 2026, opens month picker"`), so assistive tech surfaces the
direct-navigation gesture.

Density: the picker's outer padding, row gap, and cell inset are
optimized so a month block fits in less vertical space
while keeping 32pt minimum tap targets on every cell.

#### Time picker — wheel rebuild isolation

`UiTimePicker` drives each wheel's active-item styling through a
`ValueNotifier<int>` + `ValueListenableBuilder`, so a fling rebuilds
only the one or two rows whose active/inactive state changed. The
parent picker widget does **not** `setState` on every wheel tick —
previously the fling was rebuilding the full picker subtree on every
snap, which was the visible scrolling lag on low-powered Android
devices.

`onChanged` still fires once per snapped value during a fling, so
host form state / dependent pickers see the full event stream — this
is a purely internal rendering optimization.

### 16. Integrating into an existing app

1. Add the package to the app's dependencies.
2. Adopt `UiThemeData` at the application root.
3. Replace screen scaffolds incrementally with `UiPageScaffold`.
4. Use `UiSheetScope.show` in place of Flutter's
   `showModalBottomSheet`. The return value + drag-dismiss behaviour
   match; a controller is injected so screens can close themselves.
5. Keep the app's router at the shell. Introduce `UiNavigationController`
   only inside screens that own a sub-stack (e.g. chat master/detail,
   settings flow). The two navigation layers can coexist.
6. When moving a screen from a Material toolbar to the sliver
   large-title bar, declare a `UiNavigationSpec` and render a
   `UiSliverNavigationBar` as the first sliver.

## Testing

```bash
flutter analyze
flutter test
flutter test test/goldens/async_states_golden_test.dart
flutter test test/goldens/core_components_golden_test.dart
```

### Golden tests (CI parity)

Golden snapshots run on a fixed host in CI: `macos-14`.

```bash
flutter test test/goldens/async_states_golden_test.dart
flutter test test/goldens/core_components_golden_test.dart
```

To refresh baselines intentionally:

```bash
flutter test test/goldens/async_states_golden_test.dart --update-goldens
flutter test test/goldens/core_components_golden_test.dart --update-goldens
```

Host policy:
- Goldens are enabled only on macOS hosts to avoid cross-OS raster/font drift.
- Non-macOS hosts skip the golden suite by design.

#### What goldens are (and when to update them)

Golden tests are **pixel-exact screenshots** of component compositions,
stored as PNGs under `test/goldens/goldens/`. Each test pumps a widget
tree into a fixed-size frame and asserts the rendered pixels match the
stored baseline.

They exist to catch *unintentional* visual drift:

- A token tweak silently changed a component's padding? The golden
  diff surfaces it.
- A refactor accidentally dropped a border or swapped a color? Golden
  fails loudly.
- Dark-mode regressions that are easy to miss in a quick manual check.

**A golden failure is signal, not noise.** Read the diff before you
update.

##### When to update goldens (and when NOT to)

Update baselines (`--update-goldens`) **only** when the visual change
is intentional and documented in the PR. Typical reasons:

- A design token was tuned (radius, spacing, surface).
- A component variant was intentionally restyled.
- A new variant was added to a fixture and you want it captured.

Do **not** update when:

- You're chasing red without reading the masked diff. The diff often
  reveals a real bug (missing border, wrong foreground, layout shift)
  you would otherwise ship.
- The failure is cross-host (Linux dev machine vs. macOS CI). Goldens
  are gated on macOS — don't regenerate on Linux.
- A flaky raster (font metrics, AA) — fix the fixture, don't bake the
  flake into the baseline.

##### Why goldens fail after an intentional UI change

When a component's rendering changes intentionally, the stored baseline is
by definition
stale. The test compares the old pixels to the new pixels and fails —
that failure is *expected* and *the reason goldens exist*. The PR
should:

1. Explain the visual change in words.
2. Regenerate the affected baselines with `--update-goldens`.
3. Commit the updated PNGs so reviewers can eyeball the diff in the
   PR UI.

If you change a component's visuals without updating its golden, CI
blocks the merge — on purpose.

Detailed quality protocol (matrix, golden policy, update flow, flake handling):
`doc/quality.md`.
