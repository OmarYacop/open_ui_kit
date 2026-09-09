> **Tracking update:** Use the repository's [Linear tracking agreement](AGENTS.md#linear-tracking-primary-work-tracker)
> for new work. It defines the project, labels, statuses, and Linear issue links.
> GitHub issue forms, numeric `#N` references, and backlog sync instructions below
> describe legacy tracking; retain them for existing issues. Do not create a parallel
> GitHub issue for new Linear work. Branch, CI, review, and release rules still apply.

# Contributing to Open UI Kit

Open UI Kit uses issue-first development, small pull requests, one required CI gate, and
SemVer release tags. Read [the development workflow](doc/development_workflow.md) before starting
material work. AI coding agents must also follow [AGENTS.md](AGENTS.md).

The short version is:

1. Link material work to a structured GitHub issue with observable acceptance criteria.
2. Branch as `<type>/<issue>-<short-kebab-description>` and use Conventional Commit subjects.
3. Use a native GitHub stacked pull request for two or more dependent review layers.
4. Run `./scripts/ci changed`, include the exact result in the pull request, and review the full
   diff for secrets, generated output, local artifacts, and unrelated edits.
5. Merge only after `CI Gate / gate` passes and every review conversation is resolved.

Keep changes focused and evidence-led. Resolve expensive architectural disagreements with an ADR,
not by indefinitely expanding a pull request.
