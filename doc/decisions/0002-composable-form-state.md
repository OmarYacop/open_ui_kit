# ADR 0002: Composable form state and shared field presentation

- Status: Proposed
- Date: 2026-09-05
- Issue: #16
- Owners: @OmarYacop

## Context

Applications need consistent field errors, dirty tracking, validation, and submission without introducing Material widgets or a second state-management dependency. Existing UiFormSubmitController users need to retain their current behavior.

## Decision

Add an opt-in UiFormController that registers typed field controllers and owns their lifecycle. Values are treated as immutable snapshots. Shared field presentation remains internal; adapters connect controller state to existing components and custom fields. Callers can supply focus nodes and remain responsible for disposing those nodes.

Synchronous validation follows edits. Explicit validation and submission also run asynchronous validators. Field and registration revisions reject results from stale validation; edits made during saving remain dirty. Validator exceptions propagate to the caller and always clear pending state. Submission receives an unmodifiable values map.

Keep UiFormSubmitController compatible and use it for submission gating. Dependencies continue to point from patterns to components to foundation, with architecture tests enforcing that direction.

## Alternatives considered

### Material Form and TextFormField

They provide familiar form behavior but violate the widgets-layer package boundary and couple kit components to Material presentation.

### External form-state dependency

It could reduce implementation work, but would impose a state-management model on consumers. Typed controllers and Listenable adapters permit integration with an application's existing approach.

## Consequences

The API is additive and opt-in. Applications own the form controller and dispose it with their screen. Mutable values must be replaced rather than mutated in place. Async validity is confirmed on explicit validation or submission, not every keystroke. Custom fields must bind their value, change callback, and focus node correctly.

## Verification

Controller tests cover stale async results, changes during submission, focus on invalid fields, reset and disposal. Field tests cover shared errors and accessibility. Architecture tests enforce import boundaries. See [forms](../forms.md) for ownership and integration contracts.
