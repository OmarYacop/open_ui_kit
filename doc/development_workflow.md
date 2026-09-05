# Open UI Kit development workflow

This is the source of truth for issues, labels, branches, pull requests, local checks, package
compatibility, and releases. It adapts the ERS workflow to a public Flutter package with visual
goldens and pub.dev publication.

## Clean local setup

Install Flutter stable, Git, and GitHub CLI. The package currently supports the SDK floors in
`pubspec.yaml`; CI checks the pinned minimum Flutter 3.47.0 / Dart 3.13.0 and current stable
so new changes remain compatible with the supported public contract (ADR 0001).

Prepare a checkout and validate the tools:

```bash
flutter pub get
flutter doctor -v
./scripts/ci repo-policy
```

For native GitHub stacked pull requests, install GitHub CLI 2.90 or later and the official preview
extension:

```bash
gh extension install github/gh-stack
gh stack --version
```

The canonical validation entry point is:

```bash
./scripts/ci repo-policy  # governance, branch names, pinned Actions, artifact policy
./scripts/ci quality      # format check, analyzer, and non-golden Flutter tests
./scripts/ci examples     # example widget and responsive showcase tests
./scripts/ci goldens      # all deterministic macOS golden suites
./scripts/ci package      # pub.dev dry-run validation
./scripts/ci changed      # suites affected by the branch and working tree
./scripts/ci all          # complete release-level validation
```

Example behavior tests run on every quality host. The example screenshot comparisons run only
on macOS, alongside the root golden job; their stored baselines require the same explicit approval
for updates.

GitHub Actions calls these same suites. Extend `scripts/ci` first, then orchestrate the suite from
`ci-gate.yml`. Never commit `.dart_tool`, `build`, coverage, golden failure diagnostics, editor
state, or package credentials. Golden baselines are source files, but may change only when the
visual change is intentional and explicitly requested.

## Issues and labels

Open an issue for material features, defects, public API migrations, security hardening,
publication incidents, or expensive architectural decisions. Do not create extra issues for
mechanical steps already tracked by one outcome. Every issue needs observable acceptance criteria.

Use labels as independent dimensions:

- Exactly one `type:*`: `bug`, `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `hotfix`, `perf`,
  `refactor`, `release`, `security`, or `test`.
- One or more `area:*`: `accessibility`, `ci`, `components`, `docs`, `foundation`, `governance`,
  `localization`, `motion`, `patterns`, or `release`.
- Exactly one issue priority: `priority:p0` through `priority:p3`.
- Add `status:blocked`, `status:needs-decision`, or `breaking-change` only when applicable.

The issue forms set initial type/status labels. The filer or triager applies area and priority
after creation. `scripts/github/sync-labels OmarYacop/open_ui_kit` is the repeatable definition; it
creates or updates this taxonomy without deleting unrelated historical labels.

## Branches and commits

Branch names use `<type>/<issue>-<short-kebab-description>`:

```text
feat/142-adaptive-segmented-control
fix/187-dialog-focus-loop
ci/205-required-gate
docs/stacked-pr-guide
```

Allowed types are the `type:*` values above except `bug`; a bug implementation uses `fix` or
`hotfix`. Omit the issue number only for genuinely untracked documentation or maintenance. Never
use an agent, tool, or person's name as a branch prefix.

Commit subjects follow Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, and so on). Keep
each commit intentional and buildable. A public API change must include its implementation, tests,
documentation, changelog entry, and any required deprecation path in the same layer or a safely
ordered stack.

## GitHub stacked pull requests

Use a stack for two or more dependent review units, such as tokens → primitive → component, or
deprecation shim → replacement API → migration cleanup. Use one standalone PR when the work is one
focused outcome; do not create stacks merely to split files or bypass meaningful review.

Plan foundations at the bottom and dependents above. All branches must be in this repository;
cross-fork stacks and GitHub Desktop are not supported in GitHub's public preview.

Create a stack:

```bash
git switch main
git pull --ff-only
gh stack init --base main feat/142-segmented-tokens

# Edit, test, stage, and commit the bottom layer.
git add <paths>
git commit -m "feat: add segmented-control tokens"

gh stack add feat/142-segmented-primitive
# Edit, test, stage, and commit the next layer.

gh stack add feat/142-segmented-control
# Edit, test, stage, and commit the top layer.

gh stack submit
```

Each PR has one outcome and targets the branch below it; only the bottom PR targets `main`. Use
`Part of #142` on intermediate layers and `Closes #142` only on the layer that completes every
acceptance criterion. Submit draft layers, attach test evidence per layer, and review bottom-up.

Maintain a stack with:

```bash
gh stack view       # inspect the active stack
gh stack rebase     # cascade-rebase onto the trunk and lower layers
gh stack push       # push rebased branches
gh stack sync       # reconcile local tracking after remote changes or merges
gh stack modify     # reorder, insert, rename, fold, or remove layers interactively
```

When a lower layer changes, fix that layer and cascade upward; never duplicate its fix in a higher
layer. A stack must keep linear history. GitHub evaluates every layer against `main` protections,
including checks, reviews, and CODEOWNERS. Merge the ready stack from the top or merge a contiguous
lower portion first. This feature is a public preview and can change; use GitHub's native stack map
and `gh stack` rather than manually maintained base-branch chains.

## Pull requests, CI, and repository settings

Keep one behavioral, visual, API, or architectural argument per PR. The template requires scope,
public API/compatibility impact, dependencies, real test evidence, and stack position. UI changes
need visual evidence. Never claim a check passed unless it ran on the final diff.

`CI Gate / gate` is the only required check on `main`. It aggregates repository policy, analyzer
and tests, pub.dev package validation, and macOS goldens. Component jobs stay visible for diagnosis
without creating multiple required-check contracts. PR workflows are read-only, use timeouts,
cancel superseded runs, and pin third-party Actions to immutable commit SHAs.

Repository policy is:

- Require a pull request, resolved conversations, and `CI Gate / gate` before `main` changes.
- Keep CODEOWNERS review routing visible. Do not require self-approval while this repository has
  only one maintainer; raise the required approval count when another maintainer is added.
- Require linear history and block force pushes/deletions on `main`.
- Allow squash merges and automatically delete merged branches.
- Permit native GitHub stack behavior; every stack layer satisfies the trunk rules.

Do not weaken a rule to land a failing change. Diagnose the check or amend the layer where the
failure belongs.

## Architecture decisions and public compatibility

Create an Architecture decision issue and ADR for public API philosophy, dependency boundaries,
Material/Cupertino isolation, token resolution, accessibility semantics, compatibility floors,
golden strategy, or another choice expensive to reverse. Copy `doc/decisions/0000-template.md`,
allocate the next number, and link the issue, ADR, and implementation PRs.

Follow `doc/deprecation_policy.md` for public migrations. Every deprecation names its replacement
and scheduled removal version in `CHANGELOG.md`. Do not remove a compatibility API before the
announced breaking release.

## Release tags and the pub.dev environment

Open UI Kit uses annotated SemVer tags: `vMAJOR.MINOR.PATCH`. The tag version must exactly match
`pubspec.yaml`, point to a commit contained in `main`, and never be moved or reused. The GitHub
`pub.dev` environment is restricted to `v*` tags and gates the OIDC publishing identity.

One-time pub.dev configuration must name:

```text
Repository: OmarYacop/open_ui_kit
Tag pattern: v{{version}}
Required GitHub Actions environment: pub.dev
```

No long-lived pub.dev credential belongs in GitHub. From an updated `main` checkout:

```bash
git switch main
git pull --ff-only
./scripts/ci all
git tag -a v0.8.0 -m "Open UI Kit 0.8.0"
git push origin v0.8.0
```

The tag workflow validates the annotated tag, version, and `main` ancestry, repeats all checks,
publishes through pub.dev's GitHub OIDC flow, then creates a GitHub Release. A tag identifies
immutable package source, not an environment. Fix a bad release forward with a new version.

Use patch for compatible fixes, minor for compatible capabilities, and major for breaking public
contracts after the deprecation policy permits removal. During `0.x`, still document breaking
changes explicitly and choose the next version intentionally.

## Rules for AI coding agents

Before editing, an agent reads `AGENTS.md`, this document, the linked issue, relevant ADRs,
`doc/deprecation_policy.md` for API work, and sibling code/tests. It then:

1. Confirms acceptance criteria and applies label dimensions consistently.
2. Plans one PR or a dependency-ordered GitHub stack before broad changes.
3. Keeps every layer independently testable, reviewable, and safe to merge.
4. Preserves package boundaries, accessibility, RTL, adaptive layout, and reduced-motion behavior.
5. Updates focused tests with behavior and never updates goldens without explicit authorization.
6. Runs `./scripts/ci changed` on the final tree and records exact evidence.
7. Reviews the full diff/status for secrets, local artifacts, diagnostics, and unrelated edits.
8. Never creates, moves, or pushes release tags unless the user explicitly requests a release.
