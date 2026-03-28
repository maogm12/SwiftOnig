# Getting Started

Learn how to integrate SwiftOnig into your project and perform your first regular expression match.

## Installation

Add SwiftOnig as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maogm12/SwiftOnig", from: "1.0.0")
]
```

## Common Path

### 1. Create a Regex

Create a compiled regular expression object. The initializer is asynchronous and actor-isolated.

```swift
let pattern = #"\d+"#
let regex = try await Regex(pattern: pattern)
```

### 2. Perform a Match

Use the string-native `firstMatch(of:)` method to find the first occurrence of the pattern in a string.

```swift
let input = "The price is 42 dollars."
if let match = try input.firstMatch(of: regex) {
    print("Matched: \(match.substring)") // "42"
    print("Range in input: \(match.range)")
}
```

## Advanced Paths

### Optional Runtime Prewarming

SwiftOnig initializes itself automatically on first use, so no manual setup is required for normal usage.

If your application wants to prewarm specific encodings during startup, you can do that explicitly through `initialize(encodings:)`.

```swift
import SwiftOnig

try await SwiftOnig.initialize(encodings: [.utf8])
```

### Runtime Teardown

Most applications do not need to call `uninitialize()`. It is an advanced lifecycle API for cases where you explicitly want to tear down the shared runtime, and previously created regex objects must not be reused after that point.

### Non-UTF Byte Encodings

If your input is already stored in a specific byte encoding, compile the regex with that encoding and search the bytes directly.

```swift
let gbBytes: [UInt8] = [196, 227, 186, 195] // "你好" in GB18030
let regex = try await Regex(patternBytes: gbBytes, encoding: .gb18030)
let region = try regex.firstMatch(in: gbBytes)
```

### UTF-16 Input Performance

When using a UTF-16 encoded regex, `String`, `Substring`, `String.UTF16View`, and `Substring.UTF16View` may require temporary UTF-16 materialization for each call.

If repeated UTF-16 searches are performance-sensitive, prepare raw UTF-16 bytes once:

```swift
let patternData = Array("你好".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
let regex = try await Regex(patternBytes: patternData, encoding: .utf16LittleEndian)

let preparedInput = Array("Hello, 你好!".utf16).withUnsafeBufferPointer { Data(buffer: $0) }
let region = try regex.firstMatch(in: preparedInput)
```
