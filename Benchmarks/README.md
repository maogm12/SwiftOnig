# Benchmarks

This folder contains the `SwiftOnigBenchmarks` executable target used to compare:

- `SwiftOnig`
- `NSRegularExpression`
- Swift native regex (`_StringProcessing.Regex`)

The benchmark entrypoint is [main.swift](/Users/gmao/code/SwiftOnig/Benchmarks/main.swift).

## How To Run

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

Available groups:

- `compile`
- `short`
- `unicode`
- `large`
- `utf16`

## Benchmark Configuration

Current large-sample configuration:

- Compile email pattern: `10000` iterations
- First match on short input: `1000000` iterations
- Unicode capture match: `1000000` iterations
- First match on large input: `20000` iterations
- UTF-16 smart match from `String`: `100000` iterations
- UTF-16 oriented match from `UTF16View`: `100000` iterations
- SwiftOnig UTF-16 `matchCount` from `UTF16View`: `100000` iterations

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

### SwiftOnig UTF-16 `matchCount` From `UTF16View`

- `SwiftOnig`: `1.246005 s`

## Current Read

From the current results:

- `SwiftOnig` is faster than `NSRegularExpression` on compile, short-input search, and large-input search.
- `SwiftOnig` is roughly on par with `NSRegularExpression` on the Unicode capture workload.
- The main remaining performance gap is the UTF-16 path.
- UTF-16 `firstMatch` and `matchCount` are nearly identical in cost, which suggests the hotspot is not `Region` materialization but the lower-level UTF-16 search and bridging path.
