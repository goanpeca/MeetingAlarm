# Intent — Migrate to the AI-native SDLC playbook (solo)

**Status:** approved · **Spec:** [spec.md](spec.md) · **Plan:** [plan.md](plan.md)

## Problem

The repo half-adopted the playbook: its skills were installed, but change artifacts were mapped
onto a harness `docs/` taxonomy, the review loop lacked risk tiers / evidence rules / blocking /
convergence, and `CHANGELOG.md` was hand-edited and drifted.

## Who it's for

The single maintainer (and the agents working on their behalf).

## What success looks like

- Every change lives in `intent/<slug>/` as `intent.md` → `spec.md` → `plan.md`.
- Review follows the playbook's Stage 5 and
  [Solving code review at Anthropic](https://claude.dev/blog/solving-code-review-at-anthropic/):
  effort matched to risk, file+line evidence, `Pre-existing` tag, blocking findings, capped rounds.
- `CHANGELOG.md` is generated from changesets ([Changie](https://changie.dev)), never hand-edited.
- `make ci` stays the one gate, green.

## Constraints

Solo: no multi-human approval tiers, merge queue, or on-call. Keep the mechanical harness gates.

## Non-goals

Cutting a release; changing app behavior.
