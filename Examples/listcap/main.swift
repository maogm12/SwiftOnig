//
//  main.swift
//  
//
//  Created by Gavin Mao on 4/13/21.
//

import Foundation
import SwiftOnig

func execute(str: String, pattern: String, syntax: Syntax, options: Regex.Options) throws {
    let regex = try Regex(pattern: pattern,
                           options: options,
                           syntax: syntax)
    print("Pattern: /\(pattern)/ String: \(str)")
    print("Number of captures: \(regex.captureGroupCount)")
    print("Number of capture histories: \(regex.captureHistoryCount)")
    
    guard let region = try regex.firstMatch(in: str) else {
        print("Search fail")
        return
    }

    print("Match at \(region.range.startIndex)")
    for (index, subRegion) in region.enumerated() {
        guard let subRegion = subRegion else {
            print("\(index): nil")
            continue
        }

        print("\(index): \(subRegion.range)")
    }
    print()
    
    region.enumerateCaptureTreeNodes(beforeTraversingChildren: { (groupNumber, range, level) -> Bool in
        print(String(repeating: " ", count: level * 2), terminator: "")
        print("\(groupNumber): \(range)")
        return true
    })
    print()
}

try! initialize(encodings: [.utf8])
defer {
    uninitialize()
}

let str1 = #"((())())"#;
let pattern1 = #"\g<p>(?@<p>\(\g<s>\)){0}(?@<s>(?:\g<p>)*|){0}"#;

let str2 = #"x00x00x00"#
let pattern2 = #"(?@x(?@\d+))+"#

let str3 = #"0123"#
let pattern3 = #"(?@.)(?@.)(?@.)(?@.)"#

let str4 = #"(((a))(a)) ((((a))(a)))"#
let pattern4 = #"\g<p>(?@<p>\(\g<s>\)){0}(?@<s>(?:\g<p>)*|a){0}"#

let syntax = Syntax.default
syntax.operators.insert(.atmarkCaptureHistory)

do {
    try execute(str: str1, pattern: pattern1, syntax: syntax, options: .none)
    try execute(str: str2, pattern: pattern2, syntax: syntax, options: .none)
    try execute(str: str3, pattern: pattern3, syntax: syntax, options: .none)
    try execute(str: str4, pattern: pattern4, syntax: syntax, options: .findLongest)
} catch {
    print("Error: \(error)")
    exit(EXIT_FAILURE)
}
