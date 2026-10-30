## What & why

<!-- One or two sentences. Link the design-doc section or issue this touches. -->

## Testing

<!-- What you ran and the result: `make ci`, specific tests, manual checks (list them). Show output, don't claim. -->

## Risk & how to revert

<!-- Blast radius if this is wrong, and the one step to undo it (revert commit / flip setting / which files). -->

## Definition of Done

- [ ] `make ci` passes locally (build `-warnings-as-errors`, tests + coverage, layers, module map, format, lint)
- [ ] New/changed pure logic has tests; the coverage gate is still green
- [ ] Any new source file is added to the [module map](../docs/generated/repo-map.md) (`check-docs`)
- [ ] Behavior change has a **changeset** (`make changeset`) — don't hand-edit `CHANGELOG.md`
- [ ] Design/architecture docs updated — or marked `stale` in the [design-docs INDEX](../docs/design-docs/index.md) — if behavior changed
- [ ] Knowingly-deferred work logged in [technical-debt](../docs/exec-plans/tech-debt-tracker.md)
- [ ] Review ([`REVIEW.md`](../REVIEW.md)) is clean: no open **Important**/Security finding
- [ ] Commits: one line, < 72 chars, Conventional-Commit prefix, **no AI attribution**
- [ ] Invariants held (if touched): `Esc always dismisses`, secrets only in Keychain, no `print` in `Sources/`
