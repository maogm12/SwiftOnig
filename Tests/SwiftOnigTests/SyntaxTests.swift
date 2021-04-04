//
//  SyntaxTest.swift
//  
//
//  Created by Gavin Mao on 3/30/21.
//

import XCTest
@testable import SwiftOnig

final class SyntaxTest: SwiftOnigTestsBase {
    func testSyntaxOperators() {
        let syntax = Syntax.java
        XCTAssertFalse(syntax.operators.contains(.optionOniguruma))
        
        syntax.operators.insert(.optionOniguruma)
        XCTAssertTrue(syntax.operators.contains(.optionOniguruma))
        
        syntax.operators.remove(.optionOniguruma)
        XCTAssertFalse(syntax.operators.contains(.optionOniguruma))
        
        let syntax1 = Syntax.ruby
        var reg = try! Regex("a?bbb", syntax: syntax1)
        XCTAssertTrue(reg.isMatch("abbb"))
        XCTAssertTrue(reg.isMatch("bbb"))
        XCTAssertFalse(reg.isMatch("a?bbb"))

        syntax1.operators.remove(.qmarkZeroOne) // disable `?`
        reg = try! Regex("a?bbb", syntax: syntax1)
        XCTAssertFalse(reg.isMatch("abbb"))
        XCTAssertFalse(reg.isMatch("bbb"))
        XCTAssertTrue(reg.isMatch("a?bbb"))
    }
    
    func testSyntaxBehaviors() {
        let syntax = Syntax.java
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.behaviors.insert(.warnRedundantNestedRepeat)
        XCTAssertTrue(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.behaviors.remove(.warnRedundantNestedRepeat)
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
    }
    
    func testMetaCharDescription() {
        let metaChar1: Syntax.MetaChar = .Ineffective
        XCTAssertEqual(metaChar1.description, "")
        
        let metaChar2 = Syntax.MetaChar(from: "~~~")
        XCTAssertEqual(metaChar2.description, "~~~")
    }
    
    func testSyntaxMetaChar() {
        let syntax = Syntax.ruby
        XCTAssertEqual(syntax.metaCharTable[.escape], Syntax.MetaChar(from: #"\"#))
        var reg = try! Regex(#"\w`w"#, syntax: syntax)
        XCTAssertTrue(reg.isMatch(#"a`w"#))
        XCTAssertFalse(reg.isMatch(#"\wb"#))

        syntax.metaCharTable[.escape] = Syntax.MetaChar(from: #"`"#) // change escape char to `
        XCTAssertEqual(syntax.metaCharTable[.escape], Syntax.MetaChar(from: #"`"#))
        reg = try! Regex(#"\w`w"#, syntax: syntax)
        XCTAssertFalse(reg.isMatch(#"a`w"#))
        XCTAssertTrue(reg.isMatch(#"\wb"#))
    }

    static var allTests = [
        ("testSyntaxOperators", testSyntaxOperators),
        ("testSyntaxBehaviors", testSyntaxBehaviors),
        ("testMetaCharDescription", testMetaCharDescription),
        ("testSyntaxMetaChar", testSyntaxMetaChar),
    ]
}
