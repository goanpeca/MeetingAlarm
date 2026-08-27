## What & why

<!-- One or two sentences. Link the design-doc section or issue this touches. -->

## Definition of Done

- [ ] `make ci` passes locally (build `-warnings-as-errors`, tests + coverage, layers, module map, format, lint)
- [ ] New/changed pure logic has tests; the coverage gate is still green
- [ ] Any new source file is added to the [module map](../docs/architecture/modules.md) (`check-docs`)
- [ ] Design/architecture docs updated — or marked `stale` in the [design-docs INDEX](../docs/design-docs/INDEX.md) — if behavior changed
- [ ] Knowingly-deferred work logged in [technical-debt](../docs/technical-debt/README.md)
- [ ] Commits: one line, < 72 chars, Conventional-Commit prefix, **no AI attribution**
- [ ] Invariants held (if touched): `Esc always dismisses`, secrets only in Keychain, no `print` in `Sources/`
