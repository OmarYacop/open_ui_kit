# Bottom navigation

`UiBottomTabScaffold` is the canonical application navigation shell. It defaults
to four compact icon slots and an expandable destination grid; labels appear
when expanded. The handle overlays the deck without affecting icon centering.
Extra rows stay stationary relative to the revealing surface.

```dart
UiBottomTabScaffold(
  items: items, // Give each item a stable id when persisting order.
  pages: pages,
  currentIndex: selectedIndex,
  onChanged: selectPage,
  drawerController: navigationOrder,
  bottomAccessory: pageSearch,
)
```

Use `UiExpandingBottomTabBar` directly for custom shells. The low-level
`UiBottomTabBar` and `UiPagedBottomTabBar` remain available for explicit layouts.
To retain the previous scaffold behavior, set
`overflowBehavior: UiBottomTabOverflowBehavior.drawer` and
`maxVisibleBottomItems: 3`. Manual bottom-item configurations and wide rails retain
their behavior.

## Theme controls

Configure geometry and motion through the shared theme:

```dart
final tokens = UiThemeData.light(
  bottomNavigation: UiBottomNavigationTokens.defaults.copyWith(
    selectionInset: 4,
    iconTitleGap: 10,
    minRowHeight: 82,
    wigglePeriod: const Duration(milliseconds: 240),
  ),
);
```

| Token | Default | Meaning |
| --- | --- | --- |
| `compactHeight` | 64 | Deck height, excluding bottom inset/accessory |
| `iconArea` / `iconSize` | 44 / 24 | Stable icon area and glyph size |
| `selectionInset` | 2 | Per-side inset, yielding a 40px selection surface |
| `iconTitleGap` | 10 | Gap below the centered glyph to the label box |
| `minRowHeight` | 82 | Row pitch; grows to accommodate scaled text |
| `gridHorizontalInset` | 6 | Per-side inset; remaining width is divided equally |
| `gridBottomPadding` | 12 | Space below destination rows |
| `editActionHeight` | 56 | Revealed area for the bottom-right check |
| `checkCornerInset` | 12 | Equal bottom/end check margins |
| `accessoryGap` | 8 | Space between dock and contextual accessory |
| `wigglePeriod` / `wiggleAngle` | 240ms / .022 radians | Editing rotation cycle/amplitude |
| `drawerDuration` / `reorderDuration` | 450ms / 180ms | Drawer and slot transition timing |

Colors, selected fill, type, radii and shadows use the existing shared palettes.
The old `UiExpandingBottomTabBar.compactHeight` constant remains the default
reference value; runtime layout reads the theme token. Outer margins are supplied
through scaffold/bar arguments.

## Ordering and accessibility

`UiBottomTabDrawerController` owns expanded/customizing state and an order of
stable IDs. Applications persist `order`; the kit filters removed IDs and appends
new IDs. Selecting a secondary destination temporarily displays it in the last
compact slot. Returning to a primary page restores that slot immediately. Selection
never writes `order`; the expanded grid always uses the saved order, and only
accepted edit-mode changes alter it.

Hold any destination to enter editing and lift it in one gesture. Neighbors shift
to preview insertion at the target slot. The source has no ghost; dropping commits
once, leaving the drawer cancels and restores order. The grid scrolls at its edges
for long lists. The accessible alternative selects a source and then a destination
position with two taps. F2 enters editing; Escape and the bottom-right check finish
editing. Semantic actions have labels. The host can own back handling using its
controller, otherwise the bar handles drawer dismissal itself.

The editing wiggle repaints cells independently of the fluid surface, uses small
phase differences, and stops under Reduce Motion. Keyboard focus outlines remain.
The dock stays anchored to the physical bottom edge while the search/accessory
follows keyboard geometry with hittable bounds above it.

The dock uses a reduced bottom gap rather than a full bottom safe-area spacer.
Its expanded bottom corners use a conservative window-corner envelope adjusted
for the outer gap; landscape side insets still constrain the width.
Native corner alignment uses portable window/safe-area geometry; the kit does not
query private hardware corner APIs. No physical-device performance claim is made
from widget tests or simulator screenshots alone.

Run the standalone canonical showcase with
`cd example && flutter run -t lib/bottom_navigation_main.dart`.
The earlier accessory showcase explicitly selects legacy mode to retain its
compatibility coverage and existing golden references.

## Drag surface

The visible handle stays a small pill, but the whole compact dock is a
translucent vertical-drag surface for the deck (the strip above the grid once
expanded). Tiles keep their tap, hold-to-customize and drag-to-reorder
gestures because the band never claims a pointer until it moves vertically past
touch slop; mouse pointers bypass the band so desktop reorder drags stay
immediate. The band is disabled while customizing or reordering.

Destination labels stay on one line inside a 4pt side inset and ellipsize
beyond that.

### Accessory press feedback

Compact accessory icon buttons delegate their neutral chrome to the dock.
Pressing grows the shared outer fill and outline by 14%, leaving the icon and
touch target in place; release/cancel returns smoothly and reduced motion keeps
the resting size. Accessory presence and search expansion use 20% of the normal
fluid settling overshoot. Other fluid components retain their existing response.

Tracked in [OMA-46](https://linear.app/omar-yacop/issue/OMA-46); LMS consumes the
shared behavior through [OMA-48](https://linear.app/omar-yacop/issue/OMA-48).
