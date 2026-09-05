# ADR 0001: Verified SDK support and composition boundaries

- Status: Accepted
- Date: 2026-09-05
- Issue: #11
- Owners: @OmarYacop

## Context

The 0.8.1 manifest claimed Flutter 3.22 / Dart 3.4 support while the source uses
newer framework APIs. Stable-only CI did not verify that promise. The example
already requires Dart 3.13. The installed and release-validated toolchain is
Flutter 3.47.0 / Dart 3.13.0.

## Decision

Declare Flutter 3.47.0 and Dart 3.13.0 as the verified support floor. Test that
exact Flutter version and current stable in the required quality gate. This is
a correction of unsupported metadata, not a claim that every intermediate SDK
has been tested. Future minimum changes require a changelog entry and this CI
contract to change together.

Preserve foundation primitives, components, and patterns as the public layers.
UiApp is the composition root: its navigation-pattern imports are an explicit
exception to the usual direction of dependencies. Keep Material/Cupertino
styling outside the package while using Flutter platform services for native
interaction. Retain existing focused and umbrella export paths.

## Alternatives considered

Restoring Flutter 3.22 would require replacing newer rendering, selection, and
color APIs and testing an additional compatibility implementation. It is not
justified for this corrective update. Guessing a 3.44 floor from one API's
release date would still leave the complete package unverified.

Moving UiApp or splitting large modules is deferred until a concrete consumer
or maintenance benefit warrants the migration. No public API is removed.

## Consequences

Consumers must upgrade to the declared minimum to use the next release. Older
published versions remain available. New localization methods have concrete
English defaults; new color tokens are optional for existing custom themes.
Existing deprecations are retained throughout 0.x and scheduled for 1.0.0.

## Verification

Run formatting, analyzer, and root tests on Flutter 3.47.0 and current stable.
The aggregate gate must wait for both matrix jobs. Regression tests verify the
new token defaults, interpolation, and English/Arabic localization hooks.
