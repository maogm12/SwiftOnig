//
//  Region.swift
//
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

/**
 A wrapper of oniguruma `OnigRegion` which represents the results of a single regular expression match.
 
 In `SwiftOnig`, `Region` is supposed to be immutable and only used as the result of regular expression matches. So it only wrap new/delete and immutable query APIs of `OnigRegion`:
 - `onig_region_new`: wrapped in `init`.
 - `onig_region_copy`: wrapped in `init(from:)`.
 - `onig_region_free`: wrapper in `deinit`.

 Those APIs are not wrapped becuase there is no need to reuse  `Region` in regular expression matches as in C.
 - `onig_region_clear`
 - `onig_region_resize`
 - `onig_region_set`
 */
public class Region {
    internal typealias OnigRegionPointer = UnsafeMutablePointer<OnigRegion>
    internal var rawValue: OnigRegionPointer!
    
    /**
     The regular expression used in match operation.
     */
    internal var regex: Regex

    /**
     The string matched against.
     */
    internal var str: OnigurumaString

    // MARK: init and deinit
    
    /**
     Create an empty `Region`.
     - Parameter regex: The associated `Regex` object.
     - Parameter text: The string matched against.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
     */
    internal init(regex: Regex, str: OnigurumaString) throws {
        self.rawValue = onig_region_new()
        if self.rawValue == nil {
            throw OnigError.memory
        }
        
        self.regex = regex
        self.str = str
    }

    /**
     Create a new `Region` by copying from other `Region`.
     - Parameters:
        - other: The other `Region` to copy from.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
    */
    internal convenience init(copying other: Region) throws {
        try self.init(regex: other.regex, str: other.str)
        onig_region_copy(self.rawValue, other.rawValue)
    }
    
    /**
     Create a new `Region` by coping from an exsiting oniguruma `OnigRegion` pointer.
     
     - Parameters:
        - rawValue: The oniguruma `OnigRegion` pointer.
        - regex: The associated `Regex` object.
     */
    internal convenience init(copying rawValue: OnigRegionPointer!, regex: Regex, str: OnigurumaString) throws {
        try self.init(regex: regex, str: str)
        onig_region_copy(self.rawValue, rawValue)
    }

    deinit {
        onig_region_free(self.rawValue, 1 /* free_self */)
        self.rawValue = nil
    }

    /**
     Get the number of subregion in the region.
     
     A region will have at least one subregion representing the whole matched portion, but may optionally have more, for example for a regular expression with capture groups.
     */
    public var count: Int {
        Int(self.rawValue.pointee.num_regs)
    }
}

// MARK: Subregion

/**
 `Subregion` represents the matching result for a single capture group.
 */
public struct Subregion {
    /// The `Region` this `Subregion` belongs to.
    public let region: Region

    /// The n-th capture group. `0` means the whole matching portition.
    public let group: Int

    /// Get the range of the this capture group.
    public var range: Range<Int> {
        let begin = Int(self.region.rawValue.pointee.beg[self.group])
        let end = Int(self.region.rawValue.pointee.end[self.group])
        return begin ..< end
    }

    /// Get the matched string of this capture group, if the encoding of the regular expression fails to encode the bytes in the range, `nil` will be returned.
    public var string: String? {
        let range = self.range
        return self.region.str.withOnigurumaString { (start, count) -> String? in
            String(bytes: UnsafeBufferPointer(start: start.advanced(by: range.lowerBound),
                                              count: range.count),
                   encoding: self.region.regex.encoding.stringEncoding)
        }
    }
}

extension Region: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Subregion

    public var startIndex: Int {
        0
    }

    public var endIndex: Int {
        self.count
    }

    /**
     Get the subregion of n-th capture group.
     */
    public subscript(group: Int) -> Subregion {
        precondition(group >= 0 && group < self.count, "Group index \(group) out of range")
        return Subregion(region: self, group: group)
    }

    /**
     Get the subregions of named capture groups with the specified name.
     */
    public subscript(name: String) -> [Subregion] {
        self.regex.namedCaptureGroupIndexes(of: name).map { Subregion(region: self, group: $0) }
    }
}
