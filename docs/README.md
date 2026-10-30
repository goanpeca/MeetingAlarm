# Docs — repo-wide references

Per-change artifacts (`intent.md` → `spec.md` → `plan.md`) live in [`../intent/`](../intent/README.md),
one folder per change. This folder holds only the **repo-wide** references that outlive any one
change. The compact map is [`../AGENTS.md`](../AGENTS.md); the architecture is
[`../ARCHITECTURE.md`](../ARCHITECTURE.md).

| Area | Doc |
| --- | --- |
| Changes (intent / spec / plan, verification status) | [../intent/README.md](../intent/README.md) |
| Agent-first operating principles (golden rules) | [core-beliefs.md](core-beliefs.md) |
| Commit / code conventions | [conventions.md](conventions.md) |
| Known issues / deferred work | [tech-debt-tracker.md](tech-debt-tracker.md) |
| Machine-generated, verified module map | [generated/repo-map.md](generated/repo-map.md) |
| Quality grades + coverage bar | [QUALITY_SCORE.md](QUALITY_SCORE.md) |
| Stack reference material / external notes | [references/](references/README.md) |

Enforcement lives in `scripts/*.sh` and `.github/workflows/`; reproduce it all with `make ci`.
