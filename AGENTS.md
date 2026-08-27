# AGENTS.md — meeting-alarm

> Navigation map, not an encyclopedia. This file is a **table of contents** with
> progressive disclosure: it points to the real source of truth in `docs/`. Keep
> it short (~100 lines). When something here would go stale, link instead of copy.
>
> Shared entry point for both agents: **OpenAI Codex** reads this file natively;
> **Claude Code** reads it via `CLAUDE.md`, which imports it. Edit this file — not
> `CLAUDE.md` — so guidance never drifts between the two.

## What this is

A macOS **menu-bar app** that makes meetings impossible to miss: it reads your
calendar, lets you arm an extra alarm per meeting, and throws a full-screen
overlay (with optional sound) across every display at the chosen time. Alerts run
on a configurable **sensory profile** with two presets — **Blast** (max-intensity)
and **Gentle Ramp** (predictable, sensory-safe; see the design doc §9).

## Start here

- **Design (system of record):** [`docs/design-docs/2026-08-26-meeting-alarm-design.md`](docs/design-docs/2026-08-26-meeting-alarm-design.md)
  (catalog: [`docs/design-docs/INDEX.md`](docs/design-docs/INDEX.md))
- **Architecture map & layers:** [`docs/architecture/overview.md`](docs/architecture/overview.md)
- **Module map (every file, verified):** [`docs/architecture/modules.md`](docs/architecture/modules.md)
- **Golden principles (mechanical rules):** [`docs/principles/golden-principles.md`](docs/principles/golden-principles.md)
- **Quality grades & coverage bar:** [`docs/quality/quality.md`](docs/quality/quality.md)
- **Known issues:** [`docs/technical-debt/README.md`](docs/technical-debt/README.md)
- **Plans & progress:** [`docs/execution-plans/`](docs/execution-plans/)
- **Human setup (Google, permissions):** [`README.md`](README.md)
- **Contributing (hooks, the loop):** [`CONTRIBUTING.md`](CONTRIBUTING.md) · docs index: [`docs/README.md`](docs/README.md)

## Layers (imports point up only)

```
Models      pure value types (Meeting, SensoryProfile)      — no UI/IO
State       persistence (Store, Keychain)                   — imports Models
Services    calendar sources, alarm scheduler, overlay      — imports Models, State
Runtime/UI  App entry, menu & settings views                — imports all below
```

Purity is enforced mechanically by `scripts/check-layers.sh` (Models/State may not
import UI/EventKit/Network frameworks). Details:
[`docs/architecture/overview.md`](docs/architecture/overview.md).

## Where code lives

Every file is catalogued in the **[module map](docs/architecture/modules.md)**, kept in sync
mechanically (see `check-docs`). By layer:

- `Sources/MeetingAlarm/Models/` — pure value types (`Meeting`, `SensoryProfile`, …)
- `Sources/MeetingAlarm/State/` — persistence (`Store`, `Keychain`)
- `Sources/MeetingAlarm/Calendar/` — `CalendarSource` protocol, EventKit + Google impls
- `Sources/MeetingAlarm/Alarm/` — scheduler, overlay, sound
- `Sources/MeetingAlarm/UI/` — menu popover, settings, summonable quick panel
- `Sources/MeetingAlarm/App.swift` + `AppCoordinator*` — `@main` entry + coordination
- `Sources/MeetingAlarm/{GlobalHotKey,LoginItem,Logging}.swift` — cross-cutting runtime
- `Tests/MeetingAlarmTests/` — Swift Testing unit tests for the pure core

## Commands

```bash
make build         # swift build
make test          # swift test
make coverage      # tests + coverage gate (>= 70% on the pure core)
make check-layers  # architectural import purity
make check-docs    # module map (docs) stays in sync with Sources/
make check-workflows # GitHub Actions workflow YAML is valid
make lint          # swiftlint --strict
make format        # swiftformat . (format-check = --lint)
make scan          # all mechanical checks together (fast: no build/test)
make ci            # the exact gate CI runs — reproduce locally before pushing
make hooks         # install pre-commit (scan) + pre-push (ci) git hooks
make mutation      # muter mutation testing (slow, on demand; tests the tests)
make app           # assemble + ad-hoc-sign MeetingAlarm.app
make run           # build app bundle and open it
```

Run `make hooks` once after cloning: commits are then gated by `make scan` and pushes by
`make ci`, so drift and build/test breakage never reach CI.

Tooling: Swift 6.3 / **Xcode 26** (pinned for reproducible builds in `.xcode-version` and via
`setup-xcode` in CI), macOS 14+. Install lint/format once with `brew install swiftformat swiftlint`.

## Non-negotiable invariants

- **Esc always dismisses** the overlay — it can never trap the user.
- **Secrets only in Keychain** — never `UserDefaults`, never logs.
- **No `print`** in `Sources/` — use `os.Logger`. (Enforced by SwiftLint.)
- **Files ≤ ~250 lines**; split when they grow. (Enforced by SwiftLint.)
- **Pure logic stays pure** so it's testable without a screen/network.
- **Every source file is in the [module map](docs/architecture/modules.md)** — a new file
  needs a one-line row in the same change. (Enforced by `check-docs`.)

## Conventions for changes

1. Read the design doc section you're touching; if code diverges, update the doc
   or mark it `stale` in `docs/design-docs/INDEX.md` in the same change.
2. Add tests for pure logic; keep the coverage gate green.
3. Run `make scan` before committing.
4. Commits: **one line only, under 72 chars, Conventional-Commit prefix**
   (`feat:`/`fix:`/`docs:`/`refactor:`/`test:`/`chore:`…), no body, no bullet list.
5. **Never add AI attribution of any kind** to a commit or PR — no
   `Co-Authored-By`, no `Signed-off-by`, no "Generated with Claude / Codex / …",
   and never name Claude, Codex, Anthropic, OpenAI, or any AI tool anywhere in the
   message. Check the message before finalizing so a trailer never slips back in.
