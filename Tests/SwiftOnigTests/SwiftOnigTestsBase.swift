//
//  SwiftOnigTestsBase.swift
//  
//
//  Created by Guangming Mao on 4/12/21.
//

import Testing
import SwiftOnig

@OnigurumaActor
struct SwiftOnigTestSupport {
    static func setup() async throws {
        // SwiftOnig now handles initialization automatically,
        // but we can pre-warm if needed.
    }
}
