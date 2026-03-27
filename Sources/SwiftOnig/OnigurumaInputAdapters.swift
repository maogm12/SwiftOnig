import OnigurumaC
import Foundation

internal enum OnigurumaInputAdapters {
    internal static func withRawBytes<Result>(
        _ bytes: UnsafeRawBufferPointer,
        body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result
    ) rethrows -> Result {
        precondition(MemoryLayout<UInt8>.stride == MemoryLayout<OnigUChar>.stride, "UInt8 and OnigUChar should be the same size")

        guard let start = bytes.baseAddress?.assumingMemoryBound(to: OnigUChar.self) else {
            return try body(UnsafePointer<OnigUChar>(bitPattern: 1)!, 0)
        }

        return try body(start, bytes.count)
    }

    internal static func withUTF16CodeUnits<C, Result>(
        _ codeUnits: C,
        body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result
    ) rethrows -> Result where C: Collection, C.Element == UInt16 {
        let contiguousResult = try codeUnits.withContiguousStorageIfAvailable { buffer -> Result in
            try withUTF16BufferPointer(buffer, body: body)
        }

        if let contiguousResult {
            return contiguousResult
        }

        let copiedUnits = Array(codeUnits)
        return try copiedUnits.withUnsafeBufferPointer { buffer in
            try withUTF16BufferPointer(buffer, body: body)
        }
    }

    internal static func withUTF16BufferPointer<Result>(
        _ buffer: UnsafeBufferPointer<UInt16>,
        body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result
    ) rethrows -> Result {
        let byteCount = buffer.count * MemoryLayout<UInt16>.size
        return try buffer.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
            try body($0, byteCount)
        }
    }
}
