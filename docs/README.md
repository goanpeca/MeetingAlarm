# Docs — system of record

The authoritative documentation for meeting-alarm. When code and these docs disagree, one of
them is a bug — fix it in the same change. The compact router is [`../AGENTS.md`](../AGENTS.md).

| Doc | What it is |
|-----|-----------|
| [architecture/overview.md](architecture/overview.md) | Domains, layers, data flow |
| [architecture/modules.md](architecture/modules.md) | Every source file, one line each (verified by `check-docs`) |
| [design-docs/](design-docs/INDEX.md) | Per-component contracts — the deep source of truth |
| [principles/golden-principles.md](principles/golden-principles.md) | The mechanically-enforced rules |
| [quality/quality.md](quality/quality.md) | Quality grades + the coverage bar |
| [technical-debt/README.md](technical-debt/README.md) | Known deferred issues (TD-N) |
| [execution-plans/](execution-plans/) | Plans & progress |

Enforcement lives in `scripts/*.sh` and `.github/workflows/`; reproduce it all with `make ci`.
