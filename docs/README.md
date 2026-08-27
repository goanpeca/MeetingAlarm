# Docs — system of record

Authoritative documentation. When code and these docs disagree, one of them is a bug — fix it
in the same change. The compact map is [`../AGENTS.md`](../AGENTS.md) (imported by `CLAUDE.md`
so Claude and Codex share one source of truth); the architecture is
[`../ARCHITECTURE.md`](../ARCHITECTURE.md).

| Area | Doc |
| --- | --- |
| Per-subsystem design docs (catalogued, verification status) | [design-docs/index.md](design-docs/index.md) |
| Agent-first operating principles (golden rules) | [design-docs/core-beliefs.md](design-docs/core-beliefs.md) |
| Commit / code conventions | [design-docs/conventions.md](design-docs/conventions.md) |
| Execution plans (active / completed) + tech debt | [exec-plans/](exec-plans/README.md) · [tech-debt-tracker.md](exec-plans/tech-debt-tracker.md) |
| Machine-generated, verified (module/repo map) | [generated/repo-map.md](generated/repo-map.md) |
| Quality grades + coverage bar | [QUALITY_SCORE.md](QUALITY_SCORE.md) |
| Product specs (what it's for, who it serves) | [product-specs/index.md](product-specs/index.md) |
| Stack reference material / external notes | [references/](references/README.md) |

Enforcement lives in `scripts/*.sh` and `.github/workflows/`; reproduce it all with `make ci`.
