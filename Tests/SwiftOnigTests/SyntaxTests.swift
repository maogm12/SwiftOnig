//
//  SyntaxTest.swift
//  
//
//  Created by Gavin Mao on 3/30/21.
//

import XCTest
@testable import SwiftOnig

final class SyntaxTest: XCTestCase {
    func testSyntaxOperators() {
        let syntax = Syntax.java
        XCTAssertFalse(syntax.operators.contains(.optionOniguruma))
        
        syntax.enableOperators(operators: .optionOniguruma)
        XCTAssertTrue(syntax.operators.contains(.optionOniguruma))
        
        syntax.disableOperators(operators: .optionOniguruma)
        XCTAssertFalse(syntax.operators.contains(.optionOniguruma))
    }
    
    func testSyntaxBehaviors() {
        let syntax = Syntax.java
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.enableBehaviors(behaviors: .warnRedundantNestedRepeat)
        XCTAssertTrue(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.disableBehaviors(behaviors: .warnRedundantNestedRepeat)
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
    }
    
    func testSyntaxMetaChar() {
        let syntax = Syntax.ruby
        XCTAssertEqual(syntax.metaCharTable[.escape], Syntax.MetaChar(chars: #"\"#))
        
        syntax.metaCharTable[.escape] = Syntax.MetaChar(chars: #"`"#)
        
        var table = syntax.metaCharTable
        table[.escape] = Syntax.MetaChar(chars: #"`"#)
        XCTAssertEqual(syntax.metaCharTable[.escape], Syntax.MetaChar(chars: #"`"#))
    }

    static var allTests = [
        ("testSyntaxOperators", testSyntaxOperators),
        ("testSyntaxBehaviors", testSyntaxBehaviors),
        ("testSyntaxMetaChar", testSyntaxMetaChar),
    ]
}
