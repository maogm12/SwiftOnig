# Introduction

SwiftOnig is a modern, high-performance regular expression library for Swift, built as a wrapper around the powerful [Oniguruma](https://github.com/kkos/oniguruma) C library.

## Overview

While Swift provides built-in regular expression support, SwiftOnig offers several advantages for specialized use cases:
- **Comprehensive Encoding Support**: Support for a wide range of character encodings beyond UTF-8 and UTF-16.
- **Advanced Syntax Modes**: Support for Perl, Python, Java, Ruby, and many other regex syntaxes.
- **Capture History**: Access to the complete hierarchy of capture group matches.
- **Modern Swift Integration**: Full support for Swift Concurrency (`async/await`) and thread-safety (`Sendable`).

## Key Concepts

### Regex
The core class used to compile and execute regular expressions.

### Region
Represents the result of a match, including all capture groups and their ranges.

### Encoding
Wraps Oniguruma's character encoding system, allowing searches in various byte formats.

### Syntax
Defines the rules and operators used by the regular expression engine.
