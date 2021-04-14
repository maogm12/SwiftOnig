//
//  main.swift
//  
//
//  Created by Gavin Mao on 4/7/21.
//

import Foundation
import SwiftOnig

try! initialize(encodings: [.utf8])
defer {
    uninitialize()
}

let pattern = #"a(.*)b|[e-f]+"#
let str = "zzzzaffffffffb"

let regex = try! Regex(pattern: pattern)

guard let region = try! regex.firstMatch(in: str) else {
    print("No match")
    exit(EXIT_SUCCESS)
}
    
for (index, subRegion) in region.enumerated() {
    guard let subRegion = subRegion else {
        print("Capture \(index) ==> nil")
        continue
    }
    print("Capture \(index) ==> range: \(subRegion.range), content: \(subRegion.string!))")
}
