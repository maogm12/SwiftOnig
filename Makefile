SWIFT_SOURCES := Sources Tests Examples Benchmarks

.PHONY: test test-no-parallel lint format

test:
	swift test

test-no-parallel:
	swift test --no-parallel

lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --strict; \
	else \
		echo "swiftlint is not installed. Install it locally to run 'make lint'."; \
		echo "Suggested macOS install: brew install swiftlint"; \
		exit 1; \
	fi

format:
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat $(SWIFT_SOURCES); \
	else \
		echo "swiftformat is not installed. Install it locally to run 'make format'."; \
		echo "Suggested macOS install: brew install swiftformat"; \
		exit 1; \
	fi
