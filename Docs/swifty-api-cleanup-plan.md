## Status

Ready for Build

## Summary

This document records a follow-up API cleanup pass focused on making SwiftOnig's public surface feel more native to Swift after the recent string-match, runtime-namespace, and sync-initializer migrations.

The goal is not to redesign the library from scratch. The goal is to identify the remaining public APIs that still read like C wrappers, Java-style mutators, or outdated async surfaces, then migrate them toward clearer Swift-first forms.

## Verification Baseline

- The current public surface was re-read from `Sources/SwiftOnig`.
- A repository-wide search for `async` in public-facing code found only one remaining public API that is still unnecessarily async-shaped:
  - `Regex.syntax`
- Existing string-native APIs on `String` and `Substring` already align reasonably well with Swift regex conventions:
  - `contains(_:)`
  - `firstMatch(of:)`
  - `prefixMatch(of:)`
  - `wholeMatch(of:)`
  - `matches(of:)`
  - `ranges(of:)`
  - `replacing(_:with:)`
  - `replace(_:with:)`
  - `split(separator:)`
  - `trimmingPrefix(_:)`

## Design Goals

- Remove remaining public API shapes that look like transcribed C wrappers instead of Swift APIs.
- Remove any remaining unnecessary async public accessors.
- Prefer properties for stored configuration and simple metadata.
- Prefer Swift-native value types over C typedefs in public signatures.
- Preserve the current layering:
  - string-native APIs return `Regex.Match`
  - raw encoded input APIs return `Region`
  - runtime control APIs live under `Oniguruma`

## Non-Goals

- Do not redesign raw `Region` semantics into string-native results.
- Do not introduce compatibility shims just to avoid breakage; the package is still pre-1.0.
- Do not reopen the larger string API migration or runtime namespace migration unless a contradiction is found.
- Do not turn advanced raw APIs into "friendly" abstractions that hide encoded-byte semantics.

## Current Issues

### 1. `Regex.syntax` is still an async getter

Current shape:

```swift
public var syntax: Syntax {
    get async { storage.syntax }
}
```

This is not a meaningful async operation. `syntax` is immutable regex metadata available after compilation.

Recommended direction:

```swift
public var syntax: Syntax { storage.syntax }
```

### 2. `MatchParam` still exposes Java-style mutator methods

Current public surface uses methods like:

- `setMatchStackLimitSize(to:)`
- `setRetryLimitInMatch(to:)`
- `setRetryLimitInSearch(to:)`
- `setCalloutUserData(_:)`
- `setProgressCallout(_:)`
- `setRetractionCallout(_:)`

This reads like a mutable options builder translated from C.

Recommended direction:

- Rename `MatchParam` to `Regex.MatchConfiguration`
- Remove the Java-style setter methods
- Remove `reset()`
- Remove `calloutUserData`
- Rename:
  - `progressCallout` -> `progressHandler`
  - `retractionCallout` -> `retractionHandler`
- Make it an immutable configuration value with defaulted initialization

Preferred usage shape:

```swift
let configuration = Regex.MatchConfiguration(
    retryLimitInSearch: 100,
    progressHandler: { _ in .continue }
)
```

This is more Swift-native than a mutable "parameter bag", and Swift closures can capture user context directly, so a separate `userData` field is not necessary.

### 3. Unicode property inputs still expose C-level code point types

Public types like `OnigurumaUnicodePropertyRange` still expose `OnigCodePoint`.

Problems:

- `OnigCodePoint` is a C-level typedef, not a Swift-first public API.
- It makes callers reason about bit-width and interop details that should stay internal.
- It leaks "code point as integer" semantics instead of using Swift's `Unicode.Scalar`.

Recommended direction:

- Make `Unicode.Scalar` and `ClosedRange<Unicode.Scalar>` the primary public model.
- Keep any `OnigCodePoint` conversion internal.
- Downscope `OnigurumaUnicodePropertyRange` from the primary public path, or remove it if no longer needed after migration.

Preferred public shape:

```swift
Oniguruma.defineUnicodeProperty(
    named: "MyProperty",
    scalarRanges: [
        Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3044)!
    ]
)
```

### 4. Callout context names still under-describe raw offset semantics

`OnigurumaCalloutContext` currently exposes:

- `currentOffset`
- `startOffset`
- `searchRangeUpperBound`
- `captureRanges`

These are raw engine positions, not `String.Index` values.

Current names make it too easy to misread them as character offsets.

Recommended direction:

- `currentByteOffset`
- `startByteOffset`
- `searchByteRangeUpperBound`
- `captureByteRanges`

This does not try to make callouts string-native. It simply makes the raw semantics explicit.

### 5. Callout argument cases still read like direct C-union exposure

`OnigurumaCalloutArgument` currently uses:

- `.long(Int)`
- `.codePoint(OnigCodePoint)`
- `.pointer(UInt)`
- `.tag(Int)`

Recommended direction:

- Prefer names that read more like Swift values and less like C field names.
- Also prefer Swift-native scalar types where possible.

Candidates:

- `.integer(Int)` instead of `.long(Int)`
- `.unicodeScalar(Unicode.Scalar)` instead of `.codePoint(OnigCodePoint)`
- `.rawPointerAddress(UInt)` instead of `.pointer(UInt)`

`tag` is acceptable if the term still comes directly from Oniguruma and remains documented as such.

### 6. `RegexSet.firstSetMatch` should use a result type instead of an anonymous tuple

Current shape:

```swift
(regexIndex: Int, region: Region)?
```

This is usable, but it is not a durable public result model.

Recommended direction:

- Rename `firstSetMatch` to `firstMatch`
- Introduce a dedicated result type `RegexSet.Match`
- Give it named properties:
  - `regexIndex`
  - `regex`
  - `region`

This keeps the current raw semantics while making the API easier to discover and extend.

### 7. Some raw-byte initializer labels still read like implementation detail

Examples:

- `patternBytes:`
- `patternsBytes:`

These are accurate, but not especially Swifty.

This is lower priority than the issues above because these initializers are intentionally advanced.

Discussion outcome:

- Keep `patternBytes:` and `patternsBytes:` for now.

Reason:

- These are advanced raw-input APIs.
- The explicit `Bytes` label is a little verbose, but it is also very clear.
- Swift initializer labels are often intentionally explicit, and this does not currently create the same level of confusion as the other issues in this document.

### 8. `Region` raw range names may still be too easy to misread

`Region.range` and `Subregion.range` are raw encoded ranges, not string-native ranges.

This is acceptable for advanced APIs, but the naming is inherently easy to misread.

Recommended direction:

- Rename `Region.range` to `Region.byteRange`
- Rename `Subregion.range` to `Subregion.byteRange`

This makes the advanced raw API much harder to misread, while preserving `Regex.Match.range` as the string-native range model.

### 9. `Region.backReferencedGroupNumber(of:)` is too C-flavored

Current name is direct but awkward:

- `backReferencedGroupNumber(of:)`

Discussion outcome:

- Skip this in the current cleanup pass.

Reason:

- The naming is a little awkward, but the API is specialized and low-traffic.
- The payoff is much lower than the cleanup items already approved for this pass.
- This can be revisited later without blocking the current Swifty cleanup work.

### 10. `OnigError` is still not a very Swift-native public type name

`OnigError` is concise, but it reads like an internal bridge type rather than a polished public error type.

Discussion outcome:

- Skip this in the current cleanup pass.

Reason:

- The name is not ideal, but it is not the sharpest API problem remaining.
- Renaming the public error type would create much broader churn across docs, tests, and user-facing examples.
- This is better handled as a separate naming pass if still desired before 1.0.

## Remaining Public Async Surface

After the recent sync-initializer migration and runtime namespace migration, the public API no longer has meaningful async entry points for regex compilation or runtime control.

The remaining unnecessary async public interface identified in the current source is:

- `Regex.syntax`

No other public functions or initializers currently require `async`.

This cleanup pass should remove that final unnecessary async accessor.

## Recommended Cleanup Phases

### Phase 1: Low-risk Swifty surface cleanup

- Make `Regex.syntax` synchronous
- Replace `MatchParam` with `Regex.MatchConfiguration`
- Rename `RegexSet.firstSetMatch` to `firstMatch` and introduce `RegexSet.Match`
- Make callout context raw-offset naming explicit
- Rename `Region.range` and `Subregion.range` to `byteRange`

### Phase 2: Public type cleanup for Unicode and callouts

- Make `Unicode.Scalar` the primary public Unicode-property input model
- Rework `OnigurumaCalloutArgument` case names toward Swift value semantics
- Remove or downscope `OnigurumaUnicodePropertyRange` from the primary public path

### Phase 3: Deferred naming cleanup

- Revisit `backReferencedGroupNumber(of:)`
- Revisit whether `OnigError` should be renamed

## Affected Surface

- `Regex`
- `RegexSet`
- `MatchParam`
- `Region`
- `Subregion`
- `Oniguruma`
- callout-related public types
- Unicode-property-related public types
- README and DocC examples that use advanced runtime or raw APIs
- targeted tests for runtime, regex sets, callouts, and advanced raw inputs

## Risks

- Renaming low-level raw APIs can improve clarity for new users but irritate advanced users who already understand the current model.
- Callout APIs are intentionally engine-oriented; over-cleaning them could hide important semantics.
- A broad rename pass across raw APIs can create churn without materially improving the common path if priorities are not kept tight.

## Open Questions

- Should `RegexSet.Match` be nested under `RegexSet`, or should the result type use a different public name?
- Should `OnigurumaCalloutArgument` case names be updated in the same pass as context property renames, or split into a later follow-up?
- Should Unicode-property cleanup fully remove `OnigCodePoint` from public surface immediately, or stage the removal across a short internal transition?

## Recommended Defaults

- Make `Regex.syntax` synchronous in the first pass.
- Replace `MatchParam` with immutable `Regex.MatchConfiguration`.
- Prefer `Unicode.Scalar` in public Unicode-property APIs.
- Make raw callout offsets explicit in names rather than trying to wrap them into string-native concepts.
- Add a dedicated `RegexSet` match result type and rename `firstSetMatch` to `firstMatch`.
- Rename `Region.range` and `Subregion.range` to `byteRange`.
- Leave `patternBytes:` / `patternsBytes:` unchanged in this pass.
- Leave `OnigError` and `backReferencedGroupNumber(of:)` unchanged in this pass.

## Design Exit Criteria

- The Phase 1 cleanup set is explicitly approved.
- The remaining public async surface to be removed is confirmed to be only `Regex.syntax`.
- The intended direction for `Regex.MatchConfiguration`, `RegexSet.firstMatch`, and callout offset naming is agreed.
- Unicode-property public modeling is either approved for Phase 2 or explicitly deferred.

## Stop Rule

Stop design work when:

- the Phase 1 cleanup items are clearly scoped
- the async cleanup scope is confirmed
- no one is still proposing broader public-surface rewrites in this pass

Do not expand this design into a full pre-1.0 API redesign.

## Discussion Log

| Date | Topic | Decision |
| --- | --- | --- |
| 2026-03-28 | Swifty API revisit | Identified several public APIs that still look C-flavored or non-idiomatic after the recent migrations. |
| 2026-03-28 | Async surface audit | Confirmed that the only remaining unnecessary public async interface is `Regex.syntax`. |
| 2026-03-28 | MatchParam direction | Evolved from "replace setters with properties" to "replace `MatchParam` with immutable `Regex.MatchConfiguration`". |
| 2026-03-28 | Unicode property modeling | Prefer `Unicode.Scalar` over `OnigCodePoint` in public APIs. |
| 2026-03-28 | Callout context naming | Keep callouts raw, but rename raw offsets to make byte semantics explicit. |
| 2026-03-28 | Callout user data | Decided to remove `calloutUserData`; Swift closures can capture caller state directly. |
| 2026-03-28 | RegexSet search naming | Decided to rename `firstSetMatch` to `firstMatch` and replace the anonymous tuple with `RegexSet.Match`. |
| 2026-03-28 | Raw-byte initializer labels | Decided to keep `patternBytes:` and `patternsBytes:` for now because the explicit labels are clear enough for advanced APIs. |
| 2026-03-28 | Region raw range naming | Decided to rename `Region.range` and `Subregion.range` to `byteRange` to reduce confusion with string-native ranges. |
| 2026-03-28 | Specialized low-priority names | Deferred `backReferencedGroupNumber(of:)` and `OnigError` renaming to a later pass because the payoff is lower than the approved cleanup items. |
