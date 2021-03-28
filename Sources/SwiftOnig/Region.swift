//
//  Region.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

public class Region {
    var rawValue: OnigRegion
    
    init() {
        self.rawValue = OnigRegion()
    }
    
    init(with capacity: Int32) {
        self.rawValue = OnigRegion()
        self.reserve(capacity: capacity)
    }
    
    /// Updates the region to contain `new_capacity` slots. See
    /// [`onig_sys::onig_region_resize`][region_resize] for mor
    /// information.
    public func reserve(capacity: Int32) {
        let result = onig_region_resize(&self.rawValue, capacity)
        if result != ONIG_NORMAL {
            fatalError("Onig: fail to memory allocation during region resize")
        }
    }
}
