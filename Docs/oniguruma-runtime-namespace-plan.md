# Oniguruma Runtime Namespace Plan

This document proposes moving SwiftOnig's global runtime coordination APIs out of top-level functions and into a dedicated namespace type named `Oniguruma`.

## Status

**Status:** Ready for Build

The main direction is chosen: use a namespace-like `enum` with synchronous `static` API. This migration is intentionally breaking while the package is still pre-1.0, so compatibility shims are out of scope.

## Problem Statement

SwiftOnig currently exposes runtime-wide operations as top-level functions:

- `initialize(encodings:)`
- `uninitialize()`
- `setWarningHandler(_:)`
- `setVerboseWarningHandler(_:)`
- `defineUserUnicodeProperty(named:ranges:)`
- `registerCallout(named:encoding:phases:handler:)`

These APIs are semantically global runtime controls, not behavior on a specific `Regex` value. Top-level functions are workable, but they scatter discovery and make the public surface less structured than the rest of the library.

At the same time, these APIs should **not** move onto `Regex`, because they affect process-wide Oniguruma runtime state, not one compiled pattern.

## Verification Baseline

Current runtime-wide APIs live in:

- [`Sources/SwiftOnig/OnigurumaRuntime.swift`](../Sources/SwiftOnig/OnigurumaRuntime.swift)
- [`Sources/SwiftOnig/Callouts.swift`](../Sources/SwiftOnig/Callouts.swift)

Current top-level runtime APIs are:

- `initialize(encodings:)`
- `uninitialize()`
- `setWarningHandler(_:)`
- `setVerboseWarningHandler(_:)`
- `defineUserUnicodeProperty(named:ranges:)`
- `registerCallout(named:encoding:phases:handler:)`

These APIs are still actor-isolated because they mutate shared runtime state or global callback configuration.

Current global-runtime APIs that are exposed elsewhere and should be considered during this reorganization:

- `version()`
- `copyright()`
- `Encoding.default`
- `MatchParam.defaultMatchStackLimitSize`
- `MatchParam.defaultRetryLimitInMatch`
- `MatchParam.defaultRetryLimitInSearch`
- `Regex.subexpCallLimitInSearch`
- `Regex.subexpCallMaxNestLevel`
- `Regex.parseDepthLimit`

Upstream Oniguruma constraints for user-defined Unicode properties, verified from [`Vendor/Oniguruma/doc/API`](../Vendor/Oniguruma/doc/API) and [`Vendor/Oniguruma/src/unicode.c`](../Vendor/Oniguruma/src/unicode.c):

- registration is global
- registration is not thread-safe
- the `ranges` storage must remain alive after registration
- names must be ASCII-only, and `' '`, `'-'`, and `'_'` are ignored during normalization
- the upstream library currently allows at most 20 user-defined properties

## Design Exit Criteria

This design is ready for build when:

- [x] The namespace type name is fixed as `Oniguruma`.
- [x] The namespace shape is fixed as a non-instantiable `enum` with `static` members.
- [x] The runtime surface is fixed as synchronous; public actor isolation is removed from these APIs.
- [x] The first migration set is fixed.
- [x] The compatibility strategy is fixed: break and replace, with no long-lived compatibility wrappers.
- [x] Documentation wording is clear that these APIs are process-wide runtime controls, not regex-instance methods.

## Stop Rule

Stop this design effort and reconsider if:

- the namespace type would require changing the semantics of existing runtime APIs rather than only reorganizing them
- the namespace cannot be introduced without confusing it with the vendored C module or the existing `OnigurumaActor`
- removing public actor isolation would weaken runtime safety or require hidden asynchronous work in the new API

## Discussion Log

| Date | Decision/Event | Rationale |
| :--- | :--- | :--- |
| 2026-03-27 | Problem identified | Runtime-wide APIs currently exist as top-level functions and are easy to miss in discovery. |
| 2026-03-27 | Rejected `Regex` namespace | These are global runtime controls, not methods on a compiled regex type. |
| 2026-03-27 | Preferred `Oniguruma` name | The APIs configure the Oniguruma runtime specifically, and `SwiftOnig.Oniguruma` reads clearly at call sites. |
| 2026-03-27 | Preferred `static` methods | This is a namespace, not a service object; `shared` would add ceremony without adding semantics. |
| 2026-03-27 | Prefer properties over Java-style getters/setters | In Swift, runtime configuration reads more naturally as properties, while lifecycle and registration remain methods. |
| 2026-03-27 | User-defined Unicode properties need a Swift-native layer | Exposing `OnigCodePoint` directly is too C-oriented and underspecified for public Swift APIs. |
| 2026-03-27 | Preferred `enum` for namespace | Use an empty `enum` to enforce non-instantiability in the `Oniguruma` namespace. |
| 2026-03-27 | Include global limits | Moving `subexpCallLimitInSearch`, etc. from `Regex` to `Oniguruma` correctly reflects their process-wide impact. |
| 2026-03-28 | Include default encoding and match limits | These are also process-wide runtime knobs and should not remain split across unrelated types. |
| 2026-03-27 | Native Range for Unicode | Use `ClosedRange<Unicode.Scalar>` for better Swift ergonomics in the Unicode property API. |
| 2026-03-27 | Include Callouts in Phase 1 | Named callouts are global runtime hooks and belong in the `Oniguruma` namespace for discoverability. |
| 2026-03-28 | Remove public actor isolation | This package is pre-1.0, so the runtime surface should become synchronous now rather than preserving actor-based API shape. |
| 2026-03-28 | Break instead of shim | Top-level runtime functions and `Regex`-scoped global limits should be replaced directly rather than carried forward as compatibility wrappers. |

## Recommended Plan

### Goal

Move global runtime operations under a dedicated namespace type:

```swift
try SwiftOnig.Oniguruma.initialize(encodings: [.utf8, .gb18030])
SwiftOnig.Oniguruma.warningHandler = { message in
    print(message)
}
SwiftOnig.Oniguruma.uninitialize()
```

The goal is better organization and API discoverability. This is **not** a semantic redesign of runtime behavior.

### 1. Introduce a namespace type

Add a public namespace-like type:

```swift
public enum Oniguruma {}
```

Preferred shape:

- `Oniguruma.initialize(encodings:)`
- `Oniguruma.uninitialize()`
- `Oniguruma.warningHandler`
- `Oniguruma.verboseWarningHandler`
- `Oniguruma.defineUnicodeProperty(named:scalarRanges:)`
- `Oniguruma.registerCallout(named:encoding:phases:handler:)`
- `Oniguruma.version`
- `Oniguruma.copyright`
- `Oniguruma.defaultEncoding`
- `Oniguruma.defaultMatchStackLimitSize`
- `Oniguruma.defaultRetryLimitInMatch`
- `Oniguruma.defaultRetryLimitInSearch`
- `Oniguruma.subexpCallLimitInSearch`
- `Oniguruma.subexpCallMaxNestLevel`
- `Oniguruma.parseDepthLimit`

Review note:

- use `static` methods on a namespace type
- do not introduce `Oniguruma.shared`
- this runtime has global semantics already; a singleton object adds no useful state boundary
- use properties for configuration/state access rather than Java-style `getX` / `setX` method pairs

### 2. Remove public actor isolation

The public runtime namespace should be synchronous.

These APIs still mutate shared runtime state:

- explicit prewarming
- runtime teardown
- warning handler mutation
- user Unicode property registration
- named callout registration

But the synchronization strategy should move behind the API boundary:

- public callers should not cross `OnigurumaActor`
- runtime safety should be enforced internally with locks or equivalent synchronous coordination
- the namespace migration is therefore both a public API reorganization and a public concurrency simplification

### 3. Keep `Regex` out of it

Do **not** move these APIs onto `Regex` as `static` methods.

Reason:

- `Regex` represents a compiled pattern value
- these APIs mutate process-wide runtime configuration
- attaching them to `Regex` would imply a stronger relation to regex instances than actually exists

### 4. First migration set

The recommended first migration set is:

- `initialize(encodings:)`
- `uninitialize()`
- `warningHandler`
- `verboseWarningHandler`
- `defineUnicodeProperty(named:scalarRanges:)`
- `registerCallout(named:encoding:phases:handler:)`
- `version`
- `copyright`
- `defaultEncoding`
- `defaultMatchStackLimitSize`
- `defaultRetryLimitInMatch`
- `defaultRetryLimitInSearch`
- `subexpCallLimitInSearch`
- `subexpCallMaxNestLevel`
- `parseDepthLimit`

This is intentionally limited to the APIs that already read as top-level runtime controls.

Review tradeoff:

- `version` and `copyright` are read-only library metadata and fit naturally under the same runtime namespace
- `Encoding.default`, `MatchParam.default*`, and the `Regex` global limit knobs all configure the underlying runtime globally, not individual values
- moving them under `Oniguruma` makes their scope clearer and removes the remaining public actor-isolated runtime knobs from unrelated types

### 4c. Callout API positioning

`registerCallout(named:encoding:phases:handler:)` belongs in the runtime namespace because it is a process-wide registration API, not a per-regex capability.

Current implementation shape in SwiftOnig is already structurally sound:

- Swift stores handlers in a global registry
- Oniguruma receives a fixed C-compatible trampoline callback
- the trampoline rebuilds a Swift `OnigurumaCalloutContext`
- the stored Swift handler is then invoked from that context

That implementation strategy should remain. The design work here is about public API organization and semantics, not rewriting the callback bridge.

Important semantic note for review and docs:

- callout offsets and capture ranges are engine-oriented offsets, not `String.Index`
- they should be documented as raw match-process positions, not user-facing string slice coordinates
- this is an advanced runtime feature and should not be presented as part of the primary string-native API story

Future cleanup worth considering, but not required for the first migration:

- an explicit unregister API for named callouts, if we want something narrower than full `uninitialize()`
- clearer naming around raw offsets versus string-native ranges in `OnigurumaCalloutContext`

### 4a. Swift-native Unicode property API

The current public shape:

```swift
try defineUserUnicodeProperty(
    named: "SwiftOnigKana",
    ranges: [
        OnigurumaUnicodePropertyRange(0x3042, 0x3042),
        OnigurumaUnicodePropertyRange(0x3044, 0x3044),
    ]
)
```

is too C-oriented for a primary Swift API because:

- it exposes `OnigCodePoint` directly
- `OnigCodePoint` comes from C as `unsigned int`, which is not a good public Swift modeling choice
- the API shape does not make the global-registration semantics obvious

The preferred public shape is:

```swift
try Oniguruma.defineUnicodeProperty(
    named: "SwiftOnigKana",
    scalarRanges: [
        Unicode.Scalar(0x3042)! ... Unicode.Scalar(0x3042)!,
        Unicode.Scalar(0x3044)! ... Unicode.Scalar(0x3044)!,
    ]
)
```

Why `Unicode.Scalar`:

- it matches the underlying concept of Unicode code points better than `Character`
- it is a Swift-native semantic type, unlike `OnigCodePoint`
- it avoids forcing API consumers to care whether the C integer type is 32-bit or 64-bit on a given platform

Explicit non-goal:

- do not redesign this around `Character`
- user-defined properties are scalar/code-point based, not grapheme-cluster based

The current low-level `OnigurumaUnicodePropertyRange` may still exist internally or as an advanced compatibility layer, but it should not remain the recommended primary public surface.

### 4b. Unicode property semantics that must stay explicit

The Swift API should document, not hide, these upstream semantics:

- registration is global to the process-wide Oniguruma runtime
- registration is synchronized internally because upstream registration is not thread-safe
- registrations survive until `uninitialize()`
- names are normalized by ignoring spaces, hyphens, and underscores
- there is an upstream hard cap on the number of user-defined properties

Being more Swifty here means better modeling, not pretending this is a lightweight per-regex setting.

### 5. Compatibility strategy

Recommended migration strategy:

- replace top-level runtime-control functions with `Oniguruma` namespace members
- replace runtime-global properties currently spread across `Encoding`, `MatchParam`, and `Regex` with `Oniguruma` namespace properties
- replace `Regex`-scoped global limit controls with `Oniguruma`-scoped controls
- remove public actor isolation from this runtime surface in the same change series
- do not keep compatibility wrappers

Reason:

- this package is pre-1.0
- keeping both old and new surfaces would preserve confusion rather than reduce it
- the main value of this migration is a cleaner public API, which is undermined by carrying the old one forward

### 6. Documentation strategy

README and DocC should describe these APIs as:

- advanced runtime controls
- process-wide configuration
- not required for normal regex matching

The namespace helps reinforce that these are not ordinary per-regex operations.

Documentation should also explain the Unicode property model clearly:

- `Unicode.Scalar` is the public input model
- the API is global and advanced
- it should be used sparingly because registrations are limited and live in shared runtime state
- callouts are also global runtime registrations and should be documented as advanced hooks into the regex engine, not general-purpose string callbacks

## Open Questions

- Should `defineUserUnicodeProperty(named:ranges:)` remain as a low-level compatibility wrapper, or should the public API move directly to `defineUnicodeProperty(named:scalarRanges:)`?
- Should the first namespace migration also introduce an explicit named-callout unregister API, or leave registration as add/replace-only for now?

## Risk Notes

### 1. Name collision risk

`Oniguruma` is also the upstream library name, and the package already exposes `OnigurumaActor`. The namespace name is still preferred, but docs must distinguish:

- `Oniguruma` as the public runtime namespace
- `OnigurumaActor` as an internal/concurrency coordination detail

### 2. Surface duplication during migration

This plan intentionally avoids temporary coexistence. The risk is migration churn across tests/docs/examples, not long-lived API duplication.

### 3. Scope creep

This plan is only about organizing existing runtime APIs. It should not be used as an excuse to redesign callout semantics, warning handler semantics, or lifecycle semantics.

### 4. Unicode property ergonomics vs. semantics

The Unicode property API should become more Swift-native, but the implementation must not blur its real semantics:

- it is global
- it is limited
- it is internally synchronized
- it is scalar-oriented, not character-oriented

### 5. Callout context semantics

The current callout bridge exposes raw offsets and raw capture ranges. That is acceptable for an advanced engine hook, but the docs must not imply these are string-native indices.

If this remains unclear, users will misread callout context as `String`-level API even though it is really runtime/process-level matching state.

## Test Outline

- Verify namespace methods behave identically to current top-level runtime functions.
- Verify public runtime APIs are synchronous and no longer require actor hops.
- Verify warning handlers and callout registration still work after namespace migration.
- Verify named callout registration still routes through the existing trampoline/registry bridge unchanged.
- Verify callout docs/examples describe offsets as raw engine positions rather than `String.Index` values.
- Verify Unicode property registration still works through the namespace and preserves validation semantics.
- Verify any new `Unicode.Scalar`-based overload converts correctly to the existing internal code-point packing.
- Verify docs/examples compile once they switch from top-level runtime calls to `Oniguruma` methods.

## Recommended Defaults

- Use `Oniguruma` as the runtime namespace name.
- Use `static` methods.
- Do not introduce a singleton.
- Prefer properties for configuration and metadata (`warningHandler`, `version`, global limits) and methods for lifecycle/registration actions.
- Prefer `Unicode.Scalar`-based Unicode property registration APIs over direct `OnigCodePoint` ranges.
- Migrate the current top-level runtime-control APIs plus runtime metadata and global limit controls into the namespace.
- Remove public actor isolation from this runtime surface and enforce safety internally with synchronous coordination.
- Do not keep compatibility wrappers while the package is still pre-1.0.
