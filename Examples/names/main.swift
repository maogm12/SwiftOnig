//
//  main.swift
//  
//
//  Created by Guangming Mao on 4/12/21.
//

import Foundation
import SwiftOnig

Task {
    do {
        // SwiftOnig now handles initialization automatically on first use.
        
        let pattern = #"(?<foo>a*)(?<bar>b*)(?<foo>c*)"#;
        let str = "aaabbbbcc";

        let regex: Regex
        let region: Region?
        
        regex = try await Regex(patternBytes: pattern.utf8,
                          encoding: await .ascii)
        region = try regex.firstMatch(in: str)

        guard let region = region else {
            print("No match")
            await uninitialize()
            exit(EXIT_SUCCESS)
        }

        print("Number of names: \(regex.namedCaptureGroupsCount)")
        regex.enumerateCaptureGroupNames { (name, groupNumber) -> Bool in
            for groupNumber in groupNumber {
                let backRefGroupNumber = region.backReferencedGroupNumber(of: name)
                if let subRegion = region[groupNumber] {
                    print("\(name) (\(groupNumber)): ", terminator: "")
                    print("\(subRegion.range) \(backRefGroupNumber == groupNumber ? "*" : "")")
                }
            }

            return true
        }
        
        await uninitialize()
        exit(EXIT_SUCCESS)
    } catch {
        print("Error: \(error)")
        exit(EXIT_FAILURE)
    }
}

dispatchMain()
