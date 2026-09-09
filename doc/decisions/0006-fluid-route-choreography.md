# ADR 0006: Drive routes and sheets from the fluid sampler

- Status: Proposed
- Date: 2026-09-07
- Extends: [ADR 0003](0003-fluid-surface-choreography.md)

## Context

ADR 0003 introduced the fluid morph as a rendering primitive whose single raw clock
drives geometry, clipping and content. The kit's page routes, iOS zoom container and
modal sheets still used curve-based tweens or slides, so a button that morphs into a
menu and a card that opens a page read as two different systems. Routes also differ
from the menu: there is no held press, the destination is the full viewport, and an
edge swipe or sheet drag scrubs the route controller directly.

## Decision

Add an externally clocked sampler, `UiFluidRouteMotion`, that maps a route's `0..1`
progress onto the expansion part of the accepted morph (no press expansion, a light
`.9` gather, `.12` spring strength) and clamps every rect inside the viewport with a
positive size. Closing and any user gesture sample a monotonic ease so geometry never
overshoots under the finger or re-exposes the source before landing. Three consumers
share it and stay experimental and additive:

- `UiContainerTransformStyle.fluidZoom` keeps the iOS zoom Hero rig; the Hero rect
  tween and shuttle sample the same frame, corners clip through `UiCornerClip`.
- `UiFluidPageRoute` is a `PageRoute` with `UiCupertinoBackGestureMixin` whose scrim,
  source copy and destination `UiFluidSurface` live inside `buildTransitions`.
- `showUiFluidSheet` measures bottom-anchored sheet content after its first frame,
  joins source and sheet with the split's `fluidBridgePath` neck while apart, and maps
  drag-to-dismiss onto the route controller with `_SheetHost`'s fling/threshold.

## Alternatives considered

Retuning `UiPageRoute`'s curves would not produce a shared outline between source and
page. A separate spring simulation per route would drift from the menu's clock and
would need its own reduced-motion handling. Reusing `UiFluidController` inside routes
would duplicate the navigator's controller and break gesture scrubbing.

## Consequences

Apps opt in per call site; `iosZoom`, `UiPageRoute` and `UiSheetScope.show` are
unchanged. `UiContainerPreview` pairs cross-fade instead of flying under `fluidZoom`.
Sheet keyboard changes are followed but not animated. Timing is authored (612 ms open,
480 ms close) and collapses to zero under reduced motion through `UiMotionDuration`.

## Verification

Geometry samples over several source rects and both directions, push/pop and
open/dismiss widget tests without exceptions, hidden-source and reduced-motion checks,
layer-boundary and existing container-transform/page-route suites. No golden baseline
changes.
