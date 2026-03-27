# Advanced Encodings

Use `Encoding` directly when your application already owns byte-oriented text data and wants precise control over how SwiftOnig interprets those bytes.

Most applications do not need this article. If your data starts as Swift `String`, the common path is still:

1. Compile a `Regex` from a Swift string pattern.
2. Search another Swift string.
3. Use `Region.decodedString()`, `Region.range(in:)`, or `Region.substring(in:)` to inspect the result.

## When to Use `Encoding`

Reach for `Encoding` when one of these is true:

- Your input is already stored as encoded bytes such as GB18030 or Big5.
- You need regex behavior tied to a specific Oniguruma encoding.
- You need to reason about character boundaries in encoded byte buffers.

## Searching Encoded Bytes

Compile the regex with the same encoding as the input bytes:

```swift
let gbBytes: [UInt8] = [196, 227, 186, 195] // "你好" in GB18030
let regex = try await Regex(patternBytes: gbBytes, encoding: .gb18030)

if let region = try regex.firstMatch(in: gbBytes) {
    print(region.range)
}
```

## Byte Boundary Helpers

`Encoding` also exposes lower-level helpers for encoded byte buffers:

- `previousCharacterHead(in:before:)`
- `leftAdjustedCharacterHead(in:at:)`
- `rightAdjustedCharacterHead(in:at:)`
- `characterCount(in:)`
- `nullTerminatedCharacterCount(in:)`
- `nullTerminatedByteCount(in:)`

These are expert APIs. Use them when you need to align arbitrary byte offsets to valid character boundaries before calling lower-level regex operations or interoperating with external byte-based systems.

## UTF-16 Note

UTF-16 has an extra performance consideration: searching `String` or `String.UTF16View` with a UTF-16 regex may materialize temporary contiguous UTF-16 storage for that call.

For repeated UTF-16 searches, prefer `UTF16CodeUnitBuffer` so that materialization is explicit and reusable.
