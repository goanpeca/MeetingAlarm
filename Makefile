.PHONY: build run app test coverage lint format format-check check-layers check-docs scan ci hooks clean

APP = MeetingAlarm.app

## build: compile the package
build:
	swift build

## app: assemble + sign MeetingAlarm.app (auto-creates a stable dev identity)
app:
	./scripts/make_app.sh

## run: build the app bundle and launch it
run: app
	open $(APP)

## test: run the unit tests
test:
	swift test

## coverage: run tests with coverage and enforce the gate
coverage:
	swift test --enable-code-coverage
	./scripts/coverage-gate.sh

## lint: SwiftLint (strict)
lint:
	swiftlint --strict

## format: apply SwiftFormat in place
format:
	swiftformat .

## format-check: verify formatting without changing files
format-check:
	swiftformat --lint .

## check-layers: enforce architectural import purity
check-layers:
	./scripts/check-layers.sh

## check-docs: enforce the module map (docs/architecture/modules.md) stays in sync
check-docs:
	./scripts/check-docs.sh

## scan: all mechanical checks (the local "harness" drift scan)
scan: check-layers check-docs format-check lint

## ci: the exact gate GitHub runs — reproduce it locally before pushing
ci:
	swift build -Xswiftc -warnings-as-errors
	swift test --enable-code-coverage
	./scripts/coverage-gate.sh
	./scripts/check-layers.sh
	./scripts/check-docs.sh
	swiftformat --lint .
	swiftlint --strict

## hooks: install git hooks (pre-commit = make scan, pre-push = make ci)
hooks:
	git config core.hooksPath .githooks
	@echo "Installed .githooks — pre-commit runs 'make scan', pre-push runs 'make ci'."

## clean: remove build products
clean:
	swift package clean
	rm -rf $(APP) .build
