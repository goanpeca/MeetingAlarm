# Golden Principles

Subjective taste encoded as mechanical, checkable rules. Each principle names how
it is enforced. If a rule isn't enforceable yet, it says so — prefer moving rules
from "reviewed" to "enforced" over time.

## Structure

1. **Files stay small — ≤ 250 lines.** Outgrowing it means the file does too much;
   split it. *Enforced:* SwiftLint `file_length` (warn 250 / error 400) + the
   scheduled file-size scan.
2. **Every source file maps to exactly one layer folder** (`Models`, `State`,
   `Calendar`, `Alarm`, `UI`). *Reviewed;* folder is the layer.
3. **Imports point up only.** A lower layer never depends on a higher one.
   *Enforced (framework purity):* `scripts/check-layers.sh` — Models/State may not
   import UI/EventKit/Network frameworks.

## Purity & testability

4. **Pure logic stays pure.** Fire-time math, preset definitions, and JSON→model
   mapping live in functions with **no** AppKit/EventKit/URLSession import, so they
   unit-test without a screen or network. *Enforced:* layer check + coverage gate.
5. **Represent data as plain values at the boundary.** e.g. color is `RGBAColor`
   (components), not `NSColor`. *Reviewed;* see `RGBAColor` for the pattern.

## Safety & privacy

6. **The overlay is always dismissible with Esc.** It can never trap the user,
   regardless of a profile's configured dismissal. *Reviewed + tested* (overlay
   tests assert an Esc path once the overlay lands).
7. **No stored credentials.** EventKit-only — the app holds no OAuth tokens or
   secrets, so there's nothing sensitive to leak. *Reviewed.*
8. **Calendar access is read-only.** The app never writes to a calendar.

## Observability

9. **No `print` in `Sources/`.** Use one `os.Logger` per subsystem
   (`subsystem: "com.goanpeca.MeetingAlarm"`, a `category:` per component).
   *Enforced:* SwiftLint custom rule `no_print`.

## Process

10. **Docs don't silently drift.** When code diverges from a `current` design doc,
    update the doc or mark it `stale` in `docs/design-docs/index.md` in the same
    change.
11. **Keep the gates green.** `make scan` (layers + format + lint) and the coverage
    gate pass before every commit.
12. **Commits:** single line, `< 72` chars, Conventional-Commit prefix, and **no**
    AI/assistant attribution of any kind.
