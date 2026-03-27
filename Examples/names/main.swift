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
        let match: Regex.Match?
        
        regex = try await Regex(patternBytes: pattern.utf8,
                          encoding: await .ascii)
        match = try str.firstMatch(of: regex)

        guard let match = match else {
            print("No match")
            await uninitialize()
            exit(EXIT_SUCCESS)
        }

        print("Number of names: \(regex.namedCaptureGroupsCount)")
        regex.enumerateCaptureGroupNames { (name, groupNumber) -> Bool in
            for groupNumber in groupNumber {
                let captures = match.captures(named: name)
                if let capture = match[groupNumber] {
                    print("\(name) (\(groupNumber)): ", terminator: "")
                    print("\(capture.range) \(captures.contains { $0.groupNumber == groupNumber } ? "*" : "")")
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
