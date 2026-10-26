# Review instructions

Every change gets the same AI review passes before it merges. This is a **single-maintainer**
project, so there is no separate human code owner: the author runs these passes (via the
`sdlc-pr-review` skill — "review this diff") on the PR, fixes what matters, and self-merges
once `make ci` is green and the passes are clean. Human review is optional, not required.

## Passes

Run three passes and tag each finding with its pass:

- **Bugs** — logic errors, broken edge cases, subtle regressions.
- **Security** — injection risks, auth gaps, secrets or PII in logs (see [`SECURITY.md`](SECURITY.md)).
- **Compliance** — the change matches its `docs/design-docs/<slug>.md` and
  `docs/exec-plans/active/<slug>.md` (if any), the layer rules in [`ARCHITECTURE.md`](ARCHITECTURE.md),
  and the non-negotiable invariants in [`AGENTS.md`](AGENTS.md) (Esc always dismisses; no `print`;
  files ≤ 250 lines; pure logic stays pure).

## What "Important" means here

Reserve **Important** for findings that would break behavior, leak data, or breach an
invariant. Style and naming are **nits**.

## Cap the nits

Report at most five nits per review; summarize the rest as a count.

## Do not report

Generated files, the `.build/` tree, and anything `make ci` already enforces (layering,
module-map drift, formatting, lint, coverage, the mutation floor).

## Output

A table sorted by severity:

| Severity | File:Line | Issue |
|---|---|---|
| Important | `path:22` | Compliance: <finding, cite the design doc / invariant> |
| Nit | `path:8` | Bugs: <finding> |

## Feedback into the system

- A mistake flagged a second time goes into `AGENTS.md` (or a lint) in the same PR.
- Flag when a change makes `AGENTS.md` / the docs outdated.
