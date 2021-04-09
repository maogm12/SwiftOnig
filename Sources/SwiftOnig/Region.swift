//
//  Region.swift
//
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

/**
 A wrapper of oniguruma `OnigRegion` which represents the results of a single regular expression match.
 
 In `SwiftOnig`, `Region` is supposed to immutable and only used as the result of regular expression matches. So it only wrap new/delete and immutable query APIs of `OnigRegion`:
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
     Create an empty `Region`.
     - Parameter regex: The associated `Regex` object.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
     */
    internal init(with regex: Regex) throws {
        self.rawValue = onig_region_new()
        if self.rawValue == nil {
            throw OnigError.memory
        }
        
        self.regex = regex
    }

    /**
     Create a new `Region` by copying from other `Region`.
     - Parameters:
        - other: The other `Region` to copy from.
        - regex: The associated `Regex` object.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
    */
    internal convenience init(from other: Region) throws {
        try self.init(with: other.regex)
        onig_region_copy(self.rawValue, other.rawValue)
    }
    
    /**
     Create a new `Region` with an exsiting oniguruma `OnigRegion` pointer.
     
     `Region` will take over the onwership and handle the release of the pointer.
     - Parameter rawValue: The oniguruma `OnigRegion` pointer.
     - Parameter regex: The associated `Regex` object.
     */
    internal init(rawValue: OnigRegionPointer!, regex: Regex) {
        self.rawValue = rawValue
        self.regex = regex
    }

    deinit {
        onig_region_free(self.rawValue, 1 /* free_self */)
        self.rawValue = nil
    }

    /**
     Get the matched range of the region.
     
     The index of the range is the position in bytes of the string matched against. This property value is the same as `range(at: 0)`.
     */
    public var range: Range<Int> {
        precondition(self.rangeCount >= 1, "Empty region")
        return self.range(at: 0)
    }
    
    /**
     Get the number of ranges in the region.
     
     A region will have at least one range representing the whole matched portion (see also `range` property), but may optionally have more, for example for a regular expression with capture groups.
     */
    public var rangeCount: Int {
        Int(self.rawValue.pointee.num_regs)
    }

    /**
     Get the range of the n-th capture group.

     The index of the range is the position in bytes of the string matched against. Property `range` value is the same as `range(at: 0)`.
     - Parameter group: The index of the capture group.
     - Returns: The range of the n-th capture group.
     */
    public func range(at group: Int) -> Range<Int> {
        precondition(group >= 0 && group < self.rangeCount, "Invalid group index")
        
        let begin = Int(self.rawValue.pointee.beg[group])
        let end = Int(self.rawValue.pointee.end[group])
        return begin ..< end
    }
    
    /**
     Get the ranges of named capture groups with the specified name.
     
     The index of the range is the position in bytes of the string matched against.
     - Parameter group: The name of the named capture groups.
     - Returns: An array of ranges of named capture groups with the specified name. Or `[]` if no such group exists.
     */
    public func ranges(with name: String) -> [Range<Int>] {
        self.regex.namedCaptureGroupIndexes(of: name).map { self.range(at: $0) }
    }
}

extension Region: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Range<Int>

    public var startIndex: Int {
        0
    }

    public var endIndex: Int {
        self.rangeCount
    }

    public subscript(group: Int) -> Range<Int> {
        self.range(at: group)
    }
}
