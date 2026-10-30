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

- **Changes (intent → spec → plan, one folder each):** [`intent/README.md`](intent/README.md)
  — v1 design: [`intent/meeting-alarm-v1/spec.md`](intent/meeting-alarm-v1/spec.md)
- **Architecture map & layers:** [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Module map (every file, verified):** [`docs/generated/repo-map.md`](docs/generated/repo-map.md)
- **Golden principles (mechanical rules):** [`docs/core-beliefs.md`](docs/core-beliefs.md)
- **Quality grades & coverage bar:** [`docs/QUALITY_SCORE.md`](docs/QUALITY_SCORE.md)
- **Known issues:** [`docs/tech-debt-tracker.md`](docs/tech-debt-tracker.md)
- **Review rules:** [`REVIEW.md`](REVIEW.md) · **Issue forms:** bug, feature (intent), task — [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/)
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
make changeset     # add a CHANGELOG changeset (changie new) — never hand-edit CHANGELOG.md
make changelog     # regenerate CHANGELOG.md from changesets (changie merge)
make release VERSION=X.Y.Z  # prepare a release: gate + batch changesets + bump version
make app           # assemble + ad-hoc-sign MeetingAlarm.app
make run           # build app bundle and open it
make install       # build + sign, then install into /Applications (one copy, with icon)
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

This repo follows the **AI-native SDLC playbook** natively, on top of the **harness
engineering** substrate above (mechanical gates, `ARCHITECTURE.md`, module map). The playbook's
skills live in [`.claude/skills/`](.claude/skills/). Begin a change by invoking
**`ai-native-sdlc`**, which routes to the right stage skill (`sdlc-intent` → `sdlc-spec` →
`sdlc-plan` → build → `sdlc-pr-review` …).

| Playbook artifact | Here |
|---|---|
| `intent.md` → `spec.md` → `plan.md` | `intent/<slug>/` — indexed with spec status in [`intent/README.md`](intent/README.md) |
| policy skill / build hook | a rule in `docs/` + a lint wired into `make ci` |
| review passes | [`REVIEW.md`](REVIEW.md) — risk-tiered, evidence-based ([Anthropic code review](https://claude.dev/blog/solving-code-review-at-anthropic/)), via `sdlc-pr-review` |
| change records | changesets in `.changes/` → generated `CHANGELOG.md` ([Changie](https://changie.dev)) |
| config evals | [`evals/`](evals/) + `.github/workflows/agent-evals.yml` (starter — see `evals/README.md`) |
| required check | the full gate `make ci`, mirrored in CI |

**Gate posture** (playbook §4 dial): **single-maintainer, minimal gates.** The author is the
sole owner and approver: self-merge once `make ci` is green and the [`REVIEW.md`](REVIEW.md)
passes are clean; human review optional. No code-owner-approval requirement, approval hooks, or
managed settings/sandbox (N/A for a solo project). Revisit and record here if the project gains
other maintainers.

## Conventions

Full list: [`docs/conventions.md`](docs/conventions.md). In short: add
tests for pure logic; run `make scan` before committing; commits are **one line, < 72 chars,
Conventional-Commit prefix**, and **never carry AI attribution** of any kind; if code diverges
from a `current` spec, update it or mark it `stale` in [`intent/README.md`](intent/README.md). Behavior
changes add a changeset (`make changeset`).
