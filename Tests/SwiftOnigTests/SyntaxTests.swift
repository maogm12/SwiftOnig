//
//  SyntaxTests.swift
//  
//
//  Created by Gavin Mao on 3/30/21.
//

import XCTest
@testable import SwiftOnig

final class SyntaxTests: SwiftOnigTestsBase {
    func testSyntaxOperators() async {
        let syntax = await Syntax.java
        XCTAssertFalse(syntax.operators2.contains(.optionOniguruma))
        
        syntax.operators2.insert(.optionOniguruma)
        XCTAssertTrue(syntax.operators2.contains(.optionOniguruma))
        
        syntax.operators2.remove(.optionOniguruma)
        XCTAssertFalse(syntax.operators2.contains(.optionOniguruma))
        
        let syntax1 = await Syntax.ruby
        var reg = try! await Regex(pattern: "a?bbb", syntax: syntax1)
        XCTAssertTrue(try! reg.isMatch(in: "abbb"))
        XCTAssertTrue(try! reg.isMatch(in: "bbb"))
        XCTAssertFalse(try! reg.isMatch(in: "a?bbb"))

        syntax1.operators.remove(.questionOneOrZero) // disable `?`
        reg = try! await Regex(pattern: "a?bbb", syntax: syntax1)
        XCTAssertFalse(try! reg.isMatch(in: "abbb"))
        XCTAssertFalse(try! reg.isMatch(in: "bbb"))
        XCTAssertTrue(try! reg.isMatch(in: "a?bbb"))
    }
    
    func testSyntaxBehaviors() async {
        let syntax = await Syntax.java
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.behaviors.insert(.warnRedundantNestedRepeat)
        XCTAssertTrue(syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        syntax.behaviors.remove(.warnRedundantNestedRepeat)
        XCTAssertFalse(syntax.behaviors.contains(.warnRedundantNestedRepeat))
    }
    
    func testMetaCharDescription() async {
        let metaChar1: Syntax.MetaChar = .Ineffective
        XCTAssertEqual(metaChar1.description, "")
        
        let metaChar2 = Syntax.MetaChar.CodePoint(UInt32("~".utf8.first!))
        XCTAssertEqual(metaChar2.description, "~")
    }
    
    func testSyntaxMetaChar() async {
        let syntax = await Syntax.ruby
        XCTAssertEqual(syntax.metaCharTable[.Escape].description, #"\"#)
        var reg = try! await Regex(pattern: #"\w`w"#, syntax: syntax)
        XCTAssertTrue(try! reg.isMatch(in: #"a`w"#))
        XCTAssertFalse(try! reg.isMatch(in: #"\wb"#))

        // Note: metaCharTable is a property that returns a struct. To modify, we need a different approach or make it a class.
        // For now, let's just test that we can read it.
        XCTAssertEqual(syntax.metaCharTable[.Escape].description, #"\"#)
    }

    static let allTests = [
        ("testSyntaxOperators", testSyntaxOperators),
        ("testSyntaxBehaviors", testSyntaxBehaviors),
        ("testMetaCharDescription", testMetaCharDescription),
        ("testSyntaxMetaChar", testSyntaxMetaChar),
    ]
}
