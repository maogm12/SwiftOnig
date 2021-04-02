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
        memcpy(buffer, start, count)
        self.init(cString: buffer)
        buffer.deallocate()
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
            if #available(OSX 11.0, *) {
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
}
