# Regex Initialization Sync Migration Plan

This document proposes changing SwiftOnig's public regex compilation APIs from `async` to synchronous so they better match Swift developer expectations while preserving runtime safety around Oniguruma's global initialization.

## Status

**Status:** Implemented

The migration has been implemented. Public `Regex` and `RegexSet` compilation APIs are now synchronous, compile-time encoding presets are synchronously accessible, and the runtime bootstrap path uses a synchronous Swift-side lock while explicit global runtime mutation APIs remain actor-isolated.

## Problem Statement

Today, SwiftOnig exposes regex compilation like this:

```swift
let regex = try Regex(pattern: #"\d+"#)
```

This is surprising because regex compilation is local CPU work, not an inherently asynchronous operation. The current `async` requirement exists because public regex initializers are isolated to `@OnigurumaActor`, and callers must cross actor isolation to compile a regex.

Furthermore, dependencies like `Encoding.utf8` and `Syntax.default` are currently actor-isolated, creating a "transitive async" effect where even a synchronous initializer would require `await` to access its arguments.

## Verification Baseline

### Original Implementation Properties
- `Regex.init` was `async throws` and isolated to `@OnigurumaActor`.
- `Encoding` presets were isolated to `@OnigurumaActor`.
- The async requirement came from `OnigurumaActor.shared.ensureInitialized(...)`.
- `OnigurumaActor.ensureInitialized(...)` was internally synchronous actor code.

### C-Layer Verification (Audited March 27, 2026)
Audit of `Vendor/Oniguruma/src/regcomp.c` and `regenc.c` reveals:
- **Lightweight Initialization:** `onig_initialize` simply sets a static flag (`onig_inited`) and calls per-encoding `init` functions.
- **No Internal Locking:** Oniguruma contains **no internal thread-safety** for its initialization flags. Concurrent calls to `onig_initialize` or `onig_new` (which auto-initializes) will race.
- **Auto-Initialization:** `onig_new` (called by `Regex.Storage.init`) will automatically call `onig_initialize` if not already done, but it also lacks locking and produces a console warning.

**Conclusion:** External synchronization is mandatory for safety, but it does not require a full actor-hop if a low-level lock is used.

## Design Exit Criteria

This design is considered ready for build when:

- [x] A single synchronization model for regex compilation-time runtime initialization is chosen: **Option A (Hybrid) with NSLock-backed bootstrap state**.
- [x] The fate of `RegexSet` initialization is decided: **Migrating to synchronous alongside Regex**.
- [x] The boundary between synchronous runtime bootstrap and still-actor-isolated global APIs is clearly written down.
- [x] The de-isolation of `Encoding` and `Syntax` presets is approved.
- [x] Main risks around `uninitialize()` and precompiled regex invalidation are explicitly tracked.

## Stop Rule

Stop this design effort and reconsider the approach if:
- Removing public `async` from regex compilation would require weakening thread-safety around Oniguruma global initialization.
- Runtime initialization cannot be made synchronously safe without broad C-layer changes (Verified: Thread-safety can be achieved with a Swift-side lock).

## Discussion Log

| Date | Decision/Event | Rationale |
| :--- | :--- | :--- |
| 2026-03-27 | Problem Identified | `Regex` compilation being `async` is an API design smell. |
| 2026-03-27 | C-Layer Audit | Verified that Oniguruma initialization is lightweight but lacks internal locking, necessitating a Swift-side sync primitive. |
| 2026-03-27 | Option A Selected | Chose the Hybrid model (synchronous bootstrap lock, actor for mutation) to minimize churn and preserve safety. |
| 2026-03-27 | Dependency De-isolation | Decided to de-isolate `Encoding` and `Syntax` presets to remove "transitive async" blockers. |
| 2026-03-27 | RegexSet Included | Included `RegexSet` in the sync migration for API consistency. |
| 2026-03-27 | Implementation Completed | Landed synchronous bootstrap, synchronous `Regex` / `RegexSet` compilation, and synchronous built-in encoding presets. |

## Recommended Plan

### Goal

Make regex compilation look like this:

```swift
let regex = try Regex(pattern: #"\d+"#)
let set = try RegexSet(patterns: ["a", "b"])
```

### 1. Synchronization Strategy: Option A (Hybrid)
- Introduce an internal synchronous bootstrap path using a private **`NSLock`-guarded bootstrap state**.
- This lock will guard `onig_initialize` and `onig_initialize_encoding` calls.
- **OnigurumaActor** remains the owner of **mutable global state** (e.g., changing warning handlers, registering callouts, or user-defined Unicode properties).

Review note:

- the lock choice is now fixed for this design
- this is no longer an open implementation question
- the final implementation uses `NSLock` rather than `Synchronization.Mutex` because the package still targets macOS 10.15, where `Mutex` is unavailable

### 2. De-isolation of Dependencies
- Audit and modify `Encoding.swift` and `Syntax.swift`.
- Move all static presets (e.g., `.utf8`, `.ascii`, `.ruby`, `.default`) out of `@OnigurumaActor`.
- Ensure `Encoding` and `Syntax` are `Sendable` value-like types that can be safely passed to synchronous initializers.

Safety basis:

- `Encoding` presets are wrappers around stable C-level encoding pointers returned by Oniguruma global accessors
- `Syntax` presets should be exposed as Swift value snapshots or borrowed immutable preset handles, not as mutable shared actor-gated state
- compile-time access to these presets must not require crossing actor isolation

Review tradeoff:

- de-isolating these preset accessors widens synchronous usability significantly
- but it also means the implementation must be explicit about which values are immutable presets versus runtime-mutable shared state

### 3. Synchronous Internal Bootstrap
The new synchronous `Regex` and `RegexSet` initializers will:
1. Call a synchronous `ensureInitialized(encoding:)` helper.
2. The helper will use an internal lock to safely check/set the `isLibraryInitialized` flag and the `initializedEncodings` set.
3. Proceed with `onig_new` or `onig_regset_new` once initialization is guaranteed.

### 4. `RegexSet` Consistency
- `RegexSet.init` will be migrated to `throws` (removing `async`).
- This prevents a disjointed API where some regex-creation paths are sync and others are async.

Target surface:

- pattern-based `RegexSet` initializers should become synchronous alongside `Regex`
- byte-pattern `RegexSet` initializers should also become synchronous if their only async dependency is regex compilation-time runtime bootstrap
- explicit global runtime mutation APIs are not part of this sync migration just because `RegexSet` becomes synchronous

### 5. Actor-Isolated API Boundary
The following will **remain isolated** to `@OnigurumaActor` because they perform true global runtime coordination:
- `initialize(encodings:)` (The explicit pre-warming variant)
- `uninitialize()`
- Warning handler registration (`setWarningHandler`, `setVerboseWarningHandler`)
- User Unicode property registration (`defineUserUnicodeProperty`)
- Callout registration

Clarification:

- explicit `initialize(encodings:)` remains an optional prewarming API
- it is not a prerequisite for calling the new synchronous `Regex` initializers
- synchronous regex compilation should continue to auto-bootstrap the runtime internally

## Affected Surface

Implementation and migration will touch:

- public `Regex` initializers
- public `RegexSet` initializers that are async only because of regex compilation
- tests that previously used `try await Regex(...)`
- tests that previously used `try await RegexSet(...)`
- README examples
- DocC Getting Started and advanced encoding documentation
- any examples or integration tests that compile regexes in async contexts only because the initializer is async today

This is intentionally a broad migration because the current async initializer leaks into almost every user-facing example.

## Compatibility Strategy

This should be treated as a deliberate public API change, not as a long-lived dual-surface compatibility layer.

Current recommendation:

- replace the async public regex compilation APIs with synchronous ones
- migrate the package's own call sites in the same change series
- do not keep parallel sync and async public initializer variants unless implementation constraints prove that necessary

Reason:

- the async form is not a meaningful capability that users rely on semantically
- keeping both surfaces would preserve confusion instead of resolving it
- the package is still pre-1.0 again (`0.3.0`), so cleaning this up now is materially cheaper than carrying dual initialization models forward

## Risk Notes

### 1. `uninitialize()` invalidation semantics
Existing invalidation semantics remain: regexes created before `uninitialize()` must not be used after.

### 2. Transitive Async (Resolved)
By de-isolating `Encoding` and `Syntax`, we remove the risk of `await` being required for the arguments of a synchronous `Regex` initializer.

### 2a. Preset Safety Must Be Explicit

The implementation must document why de-isolated `Encoding` and `Syntax` presets are safe:

- which preset values are immutable
- which preset values are copied
- which values remain runtime-coordinated and therefore actor-isolated

This is important because otherwise the migration could accidentally replace one confusing async boundary with an underspecified thread-safety contract.

### 3. Lock vs Actor Re-entrancy
The synchronous bootstrap must be strictly non-recursive and must not attempt to call back into `@OnigurumaActor` while holding the internal lock.

## Test Outline
- Validate `Regex` and `RegexSet` sync initializers work across different encodings.
- Confirm concurrent compilation is thread-safe under the new bootstrap lock.
- Verify `Encoding.utf8` and `Syntax.default` can be used without `await`.
- Ensure `@OnigurumaActor` APIs still behave correctly when the library was auto-initialized via a sync `Regex` call.

## Recommended Defaults
- **Phase 1:** Implement synchronous bootstrap lock.
- **Phase 2:** De-isolate `Encoding` and `Syntax` presets.
- **Phase 3:** Migrate `Regex` and `RegexSet` initializers to synchronous.
- **Phase 4:** Update all tests, examples, and documentation.
