# Stacked menus

[OMA-42](https://linear.app/omar-yacop/issue/OMA-42/add-stacked-fluid-nested-menus)
adds `UiMenuStack` on top of the accepted fluid surface primitives.

Import `package:open_ui_kit/open_ui_kit.dart` or the focused menu barrel.
Provide a bounded viewport and existing `UiMenuItem`, `UiMenuSubmenu`,
`UiMenuGroup` and `UiMenuSeparator` nodes. Each submenu uses the selected row
as the source geometry for `UiMenuTransition`. Covered parents retain their content,
scroll controllers and focus nodes, scale to `parentScale` (default 0.96), and
receive a semi-transparent black shade over their surface. Submenus cast no
shadow; the root alone is unshaded. All menu surfaces blur the background
through their translucent fill, clipped to the moving rounded outline; their own
text remains sharp. `surfaceOpacity` defaults to 0.92 so the filtered backdrop
remains visible; set it to 1 for an opaque surface. `backdropBlurSigma` defaults to 16; set it to zero to disable.
Reduced motion also disables background blur. Back/Escape restores the previous level;
Up/Down and Tab move focus through its actions. Depth starts at one.

Only the front page exposes its actions to input and accessibility while open.
Tapping an exposed part of a covered parent closes all descendants of that parent;
the same tap does not execute a parent action or its Back control. These targets
follow each animated outline and parent scale, and count as inside-menu taps. On Back,
the parent becomes interactive immediately when closing starts, without
waiting for content fading or geometry to settle. The submenu starts at the selected row position and expands into the space below.
Its shared title stays at the trigger position while the body content transitions,
so closing returns the title to the row without an empty surface stage. Its trigger can reverse that same submenu. Visible submenu
content can be used before its motion settles. Back closes the current logical
level; repeated Back skips outgoing pages and never reopens them. The parent
trigger can still explicitly reopen its submenu during closing. Closing uses
`closeDuration` (280 ms by default), independently of the accepted opening motion. Disabled/loading items cannot activate; asynchronous callbacks block
repeated activation until they complete. `onSelected` reports completed actions;
`closeOnSelect` defaults to true and requests dismissal before the action runs. `onDepthChanged`
reports pushes and completed pops. Replacing the root title/items resets the stack.

This is a menu-content composition, not a root popup/route replacement: the caller
owns root placement and removal. Connect `onDismiss` to close that overlay.
Outside taps, root Back/Escape, and selected actions request dismissal. Without
`onDismiss` or root presentation properties, the bounded stack returns to its root page. Ancestor scrolling also
requests dismissal by default (`dismissOnAncestorScroll`); internal menu scrolling
does not. The scrim uses local foreground paint.
`scrimOpacity` controls its opacity (default 0.24);
controller operations honor reduced motion. Customize `backLabel` for localization.

Verification covers nested navigation, 96% parent scale, keyboard dismissal,
disabled rows, reduced motion and narrow RTL layouts with larger text. The accepted
More and split/merge primitives retain their behavior.

Nested transitions start directly at the expansion phase, with no cloned row label
or extra press/contraction prelude. Parent scale follows the submenu geometry spring,
including retargeting, rather than the slower raw animation clock.

`blurSigma` is retained as an ignored compatibility parameter and deprecated in favor
of `scrimOpacity`, with removal scheduled for 1.0.0.

The selected row transfers its visible content to the morph until closing finishes.
Touch focus restoration does not leave a selected-row background; keyboard focus
remains visible. Its parent keeps an unpainted slot of the same size, with focus and hit testing
retained for immediate reversal. The promoted header owns the label, leading
widget, and rotating chevron; it returns them to the row in one handoff, without
a second trigger or highlight beneath the closing spring.

Nested menu presentation uses its own composition over the shared fluid geometry
and controller. Content is measured at its destination width; menu height fits
that content up to the viewport limit, then scrolls. Rows retain their size while
the rounded outline clips them progressively. Fill and background blur decrease
faster than contraction so the remaining clip returns into the parent without
a distinct compact floating surface. Standalone V13 morph behavior is unchanged.

The promoted header participates in the same outside-tap group as every menu body.
Pointer Back closes exactly one logical level, including rapid successive taps.
Opening retains the elastic spring; closing uses a monotonic ease-out curve shared
with parent restoration. Its clip never shrinks below the source row dimensions,
so the title cannot be cropped by a closing undershoot.

The example presents the root through the accepted More morph. Supply
`rootController`, `rootSourceGeometry` (in viewport coordinates), and `rootTrigger`
together to enable this composition; the caller disposes the controller. Destination
bounds still come from measured root content. Outside dismissal and root Back close
the root controller. Nested pages retain their geometry and leave with the root's
content fade instead of independently returning to every trigger. At the compact
endpoint, nested pages are discarded so the next presentation starts at the root.
An `onDismiss` callback can observe that request; keep the widget mounted until the
root transition completes. Placement and any surrounding modal barrier remain the
caller's responsibility. Submenu Back remains a one-level transition.

Hold the More trigger to open without lifting the pointer. While held, drag over
visible enabled entries to highlight them; release an action to execute it once.
Resting over a submenu opens it after `submenuDwellDuration` (350 ms by default).
Moving away cancels that dwell. Holding a submenu directly also opens it. The
shared title is a Back entry: drag onto it and release to return one level.
Releasing over menu chrome leaves the menu open; releasing outside dismisses it.
Pointer cancellation never selects. Long menus scroll while a held pointer rests
near the visible scroll edges. Ordinary taps and scrolling without a hold retain
their existing behavior. Hit testing follows actual clipped, transformed surfaces.

When closing several levels, descendant layers (including their promoted title
rows) fade with their closing ancestor's content instead of persisting until
page disposal. Once an ancestor reaches its trigger, its entire outgoing branch
is removed together.

For table/list action buttons, use `UiDropdownMenu(title: ..., trigger: ...,
items: ...)`. It owns the root controller, captured-theme overlay, safe-screen
placement, focus return and route Back forwarding. The press remains attached to
the original anchor while `UiMenuGestureController` forwards its held pointer
into the popup. Ancestor scrolling removes a row's popup immediately; scrolling
inside the popup keeps it open. A completed close restores the original trigger.

Menus use a 0.5-logical-pixel outline at 18% foreground opacity. It follows the
moving rounded boundary and merges away with submenu surface separation on close.

## Canonical API and theme

`UiDropdownMenu` is the single anchored menu implementation. Existing constructors,
menu node models, focused imports and behavior options continue to work without
source edits. The old `UiFluidMenu*` types/imports delegate to the canonical menu
API; they do not retain a second renderer. The lower-level `UiFluid*` surface and
motion primitives still describe shared morph/split physics, independent of menus.

Customize all menus through `UiThemeData.light(menu: UiMenuTokens(...))` and
`UiThemeData.dark(menu: UiMenuTokens(...))`, or `tokens.copyWith(menu: ...)`.
Menu overrides on `UiMenuStack` take precedence over theme defaults. Colors,
spacing, corner radii and typography come from the shared token families; icons
inherit the row label's resolved color. Explicit icon colors remain caller-owned.
Backdrop blur respects `UiEffectsTokens` and reduced motion. Menu opening retargets the current pressed geometry directly to the destination.
`pressExpansion` (0.15) scales press feedback and `springStrength` (0.25) scales
overshoot; standalone fluid primitives retain their original defaults. Menu closing
and dwell timing also resolve from `UiMenuTokens`.

For anchored menus, outside taps consume by default. Set `consumeOutsideTap: false`
for intentional table/list passthrough. Use `minWidth`/`maxWidth` (equal values for
fixed width), `title` for an optional spoken trigger label, and `backLabel` for return semantics.
