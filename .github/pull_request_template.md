<!-- Keep one independently reviewable argument in this PR. Split dependent concerns into a stack. -->

## Summary

<!-- What does this change and why? -->

## Outcome

<!-- The single behavior, API, visual contract, or repository property this PR establishes. -->

## Stack position

<!-- Delete this section for a standalone PR. -->

- Stack: `<bottom branch>` → `<this branch>` → `<top branch>`
- This PR's base: `<branch>`
- Part of #<issue> <!-- Use "Closes #<issue>" only on the layer that completes the issue. -->

## Scope

- In scope:
- Out of scope:

## Public API and compatibility impact

<!-- Include exports, deprecations, migration path, minimum Flutter/Dart versions, and rollback. -->

## Test and visual evidence

<!-- Paste only commands actually run. Include screenshots or recordings for intentional UI changes. -->

```text
$ ./scripts/ci changed
<result>
```

## Dependencies introduced

<!-- For each dependency: purpose, license, maintenance/security posture, and alternatives. Use "None." when applicable. -->

## Checklist

- [ ] Acceptance criteria are met and linked to an issue
- [ ] Tests cover semantics, adaptive layout, overflow, disabled/loading states, and regressions as applicable
- [ ] `./scripts/ci changed` passes
- [ ] Public API changes follow `doc/deprecation_policy.md` and update `CHANGELOG.md`
- [ ] Golden changes are intentional, narrowly scoped, and requested
- [ ] Full diff reviewed; no secrets, local artifacts, generated diagnostics, or unrelated changes are staged
