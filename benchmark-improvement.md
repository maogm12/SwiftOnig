# Benchmark Improvement Plan

This document captures the current benchmark read for `SwiftOnig`, the immediate blockers to reliable measurement, and a staged plan for improving both benchmark quality and runtime performance.

## Current Read

Based on the benchmark coverage in [Benchmarks/main.swift](/Users/gmao/code/SwiftOnig/Benchmarks/main.swift) and the latest recorded results in [Benchmarks/README.md](/Users/gmao/code/SwiftOnig/Benchmarks/README.md):

- `SwiftOnig` is already ahead of `NSRegularExpression` on compile, short-input search, and large-input search.
- `SwiftOnig` is roughly competitive on the Unicode capture workload.
- The main performance gap is the UTF-16 path.
- The UTF-16 `firstMatch` and `matchCount` numbers are nearly identical, which strongly suggests the dominant cost is below `Region` materialization.

## Local Blocker

The benchmark target cannot currently be run in this workspace because vendored Oniguruma sources are missing locally:

- [`Sources/OnigurumaC/vendor`](/Users/gmao/code/SwiftOnig/Sources/OnigurumaC) is a symlink to `../../Vendor/Oniguruma/src`
- `Vendor/Oniguruma/src` is absent in this checkout
- As a result, `swift run -c release SwiftOnigBenchmarks` fails during C target compilation

Before trusting any new measurement work, initialize the vendored source:

```bash
git submodule update --init --recursive
```

## Hotspot Read

### 1. UTF-16 input adaptation is the highest-priority suspect

The main UTF-16 bridging paths live in:

- [`Sources/SwiftOnig/StringUtils.swift`](/Users/gmao/code/SwiftOnig/Sources/SwiftOnig/StringUtils.swift)
- [`Sources/SwiftOnig/OnigurumaInputAdapters.swift`](/Users/gmao/code/SwiftOnig/Sources/SwiftOnig/OnigurumaInputAdapters.swift)

Important observations:

- `String` and `Substring` choose UTF-16 bridging dynamically when the regex encoding is UTF-16.
- The fallback path for UTF-16 bridging copies with `Array(self.utf16)`.
- `String.UTF16View` and `Substring.UTF16View` still route through a generic collection adapter that may copy if contiguous storage is unavailable.

This matches the benchmark result pattern: both UTF-16-from-`String` and UTF-16-from-`UTF16View` are much slower than Foundation and Swift Regex.

### 2. `Region` allocation is probably not the primary cost

Relevant matching code lives in:

- [`Sources/SwiftOnig/Regex.swift`](/Users/gmao/code/SwiftOnig/Sources/SwiftOnig/Regex.swift)
- [`Sources/SwiftOnig/Region.swift`](/Users/gmao/code/SwiftOnig/Sources/SwiftOnig/Region.swift)

Observations:

- `firstMatch` allocates a fresh `Region` before every `onig_search` call.
- `matchCount` uses `onig_match` and does not allocate a `Region`.
- Despite that difference, UTF-16 `firstMatch` and UTF-16 `matchCount` are nearly the same speed in the latest recorded results.

That does not mean `Region` allocation is free. It means it is not the best first optimization target.

## Improvement Goals

1. Make benchmark runs reproducible and diagnosable.
2. Improve UTF-16 path performance first.
3. Only optimize `Region` materialization after measuring whether it matters.
4. Expand benchmark coverage so future regressions are easier to localize.

## Phase 1: Fix Benchmark Reliability

### Scope

- Ensure the benchmark target is runnable in a clean checkout.
- Improve measurement quality before changing runtime code.

### Tasks

- Update benchmark docs to explicitly require submodule initialization before running.
- Convert single-shot timing into repeated samples with warmup.
- Report at least `min`, `median`, and `max`, not just one wall-clock number.
- Add an easy way to run one case at a time, not just one broad group.
- Keep release-mode execution requirements documented and stable.

### Expected Outcome

- Benchmark output becomes trustworthy enough to compare small runtime changes.
- Regressions stop being hidden by noise or setup differences.

## Phase 2: Isolate UTF-16 Costs

### Scope

- Split current UTF-16 benchmark coverage into narrower cases that isolate bridging from search from result decoding.

### Tasks

- Add dedicated UTF-16 benchmarks for:
  - `String` input, search only
  - `String.UTF16View` input, search only
  - `firstMatch` returning `Region`
  - `firstMatch` plus `region.string`
  - mismatch cases
  - anchored or whole-match cases
- Add a SwiftOnig-only microbenchmark focused on repeated UTF-16 bridge setup without capture decoding.
- Keep baseline cases for Foundation and Swift Regex where comparisons are still fair.

### Expected Outcome

- We can tell whether time is being spent in input bridging, Oniguruma search, or post-match result access.

## Phase 3: Optimize UTF-16 Input Bridging

### Scope

- Reduce copies and per-call adaptation overhead in UTF-16 paths.

### Tasks

- Introduce explicit fast paths for `String`, `Substring`, `String.UTF16View`, and `Substring.UTF16View`.
- Avoid falling back to `Array(self.utf16)` unless absolutely necessary.
- Audit whether generic `Collection`-based UTF-16 adaptation is forcing extra copies in hot paths.
- Reduce repeated dynamic UTF-16 encoding checks where the answer is already known at the call site.
- Re-benchmark after each narrowing change instead of batching a large rewrite.

### Expected Outcome

- UTF-16 benchmarks should move materially closer to Foundation and Swift Regex.
- The gap between UTF-16-from-`String` and UTF-16-from-`UTF16View` should become explainable and preferably small.

## Phase 4: Optimize Match API Overhead

### Scope

- Remove avoidable overhead around search calls once UTF-16 bridging is no longer dominant.

### Tasks

- Evaluate whether `firstMatch` can avoid allocating `Region` on paths that immediately return mismatch.
- Consider an internal reusable scratch-region strategy if it does not compromise value semantics or thread safety.
- Consolidate repeated range clamping and pointer arithmetic used by `firstMatch`, `matchCount`, and `wholeMatch`.
- Measure the benefit separately for UTF-8 and UTF-16 workloads.

### Expected Outcome

- Lower constant overhead per call, especially in high-iteration search loops.

## Phase 5: Expand Real-World Coverage

### Scope

- Add workloads that better reflect actual library usage beyond simple first-match loops.

### Tasks

- Add compile-once/query-many benchmarks.
- Add capture-heavy workloads.
- Add named-group lookup and `Region.string` extraction costs.
- Add enumerate-match throughput benchmarks.
- Add mismatch-heavy and no-capture scenarios to cover branch behavior.

### Expected Outcome

- Optimizations are validated against realistic usage, not just synthetic happy-path loops.

## Recommended Execution Order

1. Restore vendored Oniguruma sources locally and make benchmark runs reproducible.
2. Refactor benchmark harness for warmup and repeated sampling.
3. Split UTF-16 coverage into narrower benchmark cases.
4. Optimize UTF-16 input bridging.
5. Revisit `Region` and match-layer overhead only after fresh measurements.
6. Expand benchmark coverage for user-facing scenarios.

## Success Criteria

- Benchmark target runs from a clean contributor checkout with documented setup.
- UTF-16 regressions are easy to detect and attribute.
- UTF-16 performance improves materially without regressing UTF-8 workloads.
- Benchmark output reflects multiple samples instead of a single timing.
