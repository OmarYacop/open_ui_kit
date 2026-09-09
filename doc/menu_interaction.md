# Menu interaction policies

`UiDropdownMenu` is a transient action menu. Defaults:

- The root surface shares the trigger edge and paints in the modal layer above navigation titles. Short menus above a low trigger align by their measured height; long menus remain within safe bounds.
- Outside tap dismisses and consumes the tap, avoiding accidental activation behind it.
- Selecting an enabled action dismisses before the callback runs, including nested actions.
- System Back/Escape dismisses; Escape closes an expanded nested level first.
- Up/Down, Enter/Space, directional submenu arrows, and focus restoration support keyboard use.
- Scrolling an ancestor dismisses a row-anchored menu; scrolling inside a long menu keeps it open.
- Disabled/loading items cannot activate. Pending repeatable actions are protected against duplicate invocation.
- Root action hit targets use their final positions as soon as opening content appears. The surface keeps animating; taps and submenu navigation do not wait for spring completion. Closing and covered-page interaction rules remain unchanged.

`consumeOutsideTap: false` allows an outside gesture to also interact with a table or list.
`scrollBehavior: UiMenuScrollBehavior.followAnchor` explicitly preserves an anchored menu
while its ancestor scrolls. `closeOnSelect: false` is for intentional repeatable actions,
not a global default. `dismissOnTapOutside: false` is an explicit application exception.

`UiMenuStack` follows these action/outside/Back semantics within its bounded
composition. The caller removes its root overlay through `onDismiss`; without that
callback, dismissal returns the bounded demo to its root. See [fluid menus](fluid_menu_stack.md).
`rootMenuBounds` optionally reserves a separate area for expanded menus inside the animation viewport, keeping the original trigger visible throughout the morph.
Its opening starts directly from the current pressed geometry. Menu spring overshoot uses `springStrength` (0.25 by default), while `closeDuration` defaults to 280 ms.

## Sources and application decisions

Apple describes outside-tap dismissal and tap/hold-drag-release selection in
[Design with iOS pickers, menus and actions](https://developer.apple.com/videos/play/wwdc2020/10205/).
Apple documents default dismissal on selection and intentional repeatable-action
exceptions in [adaptive menus](https://developer.apple.com/documentation/swiftui/populating-swiftui-menus-with-adaptive-controls).
Android [PopupProperties](https://developer.android.com/reference/kotlin/androidx/compose/ui/window/PopupProperties)
defaults outside and Back dismissal to true; [Compose menus](https://developer.android.com/develop/ui/compose/components/menu)
retain internal scrolling for long menus.

Ancestor-scroll dismissal versus following a toolbar anchor is our explicit application
policy, not a claim that both platforms mandate one universal rule. The menu should not
retain an action context after the associated table/list row moves away.

## Compact presentation

Main menus render actions immediately, without a heading. Submenus retain their
clickable return title. Rows use a 36px minimum height, single-line ellipsis and
8px horizontal/6px vertical padding; text scaling can increase their height.
Surface padding is `spacing.x1` and corners use `radius.lg`. Default anchored
width is content-sized between 180 and 280px; explicit width constraints still win.

Neutral kit menu triggers share the menu fill and border before opening, with
one painted surface through the morph. Their nested button chrome is suppressed
only within the menu's composition scope. Custom trigger widgets retain their
own drawing. Press expansion is subtle, and release begins destination travel
without a separate grow–shrink prelude. Shared standalone morphs keep their defaults.

LMS action menus use dismiss-only outside taps: the dismissal tap does not also
execute a page action. Explicit `consumeOutsideTap: false` remains available for
applications that intentionally want passthrough. Ancestor-scroll dismissal and
inside-parent taps retain their existing behavior.

## Navigation history and curved travel

`UiNavigationBackButton` keeps its existing label/history/callback API. Short taps
invoke Back; long presses open the same `UiMenuStack` used by action menus. The
held pointer can select a history entry on release; subtitles and identity values
are preserved. Shift-F10 or Alt-Down opens history for keyboard users. History
selection releases the overlay's route blocker before applying a multi-pop.

Back and menu triggers use the pill radius token (circles for square controls).
`travelArc` bounds the menu's curved travel, with the bow following the same
geometric fraction as size. Root corners and stroke width use a shared monotonic progression. Its displacement and tangent are zero at
both endpoints; upward-opening menus mirror the bow into available space. The
lower menu spring remains in effect. This is a visual approximation of the supplied
slowed recording and sketch, not a claim to reproduce private UIKit equations.
Apple's public documentation describes matched geometry and capsule-shaped glass:
[Liquid Glass custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).


### Interactive button triggers

Use `triggerBuilder` when the trigger is a normal button. Connect the supplied
callback to the button so its own pointer, hover, focus and keyboard behavior stay
active. The button owns the long-press recognizer as well as tap, keyboard, focus and
semantics. A retained pointer route carries a recognized hold into the overlay.
The menu paints the moving surface only after opening.
Existing `trigger:` widgets remain supported without changes.

```dart
UiDropdownMenu(
  triggerBuilder: (context, open) => UiButton(
    label: 'Actions',
    intent: UiIntent.neutral,
    onPressed: open,
  ),
  items: [UiMenuItem(label: 'Edit', onPressed: edit)],
)
```

Navigation Back uses a 44px `UiIconButton` with a 24px direction-aware chevron,
or a labeled `UiButton` when `showLabel` is enabled. RTL reverses the chevron and
leading-content ordering; history placement and hold/drag behavior use the shared
menu's direction-aware layout.


Builder triggers retain their own painted surface: the anchor does not suppress
button backgrounds/borders or paint a fixed surface around them. Padding around
a button is not an extra menu hit target. Disabled buttons cannot open via a
wrapper tap or long press. For a round toolbar menu button, use `UiIconButton`
with `UiSize.lg`, the pill radius, and menu surface/outline tokens; its visible
44px surface then matches its 44px tap target. `UiIconButton.borderWidth` allows
the button outline to match the menu; `UiButton.borderRadius` also supports
rounded labeled triggers.

### Platform corner shapes

The default `UiCornerStyle.platform` uses rounded superellipses on iOS/macOS and
circular rounded rectangles elsewhere. Buttons using UiBox, focus outlines, menu
surfaces and their clips share this choice. Radius sizes and motion stay unchanged.
Force a consistent style across devices through the existing theme entry point:

```dart
UiThemeData.light(
  radius: UiRadiusTokens.standard.copyWith(
    cornerStyle: UiCornerStyle.continuous, // or circular
  ),
)
```

Use the same override for the dark theme. Native non-debug platform selection is
compiler-constant in Flutter; no device query, listener or build flag is required.
Web still resolves the browser's platform because the same build serves multiple
operating systems. Both renderers remain usable through the explicit override.
See [ADR 0004](decisions/0004-platform-corner-treatment.md) for scope and limits.


### Custom trigger corners

Set `sourceBorderRadius` to the same radius as the trigger. This describes the
source/return geometry; the expanded menu keeps its own token radius. Omission
preserves the previous pill default. Zero, asymmetric, elliptical and directional
corners are supported, with directional values resolved before animation.

```dart
final sourceRadius = UiThemeTokens.of(context).radius.mdAll;
UiDropdownMenu(
  sourceBorderRadius: sourceRadius,
  triggerBuilder: (context, open) => UiIconButton(
    icon: moreIcon,
    semanticsLabel: 'Actions',
    borderRadius: sourceRadius,
    onPressed: open,
  ),
  items: items,
)
```

### Per-menu placement and transition controls

`UiDropdownMenu` exposes the existing lower-level motion and surface controls:

```dart
UiDropdownMenu(
  destinationOffset: const Offset(0, 12),
  transitionDurationScale: 0.8,
  menuTokens: UiThemeTokens.menuOf(context).copyWith(
    springStrength: 0.15,
    travelArc: 16,
    closeDuration: const Duration(milliseconds: 220),
    backdropBlurSigma: 12,
  ),
  triggerBuilder: (context, open) => UiButton(
    label: 'Actions',
    onPressed: open,
  ),
  items: items,
)
```

`destinationOffset` uses physical logical pixels: positive x is right in both
LTR and RTL, positive y is down. It moves the destination placement anchor;
source/return geometry remains attached to the button. Safe-area and keyboard
bounds still apply, and placement may flip above/below when space changes.
Offsets near an edge can be constrained by available space.

`transitionDurationScale` scales the root press/open/close timeline together;
it must be finite and greater than zero. Submenu timing remains controlled by
the shared menu implementation. Reduced motion takes precedence.
`menuTokens` scopes existing menu tokens to this trigger, root and submenus,
including `pressExpansion`, `springStrength`, `travelArc`, `parentScale`,
`scrimOpacity`, `surfaceOpacity`, and `closeDuration`. Omit it to inherit the
theme; use the inherited tokens' `copyWith` to preserve customized defaults.
Changing the offset or duration scale closes an open menu; the next opening
uses the new placement/timing. `UiFluidMenuButton` supports the same options.

### Trigger-to-menu surface continuity

Builder-based `UiButton` and `UiIconButton` triggers hand their resolved painted
surface to the transition: fill, border, corners, shadow and visual bounds.
The animation starts at the current pressed geometry and returns to the resting
surface on dismissal. Icon content keeps its fixed visual size during the handoff.
The surrounding touch target and layout space are retained while the menu is open.
Menu fill, outline and blur interpolate from the trigger instead of replacing its
appearance on the first frame. `sourceBorderRadius` remains an explicit override.

Automatic capture applies to kit buttons supplied through `triggerBuilder`.
Arbitrary custom widgets and the legacy passive `trigger` path retain their
existing menu-owned surface behavior. Lower-level `UiMenuStack` callers can
provide `rootSourceColor`, `rootSourceBorder` and `rootSourceShadows`, with
optional initial pressed geometry/paint; `UiFluidMorph` exposes the corresponding
source styling controls for compositions outside anchored menus.

Pill radii are normalized to the painted trigger size before capturing a pressed
frame. Root morph corner radius and stroke width follow the same monotonic
progression, independently of the rectangle's spring overshoot. This avoids a
long pill-shaped plateau, late corner snap, or stroke/corner timing mismatch.

To keep a custom trigger outline unchanged throughout the attachment/menu morph,
set the expanded menu's outline as well as the button's:

```dart
menuTokens: tokens.menu.copyWith(
  borderColor: tokens.colors.border,
  borderWidth: 1,
),
```

`borderColor` uses the supplied alpha exactly; omission retains the default
foreground-derived `borderOpacity` treatment. Icon-button press growth keeps
its configured stroke width constant, so equal source/destination borders do
not acquire an intermediate thicker pressed stroke.
