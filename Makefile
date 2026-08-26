.PHONY: build run app test coverage lint format format-check check-layers scan clean

APP = MeetingAlarm.app

## build: compile the package
build:
	swift build

## app: assemble + ad-hoc-sign MeetingAlarm.app
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

## scan: all mechanical checks (the local "harness" drift scan)
scan: check-layers format-check lint

## clean: remove build products
clean:
	swift package clean
	rm -rf $(APP) .build
