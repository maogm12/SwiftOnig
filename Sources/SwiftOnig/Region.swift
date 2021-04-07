//
//  Region.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

/**
 Match result region type.
 */
public class Region {
    internal var rawValue: OnigRegion

    init() {
        self.rawValue = OnigRegion(allocated: 0,
                                   num_regs: 0,
                                   beg: nil,
                                   end: nil,
                                   history_root: nil)
    }
    
    convenience init(with capacity: Int32) {
        self.init()
        self.reserve(capacity: capacity)
    }

    /**
     Copy from other `OnigRegion`.
    */
    convenience init(from other: Region) {
        self.init()
        onig_region_copy(&self.rawValue, &other.rawValue)
    }

    internal init(rawValue: OnigRegion) {
        self.rawValue = rawValue
    }
    
    deinit {
        onig_region_free(&self.rawValue, 0 /* free_self */)
    }
    
    public var capacity: Int32 {
        return self.rawValue.allocated
    }
    
    /**
     Get the size of the region.
     - Returns: the number of registers in the region.
     */
    public var count: Int32 {
        return self.rawValue.num_regs
    }
    
    /**
     Check if the region is empty.
     - Returns: `true` if there are no registers in the region.
     */
    public var isEmpty: Bool {
        return self.count == 0
    }
    
    /**
     Updates the region to contain `capacity` slots.
     - Parameters:
        - capacity: The new capacity
    */
    public func reserve(capacity: Int32) {
        let result = onig_region_resize(&self.rawValue, capacity)
        if result != ONIG_NORMAL {
            fatalError("Onig: fail to memory allocation during region resize")
        }
    }

    /**
     Clear out a region so it can be used again.
     */
    public func clear() {
        onig_region_clear(&self.rawValue)
    }
    
    /**
     Get the position range of the Nth capture group.
     - Returns: `nil` if `group` is not a valid capture group or if the capture group did not match anything. The range returned are always byte indices with respect to the original string matched.
     */
    public func utf8BytesRange(groupIndex: Int) -> Range<Int>? {
        if groupIndex >= self.count {
            return nil
        }
        
        let begin = Int(self.rawValue.beg[groupIndex])
        if begin == ONIG_REGION_NOTPOS {
            return nil
        }

        let end = Int(self.rawValue.end[groupIndex])
        if end == ONIG_REGION_NOTPOS {
            return nil
        }

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
            let range = self.region.utf8BytesRange(groupIndex: self.groupIndex)
            self.groupIndex = self.groupIndex + 1
            return range
        }
    }

    public func makeIterator() -> Region.Iterator {
        return Region.Iterator(region: self)
    }
}
