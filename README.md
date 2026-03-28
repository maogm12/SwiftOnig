# SwiftOnig

SwiftOnig is a modern, high-performance Swift wrapper for the [Oniguruma](https://github.com/kkos/oniguruma) regular expression library. It is designed for Swift 6.0+ with a focus on safety, concurrency, and ease of use.

## Key Features

- **Swift 6.0 Native**: Fully modernized with strict concurrency checking.
- **Swift Concurrency**: Asynchronous APIs for regex compilation and searching.
- **Thread Safe**: All core types (`Regex`, `Region`, `Encoding`, `Syntax`) are `Sendable`.
- **RegexBuilder Support**: Seamlessly use SwiftOnig patterns within Swift's `RegexBuilder` DSL.
- **Automatic Initialization**: No manual library setup required; encodings are initialized lazily on first use.
- **Comprehensive Encoding Support**: Support for a wide range of character encodings (UTF-8, UTF-16, Big5, GB18030, etc.).
- **DocC Documentation**: Rich, integrated documentation including guides and API references.

## Installation

Add SwiftOnig as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maogm12/SwiftOnig", from: "1.0.0")
]
```

SwiftOnig now vendors Oniguruma source in-repo, so consumers and contributors do not need a separately installed `brew` or `apt` package for the library itself.

## Quick Start

The common path is:

1. Compile a `Regex` from a Swift `String`.
2. Search another Swift `String`.
3. Read byte ranges only if you actually need byte offsets.

Everything else, including manual runtime lifecycle, non-UTF encodings, and explicit UTF-16 input preparation, is an advanced path.

### Basic Matching

```swift
import SwiftOnig

// Regex creation is asynchronous and thread-safe
let regex = try await Regex(pattern: #"\d+"#)

let input = "The answer is 42."

// Find the first match
if let match = try input.firstMatch(of: regex) {
    print("Found: \(match.substring)") // "42"
    print("String range: \(match.range)")
}

let hasDigits = try input.contains(regex)
let allDigitMatches = try input.matches(of: regex)
let digitRanges = try input.ranges(of: regex)
```

### Using RegexBuilder

SwiftOnig integrates with Apple's `RegexBuilder` through `CustomConsumingRegexComponent`.

```swift
import RegexBuilder
import SwiftOnig

let onigRegex = try await SwiftOnig.Regex(pattern: #"\d+"#)

let combinedRegex = Regex {
    "ID-"
    onigRegex
    "!"
}

if let match = "Item ID-12345! is ready.".firstMatch(of: combinedRegex) {
    print(match.0) // "ID-12345!"
}
```

### Bridging to Swift Regex APIs

You can also turn a compiled `SwiftOnig.Regex` into a standard-library regex value and use it with APIs like `firstMatch(of:)`.

```swift
let onigRegex = try await SwiftOnig.Regex(pattern: #"\d+"#)
let swiftRegex = onigRegex.swiftRegex

if let match = "The item ID-12345! is ready.".firstMatch(of: swiftRegex) {
    print(match.output) // "12345"
}
```

### Capture Groups

```swift
let regex = try await Regex(pattern: #"(\w+):\s+(\d+)"#)
if let match = try "Age: 25".firstMatch(of: regex) {
    print("Field: \(match[1]!.substring)") // "Age"
    print("Value: \(match[2]!.substring)") // "25"
}
```

## Advanced Usage

The sections below are for workloads that need tighter control over encodings, byte-level interoperability, or repeated UTF-16 searches.

### Custom Encodings

Most applications do not need this section. Use it when your input is already stored in a specific byte encoding and you want SwiftOnig to search those bytes directly.

```swift
let gbBytes: [UInt8] = [196, 227, 186, 195] // "你好" in GB18030
let regex = try await Regex(patternBytes: gbBytes, encoding: .gb18030)

let input: [UInt8] = ... // GB18030 encoded data
if let region = try regex.firstMatch(in: input) {
    // ...
}
```

### Repeated UTF-16 Searches

When a regex is compiled with a UTF-16 encoding, passing `String`, `Substring`, `String.UTF16View`, or `Substring.UTF16View` may require SwiftOnig to materialize a temporary contiguous UTF-16 buffer for that call.

For repeated searches against the same UTF-16 data, prepare raw UTF-16 bytes once and reuse them:

```swift
let utf16Pattern = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
let regex = try await Regex(patternBytes: utf16Pattern, encoding: .utf16LittleEndian)

let preparedInput = Array("Hello, 你好!".utf16).withUnsafeBufferPointer { Data(buffer: $0) }

if let region = try regex.firstMatch(in: preparedInput) {
    print(region.range) // 14..<18
}
```

This keeps the raw-input model consistent across encodings: bytes plus explicit `Encoding`. For string-backed workflows, prefer `input.firstMatch(of: regex)` and `Regex.Match`.

### Runtime Lifecycle APIs

Most applications do not need to call `initialize(encodings:)` or `uninitialize()`.

- Use the default lazy initialization unless you have a concrete startup or teardown requirement.
- Use `initialize(encodings:)` only when you want to prewarm specific encodings.
- Use `uninitialize()` only when you deliberately want to tear down the shared runtime and stop using previously compiled regex values afterward.

## Documentation

For detailed guides and API documentation, build the DocC target:

```bash
swift package generate-documentation --target SwiftOnig
```

## Testing

SwiftOnig includes a comprehensive test suite, including a port of the official Oniguruma UTF-8 tests.

```bash
swift test
```

Run the serial variant as well when touching concurrency-sensitive or C-interop-heavy code:

```bash
swift test --no-parallel
```

## Development Setup

The repository vendors the upstream Oniguruma source as a Git submodule and builds it directly through SwiftPM.

After cloning, initialize submodules before building or changing the package internals:

```bash
git submodule update --init --recursive
```

### Formatting and Linting

SwiftOnig keeps formatting and lint rules in-repo so contributors can run the same checks locally.

```bash
make format
make lint
```

These commands expect local `swiftformat` and `swiftlint` installs and will fail fast with an install hint if the tools are missing.

### Continuous Integration

GitHub Actions validates the package on both `ubuntu-latest` and `macos-latest`, with submodules initialized and both test modes exercised:

```bash
swift test
swift test --no-parallel
```

## License

SwiftOnig is available under the MIT license. See the LICENSE file for more info.
