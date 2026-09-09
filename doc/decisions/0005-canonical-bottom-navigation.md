# 0005 — Canonical expanding bottom navigation

Status: Accepted for local implementation, awaiting review (OMA-46).

The default compact navigation must expose growing destination sets without a
synthetic More page or browsing arrows. `UiBottomTabScaffold` defaults to four
compact slots and an expandable, stationary clipped grid. The wide rail and
explicit manual bottom-item compositions retain their contracts.

The expanding dock owns its own state. Accessory contour presence, horizontal
search expansion and outside-outline painting are shared with the optional
paged candidate through a private mixin, so the default path allocates no paging
controllers, page timers or arrow focus nodes. Public legacy/paged APIs remain
available. No API is removed or deprecated by this change.

`UiBottomNavigationTokens` belongs to `UiThemeTokens` and supports copy, equality,
interpolation and selective theme dependencies. Shared palettes still own colors,
radii, type and shadows. Applications tune tokens rather than fork cell code.

Customization uses stable destination IDs and insertion ordering. A held item
lifts once, neighboring slots shift, and persisted controller order changes only
on acceptance. Cancellation restores the draft. Pointer feedback does not leave
a dim source clone. Semantic long-press and a two-tap insertion alternative retain
non-drag access. Reduce Motion disables the editing wiggle and slot transitions.

Compatibility: existing More clients can explicitly select `.drawer` and their
previous slot count. The low-level `UiBottomTabBar` remains a compatibility and
manual-layout primitive; applications should prefer `UiBottomTabScaffold`.

Verification: canonical-default/theme tests; insertion, cancellation and no-ghost
tests; explicit legacy and paged coverage; LMS all-role routing/persistence/search;
`./scripts/ci all` and package dry-run. Golden updates and publishing require
separate explicit authorization.

Tracking: https://linear.app/omar-yacop/issue/OMA-46
