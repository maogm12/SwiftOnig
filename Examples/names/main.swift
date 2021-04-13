//
//  main.swift
//  
//
//  Created by Gavin Mao on 4/12/21.
//

import Foundation
import SwiftOnig

try! initialize(encodings: [.ascii])
defer {
    uninitialize()
}

let pattern = #"(?<foo>a*)(?<bar>b*)(?<foo>c*)"#;
let str = "aaabbbbcc";

let regex: Regex
let region: Region?
do {
    regex = try Regex(patternBytes: pattern.utf8,
                      encoding: .ascii)
    region = try regex.firstMatch(in: str)
} catch {
    print("Error: \(error)")
    exit(EXIT_FAILURE)
}

guard let region = region else {
    print("No match")
    exit(EXIT_SUCCESS)
}

print("Number of names: \(regex.namedCaptureGroupCount)")
regex.enumerateNamedCaptureGroups { (name, groupNumber) -> Bool in
    for groupNumber in groupNumber {
        let backRefGroupNumber = region.backReferencedGroupNumber(of: name)
        print("\(name) (\(groupNumber)): ", terminator: "")
        print("\(region[groupNumber].range) \(backRefGroupNumber == groupNumber ? "*" : "")")
    }

    return true
}
