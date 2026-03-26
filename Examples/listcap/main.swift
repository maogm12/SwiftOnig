//
//  main.swift
//  
//
//  Created by Guangming Mao on 4/7/21.
//

import Foundation
import SwiftOnig

@OnigurumaActor
func execute(str: String, pattern: String, syntax: Syntax, options: Regex.Options) async throws {
    print("Pattern: /\(pattern)/")
    print("String : \"\(str)\"")

    let regex = try await Regex(pattern: pattern, options: options, syntax: syntax)
    guard let region = try await regex.firstMatch(in: str) else {
        print("No match")
        return
    }

    for (index, subRegion) in region.enumerated() {
        guard let subRegion = subRegion else {
            print("Capture \(index) ==> nil")
            continue
        }
        print("Capture \(index) ==> range: \(subRegion.range), content: \(subRegion.string!)")
    }
}

@OnigurumaActor
func runListcap() async throws {
    // SwiftOnig now handles initialization automatically on first use.
    
    let str1 = #"((())())"#
    let pattern1 = #"\g<p>(?@<p>\(\g<s>\)){0}(?@<s>(?:\g<p>)*|){0}"#

    let str2 = #"x00x00x00"#
    let pattern2 = #"(?@a)x(?@a)0(?@a)0"#

    var syntax = Syntax.default
    var operators = syntax.operators
    operators.insert(.variableMetaCharacters)
    syntax.operators = operators

    try await execute(str: str1, pattern: pattern1, syntax: syntax, options: .none)
    print()
    try await execute(str: str2, pattern: pattern2, syntax: syntax, options: .none)
}

Task {
    do {
        try await runListcap()
        await uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
