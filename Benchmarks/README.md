# Benchmarks

This folder contains the `SwiftOnigBenchmarks` executable target used to compare:

- `SwiftOnig`
- `NSRegularExpression`
- Swift native regex (`_StringProcessing.Regex`)

The benchmark entrypoint is [main.swift](/Users/gmao/code/SwiftOnig/Benchmarks/main.swift).

## How To Run

Initialize vendored Oniguruma sources before running benchmarks from a fresh checkout:

```bash
git submodule update --init --recursive
```

Run all benchmark groups in release mode:

```bash
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift run -c release SwiftOnigBenchmarks
```

Run a single group:

```bash
BENCH_GROUP=utf16 \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift run -c release SwiftOnigBenchmarks
```

Run a single benchmark case with explicit warmup and sample counts:

```bash
BENCH_GROUP=utf16 \
BENCH_CASE="UTF-16 smart match from String" \
BENCH_WARMUP=1 \
BENCH_SAMPLES=5 \
CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
swift run -c release SwiftOnigBenchmarks
```

Available groups:

- `compile`
- `short`
- `unicode`
- `large`
- `utf16`

Selected environment variables:

- `BENCH_GROUP`: run only one benchmark group
- `BENCH_CASE`: run only one benchmark case by exact name
- `BENCH_WARMUP`: warmup runs before measuring each engine, default `1`
- `BENCH_SAMPLES`: measured runs per engine, default `5`

## Benchmark Configuration

Current large-sample configuration:

- Compile email pattern: `10000` iterations
- First match on short input: `1000000` iterations
- Unicode capture match: `1000000` iterations
- First match on large input: `20000` iterations
- UTF-16 smart match from `String`: `100000` iterations
- UTF-16 oriented match from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 explicit contiguous match from `UTF16CodeUnitBuffer`: `100000` iterations
- SwiftOnig UTF-16 `matchedByteCount` from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 anchored `firstMatch` from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 anchored `matchedByteCount` from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 mismatch from `String`: `100000` iterations
- SwiftOnig UTF-16 mismatch from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 whole match from `String`: `100000` iterations
- SwiftOnig UTF-16 first match plus `region.decodedString()`: `100000` iterations

Current output reports `median`, `min`, and `max` over repeated samples instead of a single timing.

Important note:

- `matchedByteCount(in:)` is anchored at the provided start offset because it is backed by `onig_match`, not `onig_search`.
- That means `matchedByteCount` is not a like-for-like replacement for `firstMatch(in:)` on inputs where the match does not begin at the start of the searched range.
- Use the anchored UTF-16 cases when estimating `Region` materialization cost relative to search cost.
- `String`, `Substring`, `String.UTF16View`, and `Substring.UTF16View` may materialize a temporary contiguous UTF-16 buffer when used with a UTF-16 encoded regex.
- To make that materialization explicit and reusable for repeated searches, prebuild a `UTF16CodeUnitBuffer` and pass that into the match APIs.

## Latest Results

Release-mode measurements from this workspace:

### Compile

- `SwiftOnig`: `0.020033 s`
- `NSRegularExpression`: `0.100372 s`
- `Swift Regex`: `0.238990 s`

### Short Input Match

- `SwiftOnig`: `1.483015 s`
- `NSRegularExpression`: `2.359551 s`
- `Swift Regex`: `4.642373 s`

### Unicode Capture Match

- `SwiftOnig`: `0.495169 s`
- `NSRegularExpression`: `0.461261 s`
- `Swift Regex`: `1.260472 s`

### Large Input Match

- `SwiftOnig`: `22.912944 s`
- `NSRegularExpression`: `73.393372 s`
- `Swift Regex`: `137.456312 s`

### UTF-16 Match From `String`

- `SwiftOnig`: `1.279129 s`
- `NSRegularExpression`: `0.056313 s`
- `Swift Regex`: `0.126128 s`

### UTF-16 Match From `UTF16View`

- `SwiftOnig`: `1.274563 s`
- `NSRegularExpression`: `0.055756 s`
- `Swift Regex`: `0.126161 s`

### SwiftOnig UTF-16 `matchedByteCount` From `UTF16View`

- `SwiftOnig`: `1.246005 s`

### Sampled UTF-16 Results With Warmup

Sample configuration:

- `BENCH_GROUP=utf16`
- `BENCH_WARMUP=1`
- `BENCH_SAMPLES=3`

Measured results from this workspace:

### UTF-16 Match From `String`

- `SwiftOnig`: median `0.995467 s`
- `NSRegularExpression`: median `0.042523 s`
- `Swift Regex`: median `0.163256 s`

### UTF-16 Match From `UTF16View`

- `SwiftOnig`: median `0.996272 s`
- `NSRegularExpression`: median `0.041744 s`
- `Swift Regex`: median `0.163004 s`

### SwiftOnig UTF-16 Anchored `firstMatch` From `UTF16View`

- `SwiftOnig`: median `0.995038 s`

### SwiftOnig UTF-16 Anchored `matchedByteCount` From `UTF16View`

- `SwiftOnig`: median `0.979267 s`

### SwiftOnig UTF-16 `matchedByteCount` From `UTF16View`

- `SwiftOnig`: median `0.980964 s`

### SwiftOnig UTF-16 Mismatch From `String`

- `SwiftOnig`: median `2.247639 s`

### SwiftOnig UTF-16 Mismatch From `UTF16View`

- `SwiftOnig`: median `2.246146 s`

### SwiftOnig UTF-16 `wholeMatch` From `String`

- `SwiftOnig`: median `2.251751 s`

### SwiftOnig UTF-16 `firstMatch` Plus `region.decodedString()`

- `SwiftOnig`: median `1.975839 s`

## Current Read

From the current results:

- `SwiftOnig` is faster than `NSRegularExpression` on compile, short-input search, and large-input search.
- `SwiftOnig` is roughly on par with `NSRegularExpression` on the Unicode capture workload.
- The main remaining performance gap is the UTF-16 path.
- `String` and `UTF16View` are nearly identical on the UTF-16 path, which suggests generic UTF-16 adaptation copy costs are not the primary issue in the current hot path.
- Anchored UTF-16 `firstMatch` and anchored UTF-16 `matchedByteCount` differ only slightly, which supports the conclusion that `Region` materialization is not the dominant cost.
- UTF-16 mismatch and whole-string workloads are much more expensive than the successful early-match case, so search behavior remains the main remaining performance problem.
