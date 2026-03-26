# Getting Started

Learn how to integrate SwiftOnig into your project and perform your first regular expression match.

## Installation

Add SwiftOnig as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maogm12/SwiftOnig", from: "1.0.0")
]
```

## Basic Usage

### 1. Initialize the Library

Before using SwiftOnig, you must initialize it with the encodings you plan to use. This is a thread-safe operation managed by `@OnigurumaActor`.

```swift
import SwiftOnig

try await SwiftOnig.initialize(encodings: [.utf8])
```

### 2. Create a Regex

Create a compiled regular expression object. The initializer is asynchronous and actor-isolated.

```swift
let pattern = #"\d+"#
let regex = try await Regex(pattern: pattern)
```

### 3. Perform a Match

Use the `firstMatch(in:)` method to find the first occurrence of the pattern in a string.

```swift
let input = "The price is 42 dollars."
if let region = try await regex.firstMatch(in: input) {
    print("Matched: \(region.string!)") // "42"
}
```

### 4. Cleanup

When you are finished using the library, call `uninitialize()` to free global resources.

```swift
await SwiftOnig.uninitialize()
```
