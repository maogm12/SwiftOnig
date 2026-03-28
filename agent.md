# Workspace Agent Guidance

This file captures repo-specific working rules for agents collaborating in this workspace.

## Overview

- This repository is a Swift 6 package wrapping the Oniguruma regex library.
- The main library code lives in `Sources/SwiftOnig`.
- Vendored Oniguruma C sources and helper wrappers live in `Sources/OnigurumaC`.
- Tests live in `Tests/SwiftOnigTests` and use `swift-testing`, not XCTest manifests.
- Example executables live in `Examples/`.
- Benchmarks live in `Benchmarks/`.

## Git

- Preferred prefixes:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `chore:` for maintenance or repo housekeeping
  - `test:` for test-only changes
  - `docs:` for documentation-only changes
  - `refactor:` for behavior-preserving code reshaping
- Do not create bare commit titles such as `Add X`; use `feat: add X` instead.
- Keep commits scoped to a single logical step whenever possible.
- Do not include unrelated user files in commits.
- Leave untracked or unrelated files alone unless explicitly asked to handle them.

## Versioning


- Use Semantic Versioning.
- Track release notes in `CHANGELOG.md`.
- For every commit, explicitly decide whether the change requires a version bump.
- If a bump is needed, update the top `Unreleased` or new release section in `CHANGELOG.md`.
- When the package version changes, create the matching Git tag for the new version because SwiftPM resolves releases from tags.
- Bump rules:
  - `MAJOR` for breaking public API or CLI contract changes, always ask for approval for MAJOR version bump
  - `MINOR` for backward-compatible features
  - `PATCH` for backward-compatible fixes, docs-affecting packaging changes, or release housekeeping tied to published artifacts
- If a commit is purely local workflow guidance and does not affect the library or release artifacts, note that no bump is needed.

## Testing

- Run `swift test` before each commit.
- If you suspect concurrency or discovery issues, also run `swift test --no-parallel`.
- Do not reintroduce `Tests/LinuxMain.swift` or XCTest manifest files unless the user explicitly asks for legacy XCTest support.
- Prefer adding or updating `swift-testing` suites in `Tests/SwiftOnigTests`.
- When changing behavior around encodings, named captures, syntax flags, or search semantics, add or update targeted tests.

## Oniguruma and C Interop

- Treat changes in `Sources/OnigurumaC` and `Vendor/Oniguruma` as high risk.
- Preserve pointer lifetime and ownership rules carefully.
- Prefer existing safe wrapper paths over adding new direct C API calls unless necessary.
- Be cautious with APIs that hand back borrowed pointers or arrays from Oniguruma.
- When changing regex or region internals, verify both native `swift test` runs and the affected targeted tests.
- Initialize submodules before C-layer work with `git submodule update --init --recursive`.

## Concurrency and API Design

- This package is written for Swift 6 with strict concurrency enabled.
- Avoid introducing non-`Sendable` state into public APIs without a strong reason.
- Respect the `OnigurumaActor` isolation model for global library state and syntax mutation.
- If a synchronous access pattern works inside actor isolation, do not add unnecessary `await`s.

## Editing

- Prefer focused, minimal edits.
- Preserve the existing Swift-first wrapper style rather than mirroring C naming unnecessarily.
- Keep public API changes deliberate and well-tested.
- Avoid adding compatibility shims that duplicate test execution or mask native runner failures.

## Documentation and Planning

- Update `README.md` or DocC content when user-facing behavior materially changes.
- Treat `plan.md` as the source of truth for tracked work in this repository.
- Add new implementation tasks to `plan.md` before or as part of the work when they are meant to be tracked.
- Whenever a tracked task is completed, update `plan.md` and check it off in the same step.

## Design Review Guidance

Use the rules below when reviewing any design doc in this repository.

### Review Goal

Decide exactly one:

- `continue_design`
- `ready_for_build`
- `blocked`

Do not keep design discussion going without a concrete reason.

### Required Steps

Before reviewing:

1. Read the whole file.
2. Find `Status`.
3. Check `Open Questions`.
4. Check `Design Exit Criteria`.
5. Check `Stop Rule`.
6. Read the latest `Discussion Log`.

If a section is missing, say so. Do not guess missing context.

### Review Rules

- If status is `exploring`, review options and tradeoffs.
- If status is `narrowing`, focus only on unresolved decisions.
- If status is `decided`, do not reopen design unless there is a contradiction, missing constraint, or serious risk.
- If status is `ready_for_build`, stop design review and check only implementation readiness.
- If status is `blocked`, state exactly what input is missing.

Treat the task as `ready_for_build` when:

- a main approach is chosen
- no top-level alternative is still open
- interfaces are clear enough to implement
- remaining questions are implementation details
- major risks are already recorded

### Review Output Format

```md
Status Decision: continue_design | ready_for_build | blocked

Summary:
<1-2 sentence conclusion>

Findings:
- <key issue or confirmation>
- <key issue or confirmation>

Open Questions:
- <question>
- <question>

Next Action:
- <one concrete next step>
```

### Review Priorities

Review in this order:

1. contradictions
2. missing constraints
3. unclear interfaces
4. untracked risks
5. implementation readiness

Only suggest new alternatives if the current design is materially flawed.

## Practical Checks

- If `swift test` fails unexpectedly, first confirm the Oniguruma submodule is initialized and the vendored source tree is present.
- Watch for behavior drift caused by different Oniguruma versions, especially in syntax flags, encodings, named groups, and capture history features.
- Prefer verifying assumptions with small targeted tests over relying on comments from older implementations.
