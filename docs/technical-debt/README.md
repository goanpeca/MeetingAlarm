# Technical Debt

Explicit, categorized tracking of known issues so they surface instead of rotting.
Add a row when you knowingly defer something; remove it when fixed (note the fix in
the commit).

Format: `| id | domain/layer | description | severity | added |`

| id | domain | description | severity | added |
|----|--------|-------------|----------|-------|
| TD-1 | Architecture | Single-module layering is enforced by a framework-import script, not by the compiler. Optional hardening: split layers into SwiftPM targets so an upward-only import becomes a compile error. | low | 2026-08-26 |
| TD-2 | Build/CI | `scripts/coverage-gate.sh` parses `llvm-cov` JSON; verified locally (~95% core). Confirm the `llvm-cov`/xctest paths resolve on the GitHub `macos-latest` image on first CI run. | low | 2026-08-26 |
| TD-3 | Calendar | The Google end-to-end flow (loopback → token exchange → refresh → fetch) is verified manually only; it needs a real OAuth client id/secret, so it is not exercised in CI. Pure pieces (PKCE, URL/body, JSON mapping, merge) are unit-tested. | medium | 2026-08-26 |
| TD-4 | Alarm | `AlarmScheduler` schedules with `Task.sleep`; behavior of very long sleeps across system sleep is backstopped by the `didWake` observer recomputing, not directly tested. Add a sleep/wake test. | low | 2026-08-26 |

_No high-severity debt outstanding._
