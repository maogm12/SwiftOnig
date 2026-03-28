//
//  main.swift
//  
//
//  Created by Guangming Mao on 4/7/21.
//

import Foundation
import SwiftOnig

Task {
    do {
        // SwiftOnig now handles initialization automatically on first use.
        
        let pattern = #"a(.*)b|[e-f]+"#
        let str = "zzzzaffffffffb"

        let regex = try Regex(pattern: pattern)

        guard let match = try str.firstMatch(of: regex) else {
            print("No match")
            exit(EXIT_SUCCESS)
        }
            
        for (index, capture) in match.enumerated() {
            guard let capture = capture else {
                print("Capture \(index) ==> nil")
                continue
            }
            print("Capture \(index) ==> range: \(capture.range), content: \(capture.substring))")
        }
        
        await uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
