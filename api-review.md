# SwiftOnig API Review

This document captures API design issues from the perspective of a consumer integrating `SwiftOnig` into an application. The goal is to make the library easier to understand, easier to use correctly, and more explicit about performance-sensitive behavior.

## Priority Order

1. Resolved: Initialization semantics are inconsistent across docs and API messaging.
2. Resolved: `OnigurumaString` exposes implementation-level details as a public protocol.
3. Resolved: UTF-16 copy behavior is implicit instead of explicit.
4. Resolved: `matchCount` is misnamed for what it actually returns.
5. Open: Sync and async APIs are duplicated too broadly.
6. Resolved: `Region.range` leaks byte offsets too directly for `String` users.
7. Resolved: `Region.string` and `Subregion.string` hide decoding work behind property syntax.
8. Resolved: `RegexSet.firstMatch` has a different mental model from `Regex.firstMatch`.
9. Resolved: `Encoding` exposes low-level byte helpers too prominently.
10. Resolved: Public docs still over-emphasize low-level setup instead of common usage paths.

## Issues

### 1. Initialization semantics are inconsistent

- `README.md` says initialization is automatic.
- `GettingStarted.md` still tells users they must manually initialize and uninitialize.
- This makes first-time usage ambiguous.

Suggested fix:

- Make docs consistently describe automatic initialization as the default.
- Reframe `initialize(encodings:)` as an optional prewarm API for explicit startup control.
- Reframe `uninitialize()` as a niche lifecycle API rather than normal usage.

### 2. `OnigurumaString` should not be a public consumer-facing protocol

- It exposes pointer-oriented implementation details.
- Third-party conformances are hard to get right and easy to misuse.

Suggested fix:

- Move it to an internal protocol.
- Replace public extensibility with explicit input wrapper types where needed.

### 3. UTF-16 copy behavior is too implicit

- `String` and `String.UTF16View` may materialize temporary contiguous UTF-16 storage.
- Users cannot tell from the API shape whether a call will copy.

Suggested fix:

- Document the implicit-materialization path clearly.
- Provide explicit no-copy/reusable-input types for repeated UTF-16 search workflows.

### 4. `matchCount` is misnamed

- It returns matched byte length, not number of matches.
- Users will reasonably misread it.

Suggested fix:

- Rename to `matchedByteCount` or `matchedLength`.
- Keep `matchCount` deprecated as a compatibility alias if needed.

### 5. Sync and async surfaces are over-duplicated

- The public API surface is much larger than it needs to be.
- It is harder to learn and document.
- Attempting to demote async search overloads directly runs into Swift overload-resolution behavior: in async contexts, same-signature sync/async overload pairs strongly prefer the async candidate, which makes a compatibility-preserving cleanup trickier than the other items.

Suggested fix:

- Decide which operations truly need async-first ergonomics.
- Collapse the rest around one primary surface and keep the secondary surface thin.
- Treat this as a deliberate follow-up item rather than an opportunistic cleanup.

### 6. `Region.range` is too low-level for common `String` use

- It exposes byte offsets directly.
- Most `String` users want Swift ranges or substrings.

Suggested fix:

- Add higher-level range conversion helpers for string-backed matches.
- Keep byte offsets available for advanced users.

### 7. `Region.string` and `Subregion.string` hide work in a property

- These properties may decode bytes into `String`.
- They read like trivial field access.

Suggested fix:

- Prefer a more explicit method or name that signals decoding work.

### 8. `RegexSet.firstMatch` is named like `Regex.firstMatch` but means something else

- The return semantics are different enough to create confusion.

Suggested fix:

- Rename toward set-oriented wording such as `firstSetMatch` or `firstMatchingRegex`.

### 9. `Encoding` exposes expert-only helpers too prominently

- Byte-boundary APIs are useful but niche.
- They distract from common regex usage.

Suggested fix:

- Keep them public if needed, but move them behind more focused docs and examples.

### 10. Public docs need stronger “common path vs expert path” separation

- Current docs mix beginner and low-level usage too quickly.

Suggested fix:

- Lead with automatic initialization, `Regex(pattern:)`, and common string matching.
- Move explicit encoding and pointer-adjacent topics into advanced sections.

## Execution Notes

- Resolve these issues one at a time.
- Use one git commit per issue.
- Keep tests passing after each issue.
- Prefer compatibility-preserving fixes first, then deeper API reshaping.
- Current unresolved item: issue 5.
