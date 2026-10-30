# Intent — one folder per change

Every change lives in `intent/<change-slug>/` as the
[AI-native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) prescribes:

1. **`intent.md`** — the problem, who it's for, success, non-goals (`sdlc-intent`).
2. **`spec.md`** — numbered requirements + design (`sdlc-spec`).
3. **`plan.md`** — ordered tasks, progress log, manual checks (`sdlc-plan`).

Solo posture: the author approves each hand-off (no separate reviewer). Small fixes may skip
straight to `plan.md`; anything that changes behavior or a design decision gets a `spec.md`.
Start a change with the `ai-native-sdlc` skill — it looks at what exists here and routes on.

## Verification status

Each `spec.md` carries a status: `current` (reflects the code as built), `stale` (may lag the
code — re-verify before trusting), or `superseded`. When code diverges from a `current` spec,
update it or mark it `stale` here **in the same change**.

## Changes

| Change | Intent | Spec | Plan | Spec status | State |
|---|---|---|---|---|---|
| `meeting-alarm-v1` — v1 baseline: menu-bar alerter, calendar sources, sensory-profile overlay, snooze, harness | [intent](meeting-alarm-v1/intent.md) | [spec](meeting-alarm-v1/spec.md) | [plan](meeting-alarm-v1/plan.md) | current | done |
| `post-v1-subsystems` — recurring arming, hot key + quick panel, launch-at-login, a11y, accent color | — | [spec](post-v1-subsystems/spec.md) | — | current | done |
| `alarm-refire-loop` — never re-present or preempt an on-screen alarm (#8) | — | — (see v1 spec §17) | [plan](alarm-refire-loop/plan.md) | — | done |
| `sdlc-migration` — adopt the playbook layout, blog review loop, Changie | [intent](sdlc-migration/intent.md) | [spec](sdlc-migration/spec.md) | [plan](sdlc-migration/plan.md) | current | active |

Repo-wide references (not per-change): [`../ARCHITECTURE.md`](../ARCHITECTURE.md),
[`../docs/core-beliefs.md`](../docs/core-beliefs.md), [`../docs/conventions.md`](../docs/conventions.md),
[`../docs/tech-debt-tracker.md`](../docs/tech-debt-tracker.md),
[`../docs/QUALITY_SCORE.md`](../docs/QUALITY_SCORE.md),
[`../docs/generated/repo-map.md`](../docs/generated/repo-map.md).
