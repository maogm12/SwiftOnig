import Testing
import Foundation
import OnigurumaC
@testable import SwiftOnig

@Suite("Internal Coverage Tests")
struct InternalCoverageTests {
    final class FakeOwnedResource: OnigOwnedResource {
        typealias RawResource = Int

        var rawValue: Int!
        private(set) var released = [Int]()

        init(rawValue: Int?) {
            self.rawValue = rawValue
        }

        func releaseRawValue(_ rawValue: Int) {
            released.append(rawValue)
        }
    }

    @Test("Owned resource cleanup releases and nils the raw value")
    func ownedResourceCleanup() {
        let resource = FakeOwnedResource(rawValue: 42)
        resource.cleanUpRawValue()
        #expect(resource.released == [42])
        #expect(resource.rawValue == nil)

        resource.cleanUpRawValue()
        #expect(resource.released == [42])
    }

    @Test("Supported Oniguruma inputs cover string and raw byte variants")
    func supportedInputDispatch() throws {
        let inputs: [Any] = [
            "hello",
            "world"[...],
            Data([1, 2, 3]),
            [UInt8]([1, 2, 3]),
            ArraySlice<UInt8>([1, 2, 3][1...]),
            ContiguousArray<UInt8>([1, 2, 3]),
            CollectionOfOne<UInt8>(7),
            "hi".utf16,
            "bye"[...].utf16,
        ]

        for input in inputs {
            let byteCount = try withSupportedOnigurumaInput(input, requestedEncoding: .utf8) { supported in
                supported.withOnigurumaString(requestedEncoding: .utf8) { _, count in
                    count
                }
            }
            #expect(byteCount >= 0)
        }
    }

    @Test("Unsupported Oniguruma inputs throw invalid argument")
    func unsupportedInputDispatch() {
        #expect(throws: OnigError.invalidArgument) {
            try withSupportedOnigurumaInput(123, requestedEncoding: .utf8) { _ in () }
        }
    }

    @Test("String adapters expose UTF-8 and UTF-16 byte counts")
    func stringAdapterCounts() throws {
        let input = "你好a"

        let utf8Count = input.withOnigurumaString(requestedEncoding: .utf8) { _, count in count }
        let utf16Count = input.withOnigurumaString(requestedEncoding: .utf16LittleEndian) { _, count in count }

        #expect(utf8Count == input.utf8.count)
        #expect(utf16Count == input.utf16.count * MemoryLayout<UInt16>.size)
    }

    @Test("Slice adapters preserve offsets and counts")
    func sliceAdapterOffsets() throws {
        let bytes: ArraySlice<UInt8> = [10, 11, 12, 13][1...2]
        let expected = Array(bytes)

        let collected = bytes.withOnigurumaString(requestedEncoding: .utf8) { start, count in
            Array(UnsafeBufferPointer(start: start, count: count))
        }

        #expect(collected == expected)
    }

    @Test("CollectionOfOne byte adapter exposes exactly one byte")
    func collectionOfOneAdapter() throws {
        let input = CollectionOfOne<UInt8>(255)

        let result = input.withOnigurumaString(requestedEncoding: .utf8) { start, count in
            (count, start.pointee)
        }

        #expect(result.0 == 1)
        #expect(result.1 == 255)
    }

    @Test("UTF-16 views expose UTF-16 byte counts")
    func utf16ViewAdapters() throws {
        let input = "你好"
        let stringCount = input.utf16.withOnigurumaString(requestedEncoding: .utf16LittleEndian) { _, count in count }
        let substringCount = input[...].utf16.withOnigurumaString(requestedEncoding: .utf16LittleEndian) { _, count in count }

        #expect(stringCount == input.utf16.count * 2)
        #expect(substringCount == input.utf16.count * 2)
    }
}
