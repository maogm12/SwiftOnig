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
    
for (index, range) in region.enumerated() {
    print("Capture \(index) ==> range: \(range), content: \(str.subString(utf8BytesRange: range)!)")
}
