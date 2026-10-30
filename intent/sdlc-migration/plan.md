# Migrate the review loop to the AI-native SDLC playbook (solo)

**Goal.** Adopt the [AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook)
(local copy: `~/Documents/develop/goanpeca/AI-native SDLC playbook`) and the practices in
[Solving code review at Anthropic](https://claude.dev/blog/solving-code-review-at-anthropic/),
**adapted for a single-maintainer project**. Focus first on **Stage 5 — the PR review loop**,
which both sources treat as the highest-leverage gate.

The playbook's build/test stages are already in place here (harness: `make ci`, coverage +
mutation gates, `check-*` linters, pinned toolchain, `sdlc-*` skills in `.claude/skills/`). The
gap is in how review findings are scoped, tiered, blocked on, and fed back.

## Solo adaptation (what we keep vs. drop)

The blog is written for large, multi-reviewer orgs. For a solo repo:

- **Keep:** verify-before-PR, AI review on every PR, risk-tiered *effort*, block-on-open-findings,
  file+line evidence, nit caps, convergence control, incidents→evals, fix-the-source.
- **Drop / collapse:** multi-human approval tiers (Low/Med/High → 0/0/self), merge queue, weekly
  on-call. The author is the sole human; "required human approval" becomes "author self-merge
  once `make ci` is green and no Important/Security finding is open" (per [`REVIEW.md`](../../REVIEW.md)).
- **Reinterpret:** the blog's "always needs a human" paths (auth, billing, CI, auto-updater)
  become **always-Deep review** paths here (no extra human, but never a Quick pass):
  `.github/workflows/`, `scripts/{make_app,install,release}.sh` + signing, `Sources/MeetingAlarm/Alarm/`
  (overlay/scheduler — the "never trap the user" surface), and anything touching the Keychain.

## Gap analysis (blog layer → here)

| Blog layer | Current | This migration |
|---|---|---|
| Verify before PR | `make ci`, `/code-review`, `/security-review`, hooks | ✓ (no change) |
| AI review every PR | `REVIEW.md` 3 passes; Copilot on GitHub | **Increment 1**: tiers, evidence, pre-existing tag, convergence |
| Findings block merge | implicit ("fix what matters") | **Increment 1**: explicit block + resolve-with-reason |
| PR template (Testing/Risk/Revert) | "What & why" + Definition of Done | **Increment 1**: add Testing / Risk / How to revert |
| Risk-tiered effort | same passes always | **Increment 1**: Quick / Standard / Deep + always-Deep paths |
| Incidents → evals | `evals/` exists; no review eval set | **Increment 2** |
| Measure noise & rounds, close the loop | none | **Increment 3** (lightweight) |

## Increments

- [x] **1 — Review loop (this PR).** Upgrade [`REVIEW.md`](../../REVIEW.md): Quick/Standard/Deep
  tiers + always-Deep paths; require file+line evidence (no guesses); add the **Pre-existing**
  tag so inherited bugs aren't blamed on the author; count-first summaries that say plainly when
  nothing needs fixing; make open Important/Security findings **block** self-merge, cleared by a
  fix or by resolving the thread with a reason; cap at **3 rounds** then re-review only the new
  diff and never repeat a posted finding. Add **Testing / Risk / How to revert** to the PR template.
- [x] **1b — Changesets via Changie (this PR).** Adopt [Changie](https://changie.dev) so
  `CHANGELOG.md` is generated, not hand-edited: `.changie.yaml` (Keep-a-Changelog shape), the
  existing entries migrated into `.changes/unreleased/` changesets (no release cut yet — all under
  `[Unreleased]`), `make changeset` / `make changelog` targets, and `release.sh` switched to
  `changie batch` + `changie merge`. Playbook mapping: the blog's "fix the source / small, legible
  change records" applied to release hygiene.
- [x] **1c — Native playbook layout (this PR).** Every change now lives in `intent/<slug>/`
  (`intent.md` → `spec.md` → `plan.md`), indexed with spec verification status in
  [`intent/README.md`](../README.md). Moved v1 (intent/spec/plan), post-v1 (spec), alarm re-fire
  (plan), and this change; folded the design-docs / exec-plans / product-specs indexes into
  `intent/README.md`; kept repo-wide refs (`core-beliefs`, `conventions`, `tech-debt-tracker`,
  `QUALITY_SCORE`, module map) in `docs/`. Rewired every link (`check-links` green); added a
  `TASKS.md` running board; README status → "in development".
- [ ] **2 — Incidents → evals.** Seed a code-review eval set from past *confirmed* bugs
  (alarm re-fire loop #8; `ArmedConfig` legacy-decode data loss; `install.sh` delete-then-copy;
  Zoom multi-join dedupe) and score the review passes against it; re-score on any change to the
  passes. Extend `evals/` + `.github/workflows/agent-evals.yml`.
- [ ] **3 — Close the loop (lightweight).** Track review rounds-to-green and revert rate as the
  guardrail; a rise in reverts means human time only moved, not saved. Fold recurring findings
  back into `AGENTS.md` / a lint (already the `REVIEW.md` rule).

## Rejected / deferred

- **Merge queue, staged release channels, feature flags** — overkill for a solo menu-bar app with
  a manual `make ci` gate; revisit only if the project gains maintainers (see the Gate-posture
  note in [`AGENTS.md`](../../AGENTS.md)).

## Manual checks

- `make scan` green (docs-only: format/lint N/A, `check-links` must resolve the new links).
- `/code-review` and Copilot run against this PR using the upgraded `REVIEW.md`.
