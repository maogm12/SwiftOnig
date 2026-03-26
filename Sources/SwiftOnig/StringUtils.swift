//
//  StringUtils.swift
//  
//
//  Created by Guangming Mao on 4/1/21.
//

import OnigurumaC
import Foundation

public protocol OnigurumaString: Sendable {
    /**
     Call `body(start, count)` with underlying `OnigUChar` bytes, where `start` is a begining address of the bytes,`count`is the count of bytes.
     
     The pointer passed as an argument to body might be valid only during the execution of `withOnigurumaString(_:)`. Do not store or return the pointer for later use.
     - Parameters:
         - encoding: The requested encoding. For types that support multiple encodings (like `String`), this allows the type to choose the most efficient path.
         - body: A closure with a pointer to the underlying bytes.
     */
    func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result
}

extension StringProtocol {
    /// Internal helper to provide UTF-8 bytes to Oniguruma.
    internal func _withUTF8OnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        precondition(MemoryLayout<UInt8>.size == MemoryLayout<OnigUChar>.size)

        let byteCount = self.utf8.count
        let result = try self.utf8.withContiguousStorageIfAvailable {
            try $0.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }

        if let result = result {
            return result
        }
        
        return try self.withCString {
            try $0.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }

    /// Internal helper to provide UTF-16 bytes to Oniguruma.
    internal func _withUTF16OnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        // Optimization: Try to get contiguous storage if this is a bridged NSString
        let result = try self.utf16.withContiguousStorageIfAvailable { bufPtr -> Result in
            let byteCount = bufPtr.count * MemoryLayout<UInt16>.size
            return try bufPtr.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
        
        if let result = result {
            return result
        }

        // Fallback: Copy to a contiguous buffer
        let units = Array(self.utf16)
        return try units.withUnsafeBufferPointer { bufPtr in
            let byteCount = bufPtr.count * MemoryLayout<UInt16>.size
            return try bufPtr.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }

    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        // Smart Encoding Negotiation:
        // If the regex is UTF-16, provide UTF-16 bytes directly (efficient for NSString).
        // Otherwise, default to UTF-8 (native for Swift String).
        
        let isUTF16 = requestedEncoding.rawValue == get_onig_utf16be() || requestedEncoding.rawValue == get_onig_utf16le()
        
        if isUTF16 {
            return try _withUTF16OnigurumaString(body)
        } else {
            return try _withUTF8OnigurumaString(body)
        }
    }
}

// MARK: - Generic Byte Support

extension ContiguousBytes {
    /**
     Call `body(start, count)` with underlying `OnigUChar` bytes.
     Requested encoding is ignored for raw byte types as they only have one representation.
     */
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { bufPtr in
            try OnigurumaInputAdapters.withRawBytes(bufPtr, body: body)
        }
    }
}

// Fixed conformances to avoid conflicts
extension ArraySlice : OnigurumaString where Element == UInt8 { 
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { bufPtr in
            try OnigurumaInputAdapters.withRawBytes(bufPtr, body: body)
        }
    }
}

extension ContiguousArray : OnigurumaString where Element == UInt8 { 
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { bufPtr in
            try OnigurumaInputAdapters.withRawBytes(bufPtr, body: body)
        }
    }
}

extension CollectionOfOne : OnigurumaString where Element == UInt8 { 
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        let val = self.first!
        let bytes = [val]
        return try bytes.withUnsafeBufferPointer { bufPtr in
            try body(UnsafePointer<OnigUChar>(OpaquePointer(bufPtr.baseAddress!)), 1)
        }
    }
}

extension Slice : OnigurumaString where Base : OnigurumaString {
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        let offset = base.distance(from: base.startIndex, to: self.startIndex)
        return try base.withOnigurumaString(requestedEncoding: requestedEncoding) { (baseStart, baseCount) in
            try body(baseStart.advanced(by: offset), self.count)
        }
    }
}

extension Data: OnigurumaString { 
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { bufPtr in
            try OnigurumaInputAdapters.withRawBytes(bufPtr, body: body)
        }
    }
}

extension String.UTF16View: OnigurumaString {
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        try OnigurumaInputAdapters.withUTF16CodeUnits(self, body: body)
    }
}

extension Substring.UTF16View: OnigurumaString {
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        try OnigurumaInputAdapters.withUTF16CodeUnits(self, body: body)
    }
}

// Special handling for Array to avoid conflicts between [UInt8] and [UInt16]
extension Array: OnigurumaString where Element == UInt8 {
    public func withOnigurumaString<Result>(requestedEncoding: Encoding, _ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        return try self.withUnsafeBytes { bufPtr in
            try OnigurumaInputAdapters.withRawBytes(bufPtr, body: body)
        }
    }
}

extension String: OnigurumaString { }

extension Substring: OnigurumaString { }
