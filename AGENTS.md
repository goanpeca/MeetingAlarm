# AGENTS.md — meeting-alarm

> Navigation map, not an encyclopedia. This file is a **table of contents** with
> progressive disclosure: it points to the real source of truth in `docs/`. Keep
> it short (~100 lines). When something here would go stale, link instead of copy.
>
> Canonical guide for every agent: **Codex** reads it natively; **Claude Code**
> (`CLAUDE.md`) and **Gemini** (`GEMINI.md`) point here. Edit this file, not the stubs,
> so guidance never drifts.

## What this is

A macOS **menu-bar app** that makes meetings impossible to miss: it reads your
calendar, lets you arm an extra alarm per meeting, and throws a full-screen
overlay (with optional sound) across every display at the chosen time. Alerts run
on a configurable **sensory profile** with two presets — **Blast** (max-intensity)
and **Gentle Ramp** (predictable, sensory-safe; see the design doc §9).

## Start here

- **Design (system of record):** [`docs/design-docs/2026-08-26-meeting-alarm-design.md`](docs/design-docs/2026-08-26-meeting-alarm-design.md)
  (catalog: [`docs/design-docs/index.md`](docs/design-docs/index.md))
- **Architecture map & layers:** [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Module map (every file, verified):** [`docs/generated/repo-map.md`](docs/generated/repo-map.md)
- **Golden principles (mechanical rules):** [`docs/design-docs/core-beliefs.md`](docs/design-docs/core-beliefs.md)
- **Quality grades & coverage bar:** [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md)
- **Known issues:** [`docs/exec-plans/tech-debt-tracker.md`](docs/exec-plans/tech-debt-tracker.md)
- **Plans & progress:** [`docs/exec-plans/`](docs/exec-plans/)
- **Human setup (Calendar permission):** [`README.md`](README.md)
- **Contributing (hooks, the loop):** [`CONTRIBUTING.md`](CONTRIBUTING.md) · docs index: [`docs/README.md`](docs/README.md)

## Layers (imports point up only)

```
Models      pure value types (Meeting, SensoryProfile)      — no UI/IO
State       persistence (Store)                   — imports Models
Services    calendar sources, alarm scheduler, overlay      — imports Models, State
Runtime/UI  App entry, menu & settings views                — imports all below
```

Purity is enforced mechanically by `scripts/check-layers.sh` (Models/State may not
import UI/EventKit/Network frameworks). Details:
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Where code lives

Every file is catalogued in the **[module map](docs/generated/repo-map.md)**, kept in sync
mechanically (see `check-docs`). By layer:

- `Sources/MeetingAlarm/Models/` — pure value types (`Meeting`, `SensoryProfile`, …)
- `Sources/MeetingAlarm/State/` — persistence (`Store`)
- `Sources/MeetingAlarm/Calendar/` — `CalendarSource` protocol + EventKit (macOS Calendar) impl
- `Sources/MeetingAlarm/Alarm/` — scheduler, overlay, sound
- `Sources/MeetingAlarm/UI/` — menu popover, settings, summonable quick panel
- `Sources/MeetingAlarm/App.swift` + `AppCoordinator*` — `@main` entry + coordination
- `Sources/MeetingAlarm/{GlobalHotKey,LoginItem,Logging}.swift` — cross-cutting runtime
- `Tests/MeetingAlarmTests/` — Swift Testing unit tests for the pure core

## Commands

```bash
make build         # swift build
make test          # swift test
make coverage      # tests + coverage gate (>= 90% on the pure core)
make check-layers  # architectural import purity
make check-docs    # module map (docs) stays in sync with Sources/
make check-workflows # GitHub Actions workflow YAML is valid
make check-links   # relative Markdown links resolve
make lint          # swiftlint --strict
make format        # swiftformat . (format-check = --lint)
make scan          # all mechanical checks together (fast: no build/test)
make ci            # the exact gate CI runs — reproduce locally before pushing
make tools         # install the pinned swiftformat/swiftlint into .tools/bin (auto-run by scan/ci)
make hooks         # install pre-commit (scan) + pre-push (ci) git hooks
make mutation      # muter mutation testing (slow, on demand; tests the tests)
make release VERSION=X.Y.Z  # prepare a release: gate + roll CHANGELOG + bump version
make app           # assemble + ad-hoc-sign MeetingAlarm.app
make run           # build app bundle and open it
```

Run `make hooks` once after cloning: commits are then gated by `make scan` and pushes by
`make ci`, so drift and build/test breakage never reach CI.

Tooling: Swift 6.3 / **Xcode 26** (pinned for reproducible builds in `.xcode-version` and via
`setup-xcode` in CI), macOS 14+. Lint/format tools are pinned in `scripts/tool-versions.env` and installed
by `make tools` (run automatically by `make scan` / `make ci`), so local == CI.

## Non-negotiable invariants

- **Esc always dismisses** the overlay — it can never trap the user.
- **No `print`** in `Sources/` — use `os.Logger`. (Enforced by SwiftLint.)
- **Files ≤ ~250 lines**; split when they grow. (Enforced by SwiftLint.)
- **Pure logic stays pure** so it's testable without a screen/network.
- **Every source file is in the [module map](docs/generated/repo-map.md)** — a new file
  needs a one-line row in the same change. (Enforced by `check-docs`.)

## AI-native SDLC (playbook)

This repo pairs **harness engineering** (the substrate above) with the **AI-native SDLC
playbook**, installed as skills in [`.claude/skills/`](.claude/skills/). Begin a change by
invoking **`ai-native-sdlc`**, which routes to the right stage skill (`sdlc-intent` →
`sdlc-spec` → `sdlc-plan` → build → `sdlc-pr-review` …); `sdlc-harness-translate` maps
playbook artifacts onto this repo's harness ones. The intent → spec → plan flow uses the
docs we already keep — no separate `intent/` tree:

| Playbook artifact | Here |
|---|---|
| `intent.md` | `docs/product-specs/<slug>.md` |
| `spec.md` | `docs/design-docs/<slug>.md` (+ index row, verification status) |
| `plan.md` | `docs/exec-plans/active/<slug>.md` → `completed/` at merge |
| policy skill / build hook | a rule in `docs/` + a lint wired into `make ci` |
| review passes | [`REVIEW.md`](REVIEW.md) (bugs / security / compliance), run via `sdlc-pr-review` |
| config evals | [`evals/`](evals/) + `.github/workflows/agent-evals.yml` (starter — see `evals/README.md`) |
| required check | the full gate `make ci`, mirrored in CI |

**Gate posture** (playbook §4 dial): **single-maintainer, minimal gates.** The author is the
sole owner and approver: self-merge once `make ci` is green and the [`REVIEW.md`](REVIEW.md)
passes are clean; human review optional. No code-owner-approval requirement, approval hooks, or
managed settings/sandbox (N/A for a solo project). Revisit and record here if the project gains
other maintainers.

## Conventions

Full list: [`docs/design-docs/conventions.md`](docs/design-docs/conventions.md). In short: add
tests for pure logic; run `make scan` before committing; commits are **one line, < 72 chars,
Conventional-Commit prefix**, and **never carry AI attribution** of any kind; if code diverges
from a `current` design doc, update it or mark it `stale` in the index.
