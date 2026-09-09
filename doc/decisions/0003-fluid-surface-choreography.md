# ADR 0003: Separate fluid choreography from surface rendering

- Status: Proposed
- Date: 2026-09-06
- Issue: [OMA-38](https://linear.app/omar-yacop/issue/OMA-38/implement-fluid-surface-morph-and-splitmerge-motion)

## Context

The accepted V13 reference requires coordinated geometric overshoot and early clipped
content. The second reference retains a source while producing additional surfaces.
Existing Contour deliberately clamps layout geometry and reserves physics for
optional decoration. Changing those defaults would regress existing consumers.

## Decision

Add experimental fluid primitives alongside Contour. One raw controller value drives
geometry, clipping and content. Share geometry and surface rendering; keep morph
and split choreography distinct. Branch identity represents a surface and is
independent of the actions inside it. Overlay lifecycle stays with existing scopes
and composition owners. Use widgets-layer APIs without Material/Cupertino imports
or new dependencies.

## Alternatives considered

Retuning Contour would alter its documented monotonic geometry contract. A universal
morph/split widget would entangle retained-source and replacement-source lifecycles.
Blur-based metaballs would introduce a material effect the user explicitly excluded.

## Consequences

Consumers explicitly provide local geometry and sufficient viewport bounds. Existing
motion remains compatible. Experimental rendering APIs can be refined after device
review without claiming native Apple physics. The split bridge is a geometric
approximation; source deformation and automatic branch layout are future work.

## Verification

Deterministic geometry samples, widget input/layout/reversal/reduced-motion checks,
Flutter analysis and repository CI. Preserve golden baselines. Device review in a consuming application remains the final subjective motion
acceptance step.
