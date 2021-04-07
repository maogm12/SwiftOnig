//
//  StringUtils.swift
//  
//
//  Created by Gavin Mao on 4/1/21.
//

import COnig
import Foundation

extension String {
    /**
     Initialize a string with a part of utf8 bytes.
     */
    public init?(utf8String start: UnsafePointer<UInt8>!, end: UnsafePointer<UInt8>!) {
        if start == nil || end == nil {
            return nil
        }

        let count = start.distance(to: end)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer {
            buffer.deallocate()
        }
        buffer.initialize(from: start, count: count)
        self.init(cString: buffer)
    }
}

extension StringProtocol {
    /**
     Get a substring with a range of UTF-8 byte index.
     */
    public func subString(utf8BytesRange range: Range<Int>) -> String? {
        if range != range.clamped(to: 0 ..< self.utf8.count) {
            return nil
        }

        return self.withCString { ptr -> String? in
            if #available(OSX 11.0, iOS 14.0, *) {
                return String(unsafeUninitializedCapacity: range.count) {
                    memcpy($0.baseAddress, ptr.advanced(by: range.lowerBound), range.count)
                    return range.count
                }
            } else {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: range.count)
                memcpy(buffer, ptr.advanced(by: range.lowerBound), count)
                let subStr = String(cString: buffer)
                buffer.deallocate()
                return subStr
            }
        }
    }

    /**
     Call `body(start, count)`, where `start` is a pointer to the string content,`count`is the UTF-8 code unit count.
     - Note: The pointer passed as an argument to body might be valid only during the execution of `withOnigCString(_:)`. Do not store or return the pointer for later use.
     - Parameter body: A closure with a pointe. If body has a return value, that value is also used as the return value for the `withOnigCString(_:)` method. The pointer argument might be valid only for the duration of the method’s execution.
     - Parameter start: A pointer to the string content as an UTF-8 `OnigUChar` string.
     - Parameter count: Count of UTF-8 code units in the string.
     */
    internal func withOnigurumaString<Result>(_ body: (_ start: UnsafePointer<OnigUChar>, _ count: Int) throws -> Result) rethrows -> Result {
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
        
        // If contiguous storage, go with cstring
        return try self.withCString {
            try $0.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) {
                try body($0, byteCount)
            }
        }
    }
}
