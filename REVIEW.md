# Review instructions

Every change gets the same AI review passes before it merges. This is a **single-maintainer**
project, so there is no separate human code owner: the author runs these passes (via the
`sdlc-pr-review` skill — "review this diff") on the PR, fixes what matters, and self-merges.
Human review is optional, not required.

Modeled on the [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook)
and [Solving code review at Anthropic](https://claude.dev/blog/solving-code-review-at-anthropic/),
adapted for solo (see [`docs/exec-plans/active/2026-10-30-sdlc-review-migration.md`](docs/exec-plans/active/2026-10-30-sdlc-review-migration.md)).

## Match effort to risk

Pick a tier from the change, not the author:

- **Quick** — docs, comments, changesets, test-only additions. One bugs pass, skip the rest.
- **Standard** — ordinary product/logic changes. All three passes below.
- **Deep** — **always** for these paths, never Quick: `.github/workflows/`,
  `scripts/{make_app,install,release}.sh` and signing, `Sources/MeetingAlarm/Alarm/` (overlay /
  scheduler — the "never trap the user" surface), and anything touching the Keychain. Review the
  whole surface, not just the diff, and name the invariant each change could break.

## Passes

Tag each finding with its pass:

- **Bugs** — logic errors, broken edge cases, subtle regressions.
- **Security** — injection, auth gaps, secrets or PII in logs (see [`SECURITY.md`](SECURITY.md)).
- **Compliance** — the change matches its `docs/design-docs/<slug>.md` and
  `docs/exec-plans/active/<slug>.md` (if any), the layer rules in [`ARCHITECTURE.md`](ARCHITECTURE.md),
  and the invariants in [`AGENTS.md`](AGENTS.md) (Esc always dismisses; no `print`; files ≤ 250
  lines; pure logic stays pure).

## Severity, evidence, and honesty

- **Important** — would break behavior, leak data, or breach an invariant. These **block** a
  self-merge until fixed, or until the thread is resolved with a one-line reason it's a false
  positive. **Nit** — style, naming, polish.
- **Pre-existing** — a real problem the diff didn't introduce. Tag it so inherited bugs aren't
  pinned on this change; fix opportunistically, never block on it.
- **Cite file + line as evidence.** No speculative findings — if you can't point at the code,
  don't report it.

## Cap the nits

Report at most five nits per review; summarize the rest as a count.

## Do not report

Generated files (incl. `CHANGELOG.md`), the `.build/` tree, and anything `make ci` already
enforces (layering, module-map drift, formatting, lint, coverage, the mutation floor).

## Converge; don't loop

- Cap at **three rounds**. After the first pass is clean, **re-review only the new diff**.
- Never repeat a finding already posted. When a bug has a *class*, flag the class so every
  instance is fixed at once, not one comment per site.

## Output

Start with a **count** and say plainly when nothing needs fixing (e.g. "0 Important, 2 nits" or
"Nothing to fix"). Then a table sorted by severity:

| Severity | File:Line | Issue |
|---|---|---|
| Important | `path:22` | Compliance: <finding, cite the design doc / invariant> |
| Pre-existing | `path:9` | Bugs: <inherited finding> |
| Nit | `path:8` | Bugs: <finding> |

## Feedback into the system

- A mistake flagged a second time goes into `AGENTS.md` (or a lint) in the same PR.
- Flag when a change makes `AGENTS.md` / the docs outdated.
- Confirmed bugs become eval cases (see the migration plan, increment 2).
