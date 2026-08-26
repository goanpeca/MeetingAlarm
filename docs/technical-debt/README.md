# Technical Debt

Explicit, categorized tracking of known issues so they surface instead of rotting.
Add a row when you knowingly defer something; remove it when fixed (note the fix in
the commit).

Format: `| id | domain/layer | description | severity | added |`

| id | domain | description | severity | added |
|----|--------|-------------|----------|-------|
| TD-1 | Architecture | Single-module layering is enforced by a framework-import script, not by the compiler. Optional hardening: split layers into SwiftPM targets so an upward-only import becomes a compile error. | low | 2026-08-26 |
| TD-2 | Build/CI | `scripts/coverage-gate.sh` parses `llvm-cov` JSON; verify it runs on the GitHub `macos-latest` image (Xcode/llvm path) on first CI run. | low | 2026-08-26 |

_No high-severity debt outstanding._
