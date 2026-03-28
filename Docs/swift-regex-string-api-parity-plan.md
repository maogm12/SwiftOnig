# Swift Regex String API Parity Plan

This document tracks the next layer of string-facing API work after the `Regex.Match` migration: closing the gap with Swift's native string regex APIs where that gap is both meaningful and compatible with SwiftOnig's design.

## Status

**Status:** Ready for Build

The main approach, Phase 1 interfaces, and phased execution order are now fixed. Remaining questions are implementation details inside those approved phases, not top-level API design blockers.

## Verification Baseline

The API list below was verified against the current local toolchain:

- Apple Swift `6.2.3`
- standard-library `_StringProcessing` APIs compiled locally with `swiftc -typecheck`

Verified `String` regex APIs on the current toolchain:

- `contains(_:)`
- `firstMatch(of:)`
- `prefixMatch(of:)`
- `wholeMatch(of:)`
- `matches(of:)`
- `ranges(of:)`
- `split(separator:)` with a regex separator
- `replacing(_:with:)`
- mutating `replace(_:with:)`
- `trimmingPrefix(_:)`

Notably absent from the current toolchain:

- `firstMatch(of:in:)`
- `prefixMatch(of:in:)`
- `wholeMatch(of:in:)`
- `matches(of:in:)`
- `ranges(of:in:)`

So range-limited string regex APIs should be treated as a SwiftOnig extension idea, not as a direct parity target with the currently verified standard-library surface.

## Design Exit Criteria

This design is considered ready for build when:
- [x] A concrete return type for `matches(of:)` is chosen: `[Regex.Match]` for Phase 1.
- [x] A concrete return type for `ranges(of:)` is chosen: `[Range<String.Index>]` for Phase 1.
- [x] The semantic behavior for `split(separator:)` regarding empty segments is defined.
- [x] The implementation order (Phases 1-3) is approved.
- [x] Test cases for basic parity are outlined.

## Stop Rule

Stop this design effort and pivot if:
- Swift's standard library introduces a stable, public way to plug in custom regex engines that makes this manual parity work redundant.
- Implementation of Phase 1 reveals significant performance regressions or index-mapping complexities that require a fundamental rethink of `Regex.Match`.

## Discussion Log

| Date | Decision/Event | Rationale |
| :--- | :--- | :--- |
| 2026-03-27 | Initial Draft | Establish parity targets based on Swift 6.2.3 toolchain. |
| 2026-03-27 | Phased Implementation | Prioritize discovery/match APIs over mutation and convenience to build on existing `Regex.Match` work. |
| 2026-03-27 | Eager Array Recommendation | Chose `[Regex.Match]` for initial `matches(of:)` to keep implementation simple and move forward. |
| 2026-03-27 | Phase 1 Return Types Locked | Chose eager arrays for `matches(of:)` and `ranges(of:)` so Phase 1 can move to implementation without further interface churn. |
| 2026-03-27 | Split Semantics Defined | Match stdlib-observed behavior by omitting empty subsequences in `split(separator:)`. |
| 2026-03-27 | Ready for Build | Locked the phased implementation order and outlined the initial parity test matrix. |

## Design Constraints

- Keep `String` and `Substring` as the primary text-facing path.
- Keep raw encoded inputs modeled as byte containers plus explicit `Encoding`.
- Preserve `Regex.Match` as the string-native result model.
- Do not weaken the raw `Region` model just to chase superficial parity.
- Only add APIs that fit SwiftOnig's current public layering and naming direction.

## Parity Target Tiers

### Tier 1: Core Match Presence and Discovery

These are the most important parity APIs because they sit directly on top of the string-native match model already in place.

- `String.contains(_ regex: Regex) throws -> Bool`
- `Substring.contains(_ regex: Regex) throws -> Bool`
- `String.matches(of: Regex) throws -> [Regex.Match]`
- `Substring.matches(of: Regex) throws -> [Regex.Match]`
- `String.ranges(of: Regex) throws -> [Range<String.Index>]`
- `Substring.ranges(of: Regex) throws -> [Range<String.Index>]`

Notes:

- `matches(of:)` should use non-overlapping forward-search semantics.
- `ranges(of:)` should be defined in terms of the resulting matches.
- Phase 1 explicitly uses eager arrays to keep the implementation small and deterministic.
- A lazy or collection-like result may be revisited only as a later design exercise if eager materialization becomes a demonstrated problem.

### Tier 2: Replacement APIs

These are common enough in real string-processing workloads that SwiftOnig should expose them if we want credible parity with Swift-native string processing.

- `String.replacing(_ regex: Regex, with replacement: String) throws -> String`
- mutating `String.replace(_ regex: Regex, with replacement: String) throws`

Possible follow-up variants:

- replacement closures based on `Regex.Match`
- replacement limits or subrange-specific replacements

Notes:

- The first pass should keep replacement simple and string-based.
- Closure-driven replacement should be deferred until we are confident about the shape of `matches(of:)`.

### Tier 3: Split and Trimming Conveniences

These are lower priority but still part of the standard string-processing feel.

- `String.split(separator: Regex) throws -> [Substring]`
- `Substring.split(separator: Regex) throws -> [Substring]`
- `String.trimmingPrefix(_ regex: Regex) throws -> Substring`
- `Substring.trimmingPrefix(_ regex: Regex) throws -> Substring`

Notes:

- `split(separator:)` must define whether empty segments are preserved.
- `trimmingPrefix(_:)` should only trim when the regex matches at the beginning; otherwise it should return the original substring unchanged.
- There is no verified `trimmingSuffix(_ regex:)` counterpart in the current toolchain, so SwiftOnig should not invent it just to make the list look symmetric.
- `split(separator:)` should omit empty subsequences, matching the current stdlib-observed behavior for repeated and trailing separators.

## Recommended Implementation Order

### Phase 1: Presence and Collection APIs

Implement:

- `contains(_:)`
- `matches(of:)`
- `ranges(of:)`

Reason:

- These build directly on `firstMatch(of:)` and the existing search machinery.
- They make the new string-native API feel substantially more complete.
- They unlock most ordinary string-processing workflows without forcing users back to `Region`.

### Phase 2: Replacement APIs

Implement:

- `replacing(_:with:)`
- mutating `replace(_:with:)`

Reason:

- Replacement is one of the most expected string regex operations after matching.
- It is easier to define cleanly after `matches(of:)` semantics are settled.

### Phase 3: Split and Trimming

Implement:

- `split(separator:)`
- `trimmingPrefix(_:)`

Reason:

- These are useful but less central.
- They are easier to get right once matching and replacement behavior are already stable.

## Open Questions

### 1. Should Phase 1 parity cover only string-native APIs?

Current recommendation:

- yes

Reason:

- the parity goal here is specifically to close the gap on `String` and `Substring`
- raw byte-oriented APIs already exist on `Regex` and should not be reshaped just for symmetry

### 2. Should lazy result types be revisited after Phase 1?

Current recommendation:

- yes, only if eager arrays become a demonstrated problem

Reason:

- Phase 1 should optimize for correctness and implementation speed
- a custom lazy result would add new API surface and complexity immediately

### 3. Should `contains(_:)` live only on `String` and `Substring`?

Current recommendation:

- yes

Reason:

- parity here is specifically about string-native APIs
- raw byte-oriented presence checks are already handled by `Regex.matches(_:)`

### 4. Should replacement APIs accept only `String` replacements first?

Current recommendation:

- yes

Reason:

- this keeps the first pass simple
- closure-based replacements can come later if there is a concrete need

## Test Outline

Phase 1 parity tests should cover:

- `contains(_:)` on `String` and `Substring` for match and mismatch cases
- `matches(of:)` returning non-overlapping matches in forward search order
- `matches(of:)` with capture groups to confirm `Regex.Match` contents stay correct
- `ranges(of:)` matching the ranges extracted from `matches(of:)`
- empty-result behavior for `matches(of:)` and `ranges(of:)`
- Unicode and multi-byte text inputs to confirm index mapping remains correct

Phase 2 parity tests should cover:

- `replacing(_:with:)` for single and multiple matches
- mutating `replace(_:with:)` parity with the non-mutating variant
- replacement text that changes overall string length

Phase 3 parity tests should cover:

- `split(separator:)` omitting empty subsequences for repeated and trailing separators
- `trimmingPrefix(_:)` only trimming when the regex matches at the beginning
- `trimmingPrefix(_:)` mismatch cases returning the original substring unchanged

## Recommended Defaults

If we want to stop debating and start implementation, the defaults should be:

- Phase 1 next: `contains(_:)`, `matches(of:)`, `ranges(of:)`
- use eager arrays for the first implementation of `matches(of:)` and `ranges(of:)`
- Phase 2 after that: `replacing(_:with:)` and mutating `replace(_:with:)`
- Phase 3 later: `split(separator:)` and `trimmingPrefix(_:)`
- do not invent unverified standard-library parity APIs just for symmetry
