# Contour: Open UI Kit's material, motion, and interaction language

Contour is Open UI Kit's own effects/material/motion/interaction system,
inspired by the *principles* behind Apple's Liquid Glass — but it is not a
visual clone, not an API clone, and does not use a shader, blur glow, or
material blend. **Spatial continuity comes from the movement and
transformation of the objects themselves, not from an optical effect layered
behind them.** It is built from the same tokens every other Open UI Kit
component uses: `UiThemeTokens`, `UiMotionTokens`/`UiMotionSpec`, and
`UiEffectsTokens`.

## History: the shader path was tried and retired

An earlier revision of this component painted a tinted, shader-blended glow
(`UiContourBlendMorph`/`ui_contour_blend.frag`) behind the trigger and
released actions, and drove geometry through a custom "physics" curve
(`UiContourPhysics.buildCurve()`). A design critique
(`.impeccable/critique/2026-08-19T10-42-37Z__example-lib-main-dart.md`) and a
runtime geometry probe found both were broken, not just under-tuned:

- **The glow modeled the wrong geometry.** It smooth-unioned the collapsed
  trigger rect with the *bounding rect of the entire expanded row*. Because
  one rect was nested inside the other, the union collapsed to a single
  large rounded rectangle — a flat tinted slab, not individual controls
  emerging from a source.
- **The curve conflated normalized progress with physical time.** It fed a
  `0..1` progress fraction directly into a damped-oscillator formula
  calibrated in seconds. With realistic stiffness/damping, the exponential
  decay term saturated within the first ~15% of *any* duration — the
  transition visually completed within ~30ms of a 200ms duration, then a
  tiny residual oscillation read as a recoil/wobble. This wasn't a tuning
  problem; treating a progress fraction as if it were elapsed seconds is
  categorically the wrong model.
- **Two duplicate `UiButton` instances were crossfaded** (via
  `UiMeasuredMorph`) rather than one persistent trigger surface, so the
  claimed "persistent identity" didn't actually hold — focus, semantics, and
  Element identity all flipped between two different widgets at the
  transition's midpoint.

All of that (the shader, the `.frag` file, the physics-driven curve, the
crossfaded pair) has been removed. Nothing described below depends on a
shader; the component looks complete with every advanced visual effect
disabled, because there are none — see [Anti-goals](#anti-goals).

## Anti-goals

- No shader, glow, halo, bloom, neon, tinted slab, or metaball smear behind
  the trigger or actions.
- No refraction, magnification, or optical distortion of arbitrary
  background content.
- No glass-everywhere material. A restrained surface may use existing
  tokens for fill, border, radius, and shadow — nothing invented locally.
- No generic spring/bounce curve for geometry. Geometry progress uses a
  plain, restrained curve resolved from `UiMotionSpec` — the same contract
  every other structural transition in the kit uses.
- No decorative motion under reduced motion. Every Contour transition
  collapses to an immediate, deterministic final state when
  `MediaQuery.disableAnimations` or the reduced effects tier is active.
- No unbounded horizontal action list — see
  [Responsive policy](#responsive-policy).

## Architectural rule

> **One state owner, one progress timeline, geometry computed as a pure
> function of that timeline — never through a curve that conflates
> normalized progress with physical time, and never through a second
> destination that is itself still animating.**

Concretely: exactly one `UiContourController` owns the transition's
[`UiContourPhase`](#state-machine) and `AnimationController`. Exactly one
`UiContourActionGeometrySolver.solve(...)` call, fed that controller's
`value`, produces every rectangle painted for a given frame — trigger and
every action alike. Nothing else independently infers or re-derives
geometry.

## Geometry model

`UiContourActionGeometrySolver`
(`lib/src/patterns/interaction/ui_contour_action_geometry.dart`) is a pure,
widget-free function: `UiContourActionGeometryInput → UiContourActionGeometry`.
It has no notion of time, duration, or curve — only `progress` (already
curve-shaped by the caller) and the natural (measured) sizes of the trigger
and each action.

- **Endpoints are fixed for the duration of a transition.** The trigger
  rect never changes — this component doesn't resize or relabel the
  trigger, so there is nothing to keep stable against a moving target.
  Each action's *destination* rect is a plain sequential layout (trigger
  width + spacing + action widths + spacing...), computed once per layout
  pass from measured sizes — not recomputed from an already-animating
  intermediate state. This directly fixes the earlier "destination changes
  while the outer transition targets it" bug, which came from multiplying
  gaps by progress inside a rect that a second controller was
  simultaneously interpolating toward.
- **Each action's rect is `Rect.lerp(source, destination, progress)`.**
  `source` is zero-width, co-located with the trigger's trailing edge — the
  action is materially "inside" the trigger at rest, not merely invisible
  at its final position. Because every component of every rect (left, top,
  width, height) is a linear interpolation between two fixed endpoints, the
  result is monotonic in `progress` by construction: no oscillation, no
  recoil, and forward/reverse paths are the same function evaluated at the
  same `progress` — they are identical by definition, not by careful
  tuning.
- **Outer width is `max(trigger width, last action's right edge)`** — also
  a pure function of the same fixed endpoints, so it inherits the same
  monotonicity guarantee. This is what actually fixes the "snap-then-idle"
  symptom: there is no oscillator to saturate early, so the outer width
  visibly progresses through the full curve duration instead of completing
  in the first ~15%.
- **RTL is handled outside the solver.** The solver always computes
  start-relative (LTR-shaped) rects; the render object mirrors them against
  the ambient `Directionality` at layout time. The solver itself never
  needs to know about direction.

## Emergence and occlusion

`_RenderContourActionRelease` (inside `ui_contour_release.dart`) lays out
the trigger and every action at their natural (loose-constrained) size every
frame — cheap, since this is at most 5 small buttons — then paints each
action **clipped to its solved rect**, with its natural-size content kept
centered within that clip window. Position and clipping are what
communicate emergence: a narrow rect reveals a centered sliver of the
action's icon; as the rect grows toward its destination, more of the icon
becomes visible while it also travels toward its final position. A
per-action opacity (`rect.width / naturalWidth`) assists legibility during
that reveal — it is not the primary spatial signal, position and clipping
are.

Hit testing is bounded to the *same* clip rect used for painting
(`clipRect.contains(position)` before delegating), so painted bounds and
interactive bounds can never diverge — the earlier `Clip.none` bug (visible
pixels outside the hit region) cannot recur because there is no unclipped
paint path.

Interaction eligibility is a separate, simpler signal: an action becomes
tappable and enters the semantics tree only once `progress` crosses an
activation threshold (0.92 — see `UiContourActionGeometryInput.activationThreshold`),
gated at the widget level with `IgnorePointer`/`ExcludeSemantics`. This is
independent from whether an individual action is *disabled*
(`UiContourReleaseAction.onPressed == null`), which is handled by passing
`null` straight through to `UiIconButton.onPressed` — never wrapped in a
non-null closure — so a disabled action gets `UiIconButton`'s own correct
disabled appearance, pointer behavior, focus behavior, and semantics.

## Persistent trigger identity

`UiContourRelease` builds exactly one `UiButton` call site per frame — there
is no second, crossfaded copy. Because it's the same widget type at the
same position in the tree on every rebuild, Flutter preserves its `Element`
and `State` automatically; this is verified directly in
`ui_contour_release_test.dart` by capturing `tester.element(...)` before and
after a full expand/collapse cycle and asserting `identical()`.

The trigger's **visible label never changes** between collapsed and
expanded — only its `Semantics.label` does (`label` while collapsed,
`'Collapse actions'` — or a caller-supplied override — while expanded).
This sidesteps content-handoff entirely rather than attempting a risky
in-place text swap: there is no visible text to duplicate, ghost, or flash.

## State machine

`UiContourPhase` (`lib/src/foundation/motion/ui_contour_controller.dart`):
`collapsed → opening → expanded`, `expanded → closing → collapsed`,
`opening`/`closing → reversing` (never resets progress — reversal continues
from the current value), plus `interrupted`, `sourceUnavailable`,
`destinationUnavailable`, `settled`, `disposed`. `UiContourController` is the
sole owner; `open()`/`close()` are idempotent and interruption-safe by
construction (there is only one `AnimationController` to reason about).
`open()`/`close()` now resolve their curve from `UiMotionSpec` (the theme's
`standardCurve`/its flip) rather than from `UiContourPhysics` — see
[Physics](#physics-what-remains-and-why).

## Physics: what remains, and why

`UiContourPhysics` (`lib/src/foundation/motion/ui_contour_physics.dart`) no
longer generates a `Curve`. It is reserved for a **future, optional,
purely-decorative deformation layer** — e.g. a very-low-amplitude surface
lean derived from motion velocity — that must never touch layout bounds and
must remain fully removable without the component looking incomplete. That
layer has not been built: per the correction brief, decorative deformation
is explicitly deferred until the crisp geometry is proven excellent on its
own. What remains today (`maxStretch`/`maxCompression`/`overshootPolicy`/
`settleThreshold`/`deformationAmplitude()`/`resolve()`) is inert token
infrastructure for that future work, not something any shipped component
currently reads.

## Responsive policy

`UiContourRelease.maxInlineActions == 4`, enforced by an assertion. This is
a deliberate compact-layout policy, not an arbitrary cap: an unbounded
horizontal action list has no narrow-width story. Callers with more than 4
commands should route them through a menu or sheet instead — that fallback
is not built yet (out of scope for this slice; see
[Deferred](#what-shipped-vs-deferred)).

This widget also needs a parent that permits it to grow past its collapsed
width (e.g. a `Row` with `mainAxisSize: MainAxisSize.min`) — a parent that
clamps it to exactly its collapsed width will clip the released actions,
because actions are measured at their natural size, not squeezed to fit.

## Accessibility, RTL, and performance

- Reduced motion: `UiMotionSpec` collapses duration to `Duration.zero` under
  `MediaQuery.disableAnimations`, so a single frame reaches the final,
  fully-interactive state — verified in both the geometry solver tests and
  the widget tests.
- RTL: verified by mirroring released-action rects against the ambient
  `Directionality` and asserting actions land left of the trigger and
  remain tappable under `TextDirection.rtl`.
- No per-action `AnimationController` — one controller drives every
  rectangle via the pure solver.
- No shader, no texture capture, no continuous backdrop sampling. Both
  trigger and actions repaint only while their controller is actively
  ticking; there is no ongoing rendering cost at rest.
- Only the visually/interactively active side of the transition receives
  pointer events and appears in semantics — enforced by the render object's
  clip-bounded hit test plus widget-level `IgnorePointer`/`ExcludeSemantics`,
  not by an unbounded `Clip.none` paint.

## A second model: independent surfaces sharing a timeline

`UiContourRelease` models one persistent capsule containing everything.
Not every interaction fits that shape. A bottom navigation bar releasing a
search accessory is a different case: the bar and the accessory are **two
independent surfaces with no common parent container** — they share only
color tokens and one progress timeline, not a box. `UiContourAccessoryRelease`
(`ui_contour_accessory_release.dart`) is the second Contour primitive,
covering that shape:

- `UiContourAccessoryGeometrySolver` is the same kind of pure, two-fixed-endpoint
  function as the action solver, but it produces **two independent rects**
  instead of one shared capsule plus children: `barRect(t)` recedes by
  exactly the width the accessory claims (anchored at its leading edge, so
  the two surfaces never overlap once separated), while `accessoryRect(t)`
  grows from the search trigger's own footprint to its full size at the
  freed edge. Both are linear interpolations of fixed endpoints, so both are
  monotonic and reversible by construction, same as the action solver.
- Because the accessory's source rect has real (non-zero) size — it starts
  exactly coincident with the visible search icon, not a zero-size point —
  its visibility is driven directly by `progress`, not by a width ratio
  (a width-ratio visibility would never reach 0 at rest and the accessory
  would duplicate the icon underneath it).
- Each surface's own content is always laid out at its *natural* full size
  via `OverflowBox`, with the shrinking/growing rect from the solver used
  only as a visual `ClipRect` window — this is what keeps a receding bar's
  icons from being squeezed into overflow as it narrows, the same
  "geometry drives what's visible, not what's laid out" principle used for
  released actions.
- **This is the one place in Contour that uses a blur**, and it is bounded
  and justified, not decorative: the accessory is genuinely a *separate*
  surface once emerged, so a capped `BackdropFilter` (via the same
  `UiEffectsTokens.scaleBlur`/tier machinery `UiOpenContainer` already
  uses — full tier only, `enableBackdropBlur:false` under the reduced
  tier, scaled by the same emergence progress) helps it read as detached
  from the content beneath it. Contrast with the retired glow path: that
  blur stood in for broken geometry; this one separates two surfaces whose
  geometry is already independently correct without it.

## The abstract presence layer, and where it's applied

A component with an *optional* animatable slot — content that may or may not
exist depending on external state (a search accessory that only some tabs
offer, a contextual toolbar, an inline banner) — needs the exact same three
guarantees every time: one owned progress timeline, the last value retained
while it fades out (never `null` mid-exit), and the value cleared only once
settled. Before this, that pattern was hand-rolled per component — found in
`UiBottomTabScaffold`'s `_BottomTabBodyState`, which drove a raw
`AnimationController` plus a manually retained `_visibleAccessory` field.

`UiContourPresenceController<T>`
(`lib/src/foundation/motion/ui_contour_presence.dart`) formalizes that
pattern as one reusable, independently-tested primitive built on
`UiContourController`, so it doesn't need reinventing per component:

- `update(context, next)` on every build/`didUpdateWidget`; `value` reads as
  the current target while present, and the *previous* target while
  animating out — only `null` once the timeline actually settles collapsed.
- `onRemove` transforms the retained value right before it starts fading
  (e.g. force-collapsing an expanded sub-state so removal never animates out
  mid-expansion).
- `duration` overrides the resolved open/close timing when a component needs
  something other than the theme's standard structural motion.
- Inherits everything `UiContourController` already provides: reduced-motion
  collapse, interruption-safe reversal, rapid-retrigger safety.

**Applied to `UiBottomTabScaffold`**: `_BottomTabBodyState` now uses
`UiContourPresenceController<UiBottomTabAccessory>` instead of its hand-rolled
controller — same public API and observable timing (verified against the
existing test suite, all 50 `platform_components_test.dart` cases unchanged,
including the accessory-specific ones), but the mechanism is now shared
infrastructure instead of a one-off. This directly closes the gap a
runtime probe found: switching from a tab with no accessory to one that
has one, driven only through the raw `UiBottomTabBar` (which is intentionally
a low-level, caller-driven primitive, analogous to `UiContourController`
needing a caller to drive it), snaps instantly — width flat at every sampled
frame from 0ms. Driven through `UiBottomTabScaffold` — the actual integration
point, both before and after this change — it already animated correctly,
and continues to after the retrofit (0.0 → 20.2 → 47.7 → 56.0px over ~80ms,
matching the original `motion.fast` timing).

## What shipped vs. deferred

Shipped and tested: `UiContourActionGeometrySolver` (pure geometry tests —
endpoints, monotonicity, finiteness, activation threshold, responsive
sizing), the render object that paints/hit-tests from it, `UiContourRelease`
(persistent identity, disabled actions, semantics labels, RTL, reduced
motion, rapid re-trigger, reversal mid-emergence, dispose mid-transition,
focus stability), the `UiStackedMotion`/`UiContourController` curve fixes,
`UiContourAccessoryGeometrySolver`/`UiContourAccessoryRelease` (pure
geometry tests, persistent dual-surface identity, bar recession with
content fade, bounded tier-aware blur, reduced motion, dispose
mid-transition), and `UiContourPresenceController` (the abstract
optional-slot presence layer, applied to `UiBottomTabScaffold`).

Deferred: a menu/sheet fallback beyond `maxInlineActions`, decorative
velocity-derived deformation, Prototype B (cross-screen persistence via
`UiOpenContainer`), and folding `UiContourAccessoryRelease`'s geometry model
into `UiBottomTabBar`/`UiBottomTabScaffold`'s own dock morph (they remain two
separate implementations of "surface recedes while another grows"; only the
*presence* half — whether the accessory exists at all — is unified so far).
Nothing here blocks building those next on top of this corrected foundation.
