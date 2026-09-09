# Experimental fluid motion

Tracked by [OMA-38](https://linear.app/omar-yacop/issue/OMA-38/implement-fluid-surface-morph-and-splitmerge-motion).

Import `package:open_ui_kit/open_ui_kit.dart`.

`UiFluidMorph` implements the accepted V13 choreography. `UiFluidSplit` implements
surface emergence and reunion. Both use `UiFluidGeometry`, `UiFluidController`,
and `UiFluidSurface`. These APIs are experimental and additive; existing Contour
and overlay components retain their behavior.

## Composition

Own a `UiFluidController(vsync: this)` in State and dispose it. Place the composition
in a bounded viewport. Supply source and destination rectangles in that viewport's
local coordinates, using `LayoutBuilder` for adaptive positions. Reserve space for
the small spring overshoot. Geometry must have finite, positive dimensions.

Use `UiFluidTrigger` to call `press`, `open`, and `cancelPress` with pointer, keyboard,
and semantic activation. Use the trigger as source content. Call `close(context)` to reverse from the current
frame. A controller belongs to one composition; do not share it between independently
interactive controls. Programmatic `open` includes the press phase.

The owner remains responsible for overlay insertion, focus restoration, escape/back
handling and dismissal. These widgets are rendering/interaction primitives, not
replacement menu or modal route APIs. When embedding in an overlay, retain the
viewport until the controller reaches zero; use existing kit overlay scopes for
modal semantics and focus management.

## Accepted morph timing

Press occupies progress `0–.2` and takes 122.4 ms. Release from a held press takes
612 ms. `durationScale` scales both together. `contraction` manually controls the
minimum size (default `.68`). The short center nudge overlaps contraction; every
geometry coordinate then uses the same bounded spring response and reaches its
endpoint together. No independent position correction is applied after expansion.

Destination content fades in during expansion, stays laid out at destination size,
and scales uniformly within the current rounded clip. `alignment` controls its
anchor (for example `Alignment.topRight` for a menu or `Alignment.bottomCenter` for
a sheet). Neither content layer reflows during a frame. Visible content can receive pointer events, keyboard focus and semantics during
motion; fully hidden layers cannot intercept input. Content remains mounted.

## Split and merge

Each `UiFluidBranch` describes a surface, not an action. A branch can contain a Row
of two actions while the retained source contains a third. The source remains at
its original geometry; branches interpolate outward on one spring clock. A painted
neck diminishes before separation. Reversing that timeline merges the branches.
This is a geometric interpretation of the reference, not an implementation of
Apple's renderer. No refraction, backdrop blur or shader is involved.

The split preset currently uses simultaneous branch motion and a stationary source;
there is no automatic layout solver or independent per-branch stagger. It works best
with non-overlapping destination rectangles. The morph's manually controlled
contraction intentionally does not apply to the split preset.

## Accessibility and verification

Controller operations resolve custom durations through `UiMotionDuration`, so
reduced-motion preferences jump to the requested endpoint. Supply meaningful labels
to `UiFluidTrigger` and to each action. Provide sufficient viewport space for large
text; clipping motion cannot make an undersized final layout accessible.

The focused tests sample geometry and content timing, verify reversal and reduced
motion, and exercise hidden-content input suppression. No golden baseline is changed.

## Retargeting and surface-owned chrome

Closing interpolates from the displayed frame to the source with a fresh response,
rather than rewinding the nearly stationary end of the opening spring. Interrupting
close with open captures the displayed geometry again, avoiding a position jump.
The original uninterrupted V13 opening stays unchanged. `controller.target` reports
the requested endpoint: use it for toggle actions instead of a progress threshold.

Split action content should use `UiPressable` with a label/icon, allowing the fluid
surface to own its fill and outline. Nesting a filled button adds a second background
and potentially clips its independent shape against the parent capsule. The retained
source stays interactive throughout; emerging branch actions activate as they appear.

Closing content hands off sequentially: expanded content disappears within the first
22% of the close, and the source label enters from 25–50%. The bridge's connection now depends on
the gap relative to surface size and remaining deformation strength. Near the
connection limit, its neck pinches into two separate rounded protrusions; these
retract into their surfaces instead of disappearing at a fixed cutoff. Reversal
uses the same geometry, so the protrusions approach before reconnecting.

The final retraction uses a squared strength envelope and converges onto the resting
circular arc, including its tangents. Its visible area reaches zero before the
renderer stops drawing, avoiding a disappearing residual protrusion.

## Experimental route and sheet choreography

Tracked by ADR 0006. Routes have no held press and their clock belongs to the
navigator, so `UiFluidRouteMotion` samples the accepted morph from an external
`0..1` progress: it skips press expansion, gathers to `.9`, springs with strength
`.12`, and clamps every rect inside the viewport with a positive size. Closing and
user gestures (edge swipe, sheet drag) sample a monotonic ease-out instead, so the
surface never overshoots under the finger; the scrim ramps over the first 20%.

- `UiOpenContainer(style: UiContainerTransformStyle.fluidZoom)` keeps the iOS zoom
  Hero rig. The Hero rect and the shuttle's corners and content cross-fade come from
  the same frame; corners use `UiCornerClip` from `iosSourceBorderRadius` to
  `iosScreenBorderRadius`. `UiContainerPreview` pairs cross-fade rather than fly.
- `UiFluidOpenContainer` and `context.pushUiFluidPage(builder, sourceKey: key)` push a
  `UiFluidPageRoute`: a non-opaque `PageRoute` with the iOS back gesture whose scrim,
  optional source copy and full-size destination `UiFluidSurface` are painted inside
  the transition. The closed child is hidden while its page is open, and the source
  rect is re-read while popping so the page returns to a moved source.
- `showUiFluidSheet(context, sourceKey: key, builder: ...)` and `UiFluidSheetAnchor`
  grow a bottom-anchored sheet (with `snap` and `maxWidth` like `UiSheetScope.show`)
  out of a button. The content is measured after its first frame, a `fluidBridgePath`
  neck joins the source and the emerging surface while they are apart during the
  first half, and dragging the sheet down scrubs the route controller with the same
  fling/threshold rules as the standard sheet.

Known limitations: the sheet follows the current keyboard inset but does not animate
keyboard changes while open; starting a back swipe before a push has landed switches
from the spring to the monotonic path without blending. Timing (612 ms open, 480 ms
close) resolves through `UiMotionDuration`, so reduced motion jumps to the endpoint.

### Drag to dismiss

`UiFluidPageRoute` wraps its page in `UiFluidDismissRegion`. A free-form drag
anywhere on the page carries it with the finger in any direction: it shrinks
toward half size, gains rounded corners and lifts on a shadow while the scrim
fades. Vertical lists keep scrolling, but a sideways pull or an over-scroll
past the top hands the page over (picking up the distance the list is already
rubber-banded). Releasing past 28% of the travel, or flinging outward, pops the
route; the reverse leg is a critically damped spring that starts from the
released frame with the finger's velocity toward the source, so motion never
restarts from rest. Shorter drags spring back in place the same way, without
touching the route animation.
