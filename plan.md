# SwiftOnig Modernization Plan

This document outlines the strategy for modernizing the `SwiftOnig` library to align with modern Swift standards (Swift 6.0+) and best practices.

## 1. Current Implementation Review (The "Bad" Parts)
The current implementation, while functional, suffers from several architectural and stylistic issues that hinder its usability in modern Swift environments:

*   **Outdated Synchronization**: Uses a global `onigQueue: DispatchQueue` for thread safety. This is a "stop-the-world" approach that doesn't scale well with modern Swift Concurrency (`async/await`, `Task`, `Actors`).
*   **C-Centric API Naming**: Many methods mirror the underlying `oniguruma` C functions (e.g., `matchedByteCount`, `isMatch`, `firstIndex`). These don't follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) (e.g., "prefer `matches` over `isMatch`").
*   **Manual Memory Management**: Relies heavily on manual `init`/`deinit` cycles with raw pointers. While necessary for C-interop, it lacks higher-level Swift abstractions like `ManagedBuffer` to ensure memory safety and simplify the codebase.
*   **Complex String Handling**: The `OnigurumaString` protocol and its `withOnigurumaString` implementation are verbose and could be simplified using modern Swift's `withUnsafeBytes` and `ContiguousBytes`.
*   **Lack of Concurrency Support**: Core types like `Regex` and `Region` are not `Sendable`, making them difficult and unsafe to pass between concurrent tasks without manual synchronization.

## 2. Clean Slate Approach (What I'd do from scratch)
If rebuilding `SwiftOnig` today, the architecture would focus on being a "Swift-first" wrapper:

*   **Synchronization**: Replace `DispatchQueue` with `Mutex` (Swift 6.0+) for low-level pointer access and `Actors` for high-level library state management (e.g., a `GlobalActor` for `onig_initialize`).
*   **Concurrency**: Ensure all public-facing types conform to `Sendable`. Provide `async` versions of long-running operations (like `scan` or complex searches) to keep the calling thread responsive.
*   **API Design**: Strictly follow Swift conventions. Use `some` and `any` types for better abstraction. Provide a `RegexBuilder` DSL implementation by conforming to `RegexComponent`.
*   **Memory Safety**: Wrap all C pointers (`OnigRegex`, `OnigRegion`) in dedicated, private Swift classes or `ManagedBuffer` instances that handle their own lifecycle safely.
*   **Collection Conformance**: Implement `RandomAccessCollection` for `Region` with a modern `Index` type, allowing for idiomatic Swift collection manipulations.
*   **Modern Testing**: Use the new `Testing` framework (Swift 6.0+) for clearer, more expressive unit tests and better integration with Xcode's testing tools.

## 3. Infrastructure & Tooling Upgrade
- [x] **Swift Version**: Update `Package.swift` to `swift-tools-version:6.0`.
- [x] **Strict Concurrency**: Enable `.enableUpcomingFeature("StrictConcurrency")` in `Package.swift`.
- [x] **SwiftLint/SwiftFormat**: Integrate automated linting and formatting.
- [x] **CI/CD**: Ensure GitHub Actions test on macOS and Linux with the latest Swift toolchain.

## 4. Swift Concurrency & Thread Safety
- [x] **Global Synchronization**: Replace `onigQueue` with `Mutex` or a `GlobalActor`.
- [x] **Sendable Conformance**: Make `Regex`, `Syntax`, `Encoding`, and `Region` `Sendable`.
- [x] **Async APIs**: Introduce `async` versions of search and scan operations.

## 5. API Modernization
- [x] **Naming Conventions**: Audit and rename public APIs (e.g., `isMatch` -> `matches(_:)`).
- [x] **Opaque Types**: Use `some` and `any` keywords where appropriate.
- [x] **Result & Error Handling**: Refine `OnigError` for better diagnostics.
- [x] **Collection Conformance**: Modernize `Region` collection conformance.

## 6. Standard Library Integration
- [x] **Swift `Regex` Interop**: Explore bridging to `Swift.Regex`.
- [x] **Regex Builder**: Implement `RegexComponent` support.

## 7. Porting Oniguruma Official Tests
- [x] **Testing DSL**: Create a Swift-based DSL (using `swift-testing`) that mirrors Oniguruma's C macros (`x2`, `x3`, `n`, `e`) for concise test definitions.
- [x] **Test Suites**: Port the following suites from the official Oniguruma repository:
    - `test_utf8.c`: Comprehensive UTF-8 and regex feature tests.
    - `test_syntax.c`: Different syntax modes and edge cases.
    - `test_options.c`: Regex compilation and search options.
    - `test_back.c`: Backtracking and recursion tests.
    - `test_regset.c`: Regex set search behavior and lead modes.
    - `testc.c`: Native EUC-JP test corpus.
    - `testu.c`: UTF-16BE byte-oriented test corpus.
- [x] **Validation**: Ensure all ported tests pass against the modernized `SwiftOnig` implementation.

## 8. Documentation & Quality
- [x] **DocC Integration**: Convert comments to DocC and add high-level articles.
- [x] **Unit Tests**: Migrate to or add tests using the new `Testing` framework.
- [x] **Benchmarks**: Implement performance benchmarks.

## 9. Execution Strategy
1. **Phase 1: Foundation**: Upgrade `Package.swift`, enable strict concurrency, and fix immediate compiler warnings.
2. **Phase 2: Concurrency**: Implement `Sendable` and modern synchronization.
3. **Phase 3: Refinement**: Rename APIs and improve collection conformances.
4. **Phase 4: Ecosystem**: Add DocC, `RegexBuilder` support, and `swift-testing`.
5. **Phase 5: Porting Tests**: Implement the testing DSL and port the Oniguruma test suites.

## 10. Oniguruma Packaging Migration

This section tracks the packaging refactor from a system-installed Oniguruma dependency to a vendored source build managed directly by SwiftPM.

### Chosen Decisions

- [x] Vendor Oniguruma as a Git submodule.
- [x] Build Oniguruma from source instead of relying on `pkg-config`, `apt`, or `brew`.
- [x] Merge the current `COnig` and `OnigInternal` targets into one C-facing target named `OnigurumaC`.
- [x] Preserve the current public Swift API while restructuring the package internals.

### Phased Implementation Checklist

- [x] **Step 1: Extend planning docs**
  - Record the vendoring strategy and phased rollout in this document.
  - Keep the package build unchanged in this step.

- [x] **Step 2: Add vendored source**
  - Add the upstream Oniguruma repository as a pinned Git submodule under `Vendor/Oniguruma`.
  - Document the need to initialize submodules for contributors.

- [x] **Step 3: Introduce merged `OnigurumaC` target**
  - Add a new source-based C target in parallel with the legacy bridge layout.
  - Move or copy the helper wrapper layer into the new target.
  - Compile vendored Oniguruma source files through SwiftPM.

- [x] **Step 4: Switch Swift targets to `OnigurumaC`**
  - Replace `COnig` and `OnigInternal` imports with `OnigurumaC`.
  - Keep helper symbol names stable unless a compile fix requires a local rename.
  - Validate all examples, benchmarks, and tests against the merged target.

- [x] **Step 5: Remove legacy bridge targets**
  - Delete the `COnig` system-library target and the `OnigInternal` helper target.
  - Remove old source directories and all package-manager wiring for system-installed Oniguruma.

- [x] **Step 6: Finalize source-build documentation**
  - Update `README.md` to describe vendored-source builds and submodule setup.
  - Mark this migration complete once all validation is green.

## 11. Refactor Roadmap

- [x] **Runtime Layer Split**: Move global runtime state, initialization, version/copyright helpers, and low-level Oniguruma dispatch helpers out of `SwiftOnig.swift` into dedicated runtime-focused files.
- [x] **C Globals Cleanup**: Reduce repetitive `OnigCGlobals` and `CGlobals.c` constant plumbing with a smaller or more data-driven bridge surface.
- [x] **Owned C Resource Abstraction**: Introduce a shared internal ownership pattern for `Regex`, `Region`, and `RegexSet` pointer-backed resources.
- [x] **Sync/Async API Consolidation**: Remove duplicated sync and async wrapper bodies where both paths already share the same implementation.
- [x] **String Input Adapters**: Split `StringUtils.swift` into more focused UTF-8, UTF-16, and raw-byte bridging layers.
- [x] **Encoding Registry Refactor**: Replace the large encoding mapping ladder in `Encoding.swift` with a clearer table-driven implementation.
- [x] **Syntax Ownership Model**: Separate borrowed predefined syntax presets from owned mutable syntax values to make mutation rules explicit.
- [x] **Error Metadata Refactor**: Rework `OnigError` mapping into smaller metadata-driven components with clearer diagnostics plumbing.
- [x] **RegexSet Builder Cleanup**: Consolidate repeated `RegexSet` initialization logic and add earlier compatibility validation.
- [x] **RegexSet Copy-on-Write Mutations**: Reuse uniquely owned regset storage for append, replace, and remove while preserving value semantics for shared copies.
- [x] **Test Suite Organization**: Reorganize tests by behavior layers so future refactors are easier to validate and localize.

## 12. Remaining Oniguruma Feature Gaps

- [x] **Regex MatchParam Integration**: Add `MatchParam` overloads to the main `Regex` search and match APIs and route them through `onig_search_with_param()` / `onig_match_with_param()`.
- [x] **Missing Option Flags**: Expose the remaining upstream compile and search option flags in `Regex.Options` and `Regex.SearchOptions`.
- [x] **Whole Match Convenience**: Add higher-level whole-string match APIs backed by Oniguruma whole-match semantics.
- [x] **Missing Syntax Presets and Flags**: Expose `Syntax.python` plus the remaining upstream syntax flags currently absent from `Operators` and `Operators2`.
- [x] **Regex Capture Metadata Gap**: Expose `Regex.nonameGroupCaptureIsActive`.
- [x] **Encoding Boundary Helpers**: Implement the pending encoding cursor and length helpers in `Encoding`.
- [x] **Runtime Warning Hooks**: Add actor-isolated APIs for standard and verbose Oniguruma warning callbacks.
- [x] **User Unicode Properties**: Add registration APIs for custom Unicode properties.
- [x] **Swift-Native Callouts**: Add Swift-native registration and execution support for named/content callouts and per-match callout handlers.
- [x] **Mutable RegexSet Operations**: Add append, replace, and remove operations while preserving regset invariants.

## 13. String API Migration Planning

- [x] Move the string-native API migration design document under `Docs/`.
- [x] Record the raw-input design principle that raw encoded workflows should stay modeled as byte containers plus explicit `Encoding`, not one high-level wrapper type per encoding.
- [x] Implement the string-native `Regex.Match` migration described in [`Docs/string-match-migration-plan.md`](Docs/string-match-migration-plan.md).

## 14. UTF-16 API Consolidation

- [x] Record that UTF-16 remains supported, but the preferred raw-input model is still byte containers plus explicit `Encoding`, not a dedicated family of encoding-specific wrapper types.
- [x] Migrate docs and benchmarks to prefer raw UTF-16 bytes over `UTF16CodeUnitBuffer` as the public advanced-path recommendation.
- [x] Remove `UTF16CodeUnitBuffer`; raw UTF-16 byte buffers plus explicit `Encoding` fully cover the supported advanced path.

## 15. Swift Regex String API Parity

- [x] Record the verified standard-library string regex APIs and the recommended parity phases in [`Docs/swift-regex-string-api-parity-plan.md`](Docs/swift-regex-string-api-parity-plan.md).
- [x] Implement Phase 1 parity APIs: `contains(_:)`, `matches(of:)`, and `ranges(of:)` for `String` and `Substring`.
- [x] Implement Phase 2 parity APIs: `replacing(_:with:)` and mutating `replace(_:with:)`.
- [x] Implement Phase 3 convenience APIs: `split(separator:)` and `trimmingPrefix(_:)`.

## 16. Regex Initialization Sync Migration

- [x] Record the design for removing `async` from public `Regex` initializers in [`Docs/regex-init-sync-migration-plan.md`](Docs/regex-init-sync-migration-plan.md).
- [x] Introduce a synchronous internal runtime initialization path for regex compilation.
- [x] Make public `Regex` initializers synchronous and migrate affected call sites.
- [x] Re-evaluate `RegexSet` and related APIs that may only be async because of regex compilation.
- [x] Update README, DocC, examples, and tests to remove `await` from regex compilation where no longer needed.

## 17. Oniguruma Runtime Namespace Migration

- [x] Record the runtime namespace reorganization design in [`Docs/oniguruma-runtime-namespace-plan.md`](Docs/oniguruma-runtime-namespace-plan.md).
- [ ] Introduce `Oniguruma` as the synchronous namespace for advanced runtime-control APIs.
- [ ] Move runtime metadata, default encoding, match defaults, and global limit controls under `Oniguruma`.
- [ ] Migrate docs, tests, and examples from top-level runtime functions to the `Oniguruma` namespace.
- [ ] Remove the old top-level runtime-control functions and `Regex`-scoped global limit surface.

## 18. Coverage Improvement Push

- [ ] Add targeted tests for low-coverage error and runtime utility paths in `Error.swift`, `OnigOwnedResource.swift`, and `OnigurumaRuntime.swift`.
- [ ] Add targeted tests for low-coverage string/input adapter paths in `StringUtils.swift` and `Regex+Match.swift`.
- [ ] Re-run code coverage and continue iterating on the worst remaining files until the easy uncovered branches are exhausted.

## 19. Oniguruma API Parity Gap Notes

### Worth Exposing Later

- [ ] Add an explicit error-message helper for raw Oniguruma error codes, analogous to `onig_error_code_to_str`, for advanced debugging and interop scenarios.
- [ ] Evaluate whether SwiftOnig should expose an advanced compile path analogous to deprecated `onig_new_deluxe` when a caller truly needs pattern/input encoding combinations that differ from the current one-encoding-per-regex model.

### Intentionally Not Exposing

- [x] Keep `onig_new_without_alloc` and `onig_free_body` unwrapped; they are C memory-management hooks, not Swift-first public API.
- [x] Keep regset low-level introspection APIs (`onig_regset_number_of_regex`, `onig_regset_get_regex`) unwrapped as standalone surface; `RegexSet.count`, collection conformance, and subscripting already cover their useful behavior.
- [x] Keep callback-each-match as a higher-level Swift API (`scan`, `enumerateMatches`) rather than exposing the raw `ONIG_OPTION_CALLBACK_EACH_MATCH` callback contract directly.

## 20. Swifty API Cleanup Pass

- [x] Record the remaining non-Swifty public APIs and the leftover unnecessary async surface in [`Docs/swifty-api-cleanup-plan.md`](Docs/swifty-api-cleanup-plan.md).
- [x] Remove the final unnecessary public async accessor from `Regex`.
- [x] Replace `MatchParam` with immutable `Regex.MatchConfiguration`.
- [x] Introduce `RegexSet.Match` and rename `firstSetMatch` to `firstMatch`.
- [ ] Make callout raw-offset naming explicit and continue treating callouts as advanced raw APIs.
- [ ] Revisit Unicode-property public modeling around `Unicode.Scalar` and de-emphasize `OnigCodePoint` in the public surface.
