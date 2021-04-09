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
     Create an empty `Region`.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
     */
    internal init() throws {
        self.rawValue = onig_region_new()
        if self.rawValue == nil {
            throw OnigError.memory
        }
    }

    /**
     Create a new `Region` by copying from other `Region`.
     - Parameter other: The other `Region` to copy from.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
    */
    internal convenience init(from other: Region) throws {
        try self.init()
        onig_region_copy(self.rawValue, other.rawValue)
    }
    
    /**
     Create a new `Region` with an exsiting oniguruma `OnigRegion` pointer.
     
     `Region` will take over the onwership and handle the release of the pointer.
     - Parameter rawValue: The oniguruma `OnigRegion` pointer.
     */
    internal init(rawValue: OnigRegionPointer!) {
        self.rawValue = rawValue
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
     - Parameter group: the index of the capture group.
     */
    public func range(at group: Int) -> Range<Int> {
        precondition(group >= 0 && group < self.rangeCount, "Invalid group index")
        
        let begin = Int(self.rawValue.pointee.beg[group])
        let end = Int(self.rawValue.pointee.end[group])
        return begin ..< end
    }
}

extension Region: Sequence {
    public struct Iterator: IteratorProtocol {
        private let region: Region
        private var groupIndex: Int = 0

        public init(region: Region) {
            self.region = region
        }

        public mutating func next() -> Range<Int>? {
            if self.groupIndex >= self.region.rangeCount {
                return nil
            }

            let range = self.region.range(at: self.groupIndex)
            self.groupIndex = self.groupIndex + 1
            return range
        }
    }

    public func makeIterator() -> Region.Iterator {
        return Region.Iterator(region: self)
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
