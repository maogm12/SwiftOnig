//
//  main.swift
//  
//
//  Created by Gavin Mao on 4/13/21.
//

import Foundation
import SwiftOnig

func execute(pattern: String, str: String, options: Regex.SearchOptions) async throws {
    print("Pattern: /\(pattern)/ String: \(str)")
    let regex = try await Regex(pattern: pattern)
    let numberOfMatches = try regex.enumerateMatches(in: str, options: options) { (order, index, region) -> Bool in
        print("Scan: \(order)")
        
        print("Match at \(index)")
        for (i, subRegion) in region.enumerated() {
            guard let subRegion = subRegion else {
                print("\(i): non matched group")
                continue
            }
            
            print("\(i): \(subRegion.range)")
        }
        
        return true
    }
    print("Total: \(numberOfMatches) matches.\n")
}

Task {
    do {
        try await initialize(encodings: [.utf8])
        
        try await execute(pattern: #"\Ga+\s*"#, str: "a aa aaa baaa", options: .none)
        try await execute(pattern: #"\Ga+\s*"#, str: "a aa aaa baaa", options: .notBeginPosition)
        try await execute(pattern: #"(?!\G)a+\s*"#, str: "a aa aaa baaa", options: .none)
        try await execute(pattern: #"(?!\G)a+\s*"#, str: "a aa aaa baaa", options: .notBeginPosition)
        try await execute(pattern: #"a+\s*"#, str: "a aa aaa baaa", options: .none)
        
        await uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
