# ADR 0007: High-level chat composition

- Status: Proposed
- Date: 2026-09-08
- Tracking: [OMA-58](https://linear.app/omar-yacop/issue/OMA-58), dependent [OMA-59](https://linear.app/omar-yacop/issue/OMA-59)

## Context

LMS already uses chat primitives but reconstructs the input surface, keyboard
geometry, sender rows and grouping. Reusing primitives alone does not reproduce
its current conversation design reliably. Existing consumers need compatibility.

## Decision

Add composition in `patterns/chat`, retaining existing primitives and constructors.
`UiChatComposer.conversation` preserves the incumbent attachment/input/reply
structure; `UiChatScaffold` measures chrome and owns keyboard avoidance.
`UiChatMessage` owns row presentation and interaction, while timeline entries
project domain objects into stable IDs, dates and sender grouping. The workspace
specializes existing dual-pane navigation instead of adding a navigation system.

Application adapters retain transport, receipts, persistence, permissions,
uploads, recording services, domain selection commands, media rendering and
reply snapshots. The kit receives widgets and callbacks, with localized labels
and token defaults. Existing low-level composition remains supported.

## Alternatives and consequences

A second generic composer would lose the LMS visual contract. Moving RoomBloc
or media services into the kit would couple presentation to one backend. Slots
preserve those boundaries; selection/recording contents and domain history
orchestration consequently remain app-specific. Post-layout measurement takes a
frame to publish history padding and is regression-tested through size changes.

## Verification

Contract tests cover controller replacement, mode preservation, disabled input,
keyboard reservation, chronological boundaries, receipts, RTL gestures and
scroller continuity. LMS integration tests cover actual adoption, attachment
geometry, reply cancellation, history navigation, selection and media. User owns
visual acceptance; no simulator launches or golden-baseline updates are authorized.
