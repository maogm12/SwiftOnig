//
//  StringUtils.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import COnig
import Foundation

public protocol OnigurumaString: Sendable {
    /**
     Call `body(start, count)` with underlying `OnigUChar` bytes, where `start` is a begining address of the bytes,`count`is the count of bytes.
     
     The pointer passed as an argument to body might be valid only during the execution of `withOnigurumaString(_:)`. Do not store or return the pointer for later use.
     - Parameters:
         - body: A closure with a pointer to the underlying bytes. If body has a return value, that value is also used as the return value for the `withOnigurumaString(_:)` method. The pointer argument might be valid only for the duration of the method's execution.
         - start: A pointer to the bytes content.
         - count: Count of bytes.
     */
    func withOnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result
}

extension StringProtocol {
    /**
     Call `body(start, count)`, where `start` is a pointer to the string UTF-8 bytes content,`count`is the UTF-8 code unit count.
     
     Note: This defaults to UTF-8 as it is the native storage for Swift strings.
     */
    public func withOnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        precondition(MemoryLayout<UInt8>.size == MemoryLayout<OnigUChar>.size)

        let byteCount = self.utf8.count
        let result = try self.utf8.withContiguousStorageIfAvailable {
            try $0.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }

        if result != nil {
            return result!
        }
        
        // If contiguous storage is not available, go with cstring
        return try self.withCString {
            try $0.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }
}

// MARK: - UTF-16 Support

extension String.UTF16View: OnigurumaString {
    public func withOnigurumaString<Result>(_ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        // UTF-16 is not the native storage for Swift strings (UTF-8 is).
        // To pass this to Oniguruma as a raw pointer, we must ensure it's contiguous.
        // This involves a copy.
        let bytes = Array(self)
        return try bytes.withUnsafeBufferPointer { bufPtr in
            let byteCount = bufPtr.count * MemoryLayout<UInt16>.size
            return try bufPtr.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }
}

extension Substring.UTF16View: OnigurumaString {
    public func withOnigurumaString<Result>(_ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        let bytes = Array(self)
        return try bytes.withUnsafeBufferPointer { bufPtr in
            let byteCount = bufPtr.count * MemoryLayout<UInt16>.size
            return try bufPtr.baseAddress!.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }
}

// MARK: - Generic Byte Support

extension ContiguousBytes {
    /**
     Call `body(start, count)` with underlying `OnigUChar` bytes.
     */
    public func withOnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
        precondition(MemoryLayout<UInt8>.stride == MemoryLayout<OnigUChar>.stride, "UInt8 and OnigUChar should be the same size")
        return try self.withUnsafeBytes { bufPtr in
            guard let start = bufPtr.baseAddress?.assumingMemoryBound(to: OnigUChar.self) else {
                // Return empty content if baseAddress is nil
                return try body(UnsafePointer<OnigUChar>(bitPattern: 1)!, 0)
            }
            
            return try body(start, bufPtr.count)
        }
    }
}

// Explicit conformances for Array to avoid conflicting conditional conformances
extension Array: OnigurumaString where Element == UInt8 { }
extension ContiguousArray: OnigurumaString where Element == UInt8 { }
extension ArraySlice: OnigurumaString where Element == UInt8 { }
extension Data: OnigurumaString { }

// We can't conform Array<UInt16> directly without conflict if we already have Array<UInt8>.
// Instead, users can use `Data(array)` or `withUnsafeBytes` on their side,
// OR we can provide a wrapper. 
// For now, let's just stick to UInt8 arrays and Data.

extension CollectionOfOne : OnigurumaString where Element == UInt8 { }

extension Slice : OnigurumaString where Base : OnigurumaString {
    public func withOnigurumaString<Result>(_ body: (UnsafePointer<OnigUChar>, Int) throws -> Result) rethrows -> Result {
        let offset = base.distance(from: base.startIndex, to: self.startIndex)
        return try base.withOnigurumaString { (baseStart, baseCount) in
            try body(baseStart.advanced(by: offset), self.count)
        }
    }
}

extension String: OnigurumaString { }

extension Substring: OnigurumaString { }
