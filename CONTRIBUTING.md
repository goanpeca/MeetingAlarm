# Contributing

This repo is harness-engineered: the docs are the source of truth and the constraints are
enforced by machines, not vibes. Start at **[`AGENTS.md`](AGENTS.md)** (Codex reads it
natively; Claude Code imports it via `CLAUDE.md`).

## First time

```bash
brew install swiftformat swiftlint
make hooks   # installs pre-commit (make scan) + pre-push (make ci)
```

## The loop

- `make scan` — fast drift gate: layers, module map, format, lint. Runs on every **commit**.
- `make ci` — the exact gate GitHub runs: build (`-warnings-as-errors`), tests + coverage,
  all scans. Runs on every **push**.
- `make run` — build + launch the app.
- `make mutation` — optional, on demand: [muter](https://github.com/muter-mutation-testing/muter)
  mutation testing to check the tests actually catch regressions (slow; not in CI).
  Install once: `brew install muter-mutation-testing/formulae/muter`.

Never push red — the pre-push hook runs `make ci`, so fix it locally first. Bypass a hook
only in a genuine emergency with `--no-verify`.

## Golden rules (mechanically enforced)

- Files ≤ 250 lines; the pure core stays pure (`check-layers`); every source file appears in
  the [module map](docs/generated/repo-map.md) (`check-docs`); ≥ 85% coverage on the core.
- Commits: one line, < 72 chars, Conventional-Commit prefix (`feat:`/`fix:`/`docs:`/…),
  **no AI attribution of any kind**.
- Behavior changes update the `[Unreleased]` section of [`CHANGELOG.md`](CHANGELOG.md).

The full list is in [`docs/design-docs/core-beliefs.md`](docs/design-docs/core-beliefs.md).
