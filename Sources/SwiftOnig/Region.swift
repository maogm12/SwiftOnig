//
//  Region.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import Foundation

public class Region {
    var rawValue: OnigRegion
    
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
    
    public var capacity: Int32 {
        get {
            return self.rawValue.allocated
        }
    }
    
    /**
     Get the size of the region.
     - Returns: the number of registers in the region.
     */
    public var count: Int32 {
        get {
            return self.rawValue.num_regs
        }
    }
    
    /**
     Check if the region is empty.
     - Returns: `true` if there are no registers in the region.
     */
    public var isEmpty: Bool {
        get {
            return self.count == 0
        }
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
    public func utf8BytesRange(group: Int) -> Range<Int>? {
        if group >= self.count {
            return nil
        }

        let begin = Int(self.rawValue.beg.advanced(by: group).pointee)
        if begin == ONIG_REGION_NOTPOS {
            return nil
        }

        let end = Int(self.rawValue.end.advanced(by: group).pointee)
        return begin ..< end
    }
    
    /**
     Get Capture Tree
     - Returns: the capture tree for this region, if there is one, otherwise `nil`.
     */
    public var tree: CaptureTreeNode? {
        if let tree = onig_get_capture_tree(&self.rawValue) {
            return CaptureTreeNode(rawValue: tree.pointee)
        }
        
        return nil
    }
}

extension StringProtocol {
    public subscript(utf8BytesRange: Range<Int>) -> String? {
        if utf8BytesRange != utf8BytesRange.clamped(to: 0 ..< self.utf8.count) {
            return nil
        }

        return self.withCString { ptr -> String? in
            String(data: Data(bytes: ptr.advanced(by: utf8BytesRange.lowerBound),
                              count: utf8BytesRange.count),
                   encoding: .utf8)
        }
    }
}
