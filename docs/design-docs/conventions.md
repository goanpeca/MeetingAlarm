# Conventions

Mechanically-enforced where possible; the enforcer is named in parentheses.

## Commits
- One line, **< 72 chars**, Conventional-Commit prefix (`feat:`/`fix:`/`docs:`/`refactor:`/
  `test:`/`chore:`/`ci:`/`build:`/`perf:`). No body, no bullet list.
- **No AI attribution of any kind** — no `Co-Authored-By`, no "Generated with …", never name
  any AI tool in the message.

## Code
- Files **≤ 250 lines**; split when they grow (SwiftLint `file_length`).
- **No `print`** in `Sources/` — use `os.Logger` (SwiftLint custom rule).
- **Pure core stays pure**: `Models`/`State` never import UI/EventKit/Network (`check-layers`).
- Format with SwiftFormat; lint clean under `swiftlint --strict`.

## Docs
- `AGENTS.md` is the ~100-line map; the truth lives in `docs/`. Link, don't copy.
- **Write concise docs** — every token competes with the task; cut hedging and repetition.
- Every source file appears in [`generated/repo-map.md`](../generated/repo-map.md) (`check-docs`).
- Behavior changes update `[Unreleased]` in [`../../CHANGELOG.md`](../../CHANGELOG.md); if code
  diverges from a `current` design doc, update it or mark it `stale` in [`index.md`](index.md).

## Workflow
- `make hooks` once; then pre-commit runs `make scan`, pre-push runs `make ci`. Never push red.
