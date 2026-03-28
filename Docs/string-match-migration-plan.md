# String Match Migration Plan

This document proposes a migration of SwiftOnig's string-facing API so it aligns more closely with Swift's native regex style while preserving the package's raw encoding-aware search model.

## Recommended Plan

### Core Split

The recommended API split is:

- `Regex` remains the compiled pattern type.
- `String` and `Substring` become the primary search entry points for text workflows.
- String-native searches return `Regex.Match`.
- Raw encoded searches continue to return `Region`.

This is a layered design, not a unified-result design.

### Design Principles

- String-native APIs should feel natural to Swift and iOS developers.
- Byte-oriented results should not be the default result model for `String` input.
- Raw `Region` details should stay out of the primary string-facing API.
- Mismatch and string-index-mapping failure must remain distinct outcomes.
- The first implementation should optimize for correctness and clarity over speculative optimization.

### Primary Search APIs

`Regex` continues to own compilation:

```swift
let regex = try Regex(pattern: #"\d+"#)
```

Primary search entry points live on `String` and `Substring`:

```swift
let first = try input.firstMatch(of: regex)
let prefix = try input.prefixMatch(of: regex)
let whole = try input.wholeMatch(of: regex)
```

Recommended signatures:

- `func firstMatch(of: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam? = nil) throws -> Regex.Match?`
- `func prefixMatch(of: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam? = nil) throws -> Regex.Match?`
- `func wholeMatch(of: Regex, options: Regex.SearchOptions = .none, matchParam: MatchParam? = nil) throws -> Regex.Match?`

Regex-centric helper APIs may also exist:

- `Regex.firstStringMatch(in: String/Substring, ...)`
- `Regex.prefixStringMatch(in: String/Substring, ...)`
- `Regex.wholeStringMatch(in: String/Substring, ...)`

These are secondary helpers, not the primary story.

### `Regex.Match`

Recommended string-native result:

```swift
extension Regex {
    public struct Match: Sendable, RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = Capture?

        public struct Capture: Sendable {
            public let groupNumber: Int
            public let range: Range<String.Index>
            public let substring: Substring
        }
    }
}
```

Recommended `Regex.Match` surface:

- `range: Range<String.Index>`
- `substring: Substring`
- `count: Int`
- `subscript(Int) -> Capture?`
- `captures(named: String) -> [Capture]`

Optional later convenience:

- `lastCapture(named: String) -> Capture?`

but this should not be part of the first public version unless its semantics are judged worth the complexity.

### Group 0 Semantics

`match.range` and `match.substring` correspond to capture group `0`.

If `match[0]` is exposed, it must be consistent:

- `match[0]?.range == match.range`
- `match[0]?.substring == match.substring`

### Raw API Continuity

Raw encoded APIs remain on `Regex` and continue to return `Region`:

- `regex.firstMatch(in: bytes) -> Region?`
- `regex.prefixMatch(in: bytes) -> Region?` if supported
- `regex.wholeMatch(in: bytes) -> Region?`

For raw byte-oriented and encoding-oriented workflows, `Region` remains the correct result model.

### Raw Input Design Principle

Raw encoded inputs should stay modeled as:

- byte containers such as `[UInt8]`, `ArraySlice<UInt8>`, `Data`, and `Data.SubSequence`
- plus an explicit `Encoding`

The package should not grow a family of encoding-specific high-level raw input wrapper types for cases such as:

- UTF-16
- Big5
- GB18030
- GBK

Reason:

- these are all still raw encoded byte streams
- the natural abstraction is `bytes + encoding`, not one public type per encoding
- a per-encoding wrapper family would scale poorly and make UTF-16 look special without a principled boundary

Review tradeoff:

- explicit wrapper types can make a few performance-sensitive workflows more obvious
- but they also bias the public API toward selected encodings and make the raw-input story less uniform

Current recommendation:

- keep raw-input APIs centered on byte containers plus explicit `Encoding`
- reserve string-native conveniences for `String` and `Substring`
- treat existing encoding-specific helper types, if retained, as implementation details or narrow advanced tools rather than the future public API direction

### Internal Implementation Strategy

Recommended implementation layering:

1. Reuse the existing byte-oriented `Regex` search implementation.
2. For `String` and `Substring`, obtain the underlying `Region`.
3. Convert the region's encoded offsets into `Range<String.Index>`.
4. Wrap those ranges into `Regex.Match` and `Regex.Match.Capture`.

This keeps the engine byte-oriented internally while making the public string API string-native.

### Index Conversion Rule

The conversion from `Region` to `Regex.Match` must not use character counts.

It should:

- use `utf8` view for UTF-8 regex paths
- use `utf16` view for UTF-16 regex paths
- convert view indices back to `String.Index`

This is the only sound way to map encoded offsets back to Swift string positions.

### Error Semantics

- mismatch returns `nil`
- a raw match that cannot be represented as valid `String.Index` boundaries throws `OnigError.stringIndexMappingFailed`

This failure is about result-to-string-index mapping, not malformed Swift `String` storage.

### Metadata Ownership

`Match` should not retain the full `Regex` object or C pointers.

Recommended approach:

- one shared immutable Swift metadata object per compiled `Regex`
- reused by produced matches
- no raw C pointers stored in that metadata object

This avoids both:

- retaining the entire regex engine object
- copying large metadata dictionaries into every match

### Memory Behavior

`Match.substring` and `Capture.substring` should be standard `Substring` views.

That means they may retain the original base string's storage. This should be documented explicitly, with guidance to copy into `String` for long-term retention if needed.

### First Implementation Scope

The first migration should ship the single-result family only:

- `firstMatch`
- `prefixMatch`
- `wholeMatch`
- `Regex.firstStringMatch`
- `Regex.prefixStringMatch`
- `Regex.wholeStringMatch`

This is the smallest complete string-native story.

## Alternative Considered

### Generic Unified Match Model

One proposal was to make both string-native and raw byte-oriented searches return a generic result type:

```swift
extension Regex {
    public struct Match<Input: Collection> { ... }
}
```

with examples such as:

- `Regex.Match<Substring>`
- `Regex.Match<ArraySlice<UInt8>>`

and a public `underlyingRegion` property for raw access.

### Why This Was Rejected

#### 1. It creates false uniformity

String-native and raw-byte results are not the same abstraction:

- string-native results care about `String.Index` and `Substring`
- raw results care about encoded byte offsets and regex-engine semantics

One generic type makes them look more similar than they really are.

#### 2. It weakens raw-byte semantics

Advanced byte-oriented users want `Region` because it expresses encoded offsets directly.

Replacing raw semantics with:

- `Range<Input.Index>`
- `Input.SubSequence`

does not actually preserve the engine's real result model.

#### 3. `StringMatch = Match<Substring>` is a smell

If the common case only looks natural after adding a typealias, the generic type is probably too broad for the public API.

#### 4. `underlyingRegion` collapses the boundary

Putting `underlyingRegion` on the primary `Match` type mixes the high-level and low-level APIs together again.

If `Region` is the advanced/raw layer, it should stay in that layer rather than becoming a default property on the string-native result type.

### Current Status of This Alternative

This generic unified result approach should be treated as a rejected alternative unless a strong counterargument emerges.

## Open Questions

These questions are still worth reviewing explicitly before implementation begins.

### 1. Should `lastCapture(named:)` exist at all?

Current recommendation:

- do not ship it in the first public version
- ship only `captures(named:)`

Reason:

- it encodes a non-obvious selection rule
- `captures(named:)` is semantically complete

If it is added later, it must be explicitly documented as following Oniguruma backreference-oriented effective-group semantics.

### 2. Should `matches(of:)` be added later?

Probably yes, but not in the first migration.

Important semantic defaults if it is added:

- non-overlapping matches
- forward search order
- no implicit overlapping-match enumeration

Its result shape should remain open for now:

- sequence-like or collection-like preferred
- eager array only as a fallback, not a design assumption

### 3. Should `contains(_ regex:)` be added?

Probably yes, but it is not required for the migration itself.

It should be treated as an ergonomic follow-up API rather than part of the core result-model redesign.

### 4. What should future range-limited string APIs mean?

Potential future APIs:

- `firstMatch(of:in: Range<String.Index>)`
- `prefixMatch(of:in: Range<String.Index>)`
- `wholeMatch(of:in: Range<String.Index>)`

Important semantic choice:

For range-limited `wholeMatch`, the recommended meaning is:

- whole-match-within-the-provided-range

This should be documented explicitly before such APIs ship.

### 5. Should `Regex.firstMatch(in: String)` survive migration?

This is still the most important migration boundary question.

If SwiftOnig exposes both:

- `string.firstMatch(of: regex) -> Regex.Match`
- `regex.firstMatch(in: string) -> Region`

then the same `String` input would have two plausible public entry points with different result models.

That is likely to increase user confusion.

Current recommendation:

- do not keep `Regex.firstMatch(in: String)` as a long-term public string entry point
- keep `Regex.firstStringMatch(...)` if a regex-centric helper is still desired

## Recommended Defaults

If we want to stop debating and start implementation, the recommended defaults are:

- use `Regex.Match` for string-native results
- keep `Region` for raw encoded results
- do not ship `lastCapture(named:)` in v1
- use shared immutable metadata per `Regex`
- ship only `firstMatch` / `prefixMatch` / `wholeMatch` in the first migration
- treat `matches(of:)` and `contains(_:)` as later APIs
- remove old string-specific `Region`-returning APIs at the next major-version boundary
