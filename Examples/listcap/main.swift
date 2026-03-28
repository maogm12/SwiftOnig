//
//  main.swift
//  
//
//  Created by Guangming Mao on 4/7/21.
//

import Foundation
import SwiftOnig

func execute(str: String, pattern: String, syntax: Syntax, options: Regex.Options) throws {
    print("Pattern: /\(pattern)/")
    print("String : \"\(str)\"")

    let regex = try Regex(pattern: pattern, options: options, syntax: syntax)
    guard let match = try str.firstMatch(of: regex) else {
        print("No match")
        return
    }

    for (index, capture) in match.enumerated() {
        guard let capture = capture else {
            print("Capture \(index) ==> nil")
            continue
        }
        print("Capture \(index) ==> range: \(capture.range), content: \(capture.substring)")
    }
}

func runListcap() throws {
    // SwiftOnig now handles initialization automatically on first use.
    
    let str1 = #"((())())"#
    let pattern1 = #"\g<p>(?@<p>\(\g<s>\)){0}(?@<s>(?:\g<p>)*|){0}"#

    let str2 = #"x00x00x00"#
    let pattern2 = #"(?@a)x(?@a)0(?@a)0"#

    var syntax = Syntax.default
    var operators = syntax.operators
    operators.insert(.variableMetaCharacters)
    syntax.operators = operators

    try execute(str: str1, pattern: pattern1, syntax: syntax, options: .none)
    print()
    try execute(str: str2, pattern: pattern2, syntax: syntax, options: .none)
}

Task {
    do {
        try runListcap()
        Oniguruma.uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
