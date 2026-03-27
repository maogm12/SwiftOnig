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

        let regex = try await Regex(pattern: pattern)

        guard let region = try await regex.firstMatch(in: str) else {
            print("No match")
            exit(EXIT_SUCCESS)
        }
            
        for (index, subRegion) in region.enumerated() {
            guard let subRegion = subRegion else {
                print("Capture \(index) ==> nil")
                continue
            }
            print("Capture \(index) ==> range: \(subRegion.range), content: \(subRegion.decodedString()!))")
        }
        
        await uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
