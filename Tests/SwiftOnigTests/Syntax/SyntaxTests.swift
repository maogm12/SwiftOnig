//
//  SyntaxTests.swift
//  
//
//  Created by Guangming Mao on 4/4/21.
//

import Testing
@testable import SwiftOnig

@Suite("Syntax Tests")
struct SyntaxTests {
    @Test("Syntax operators")
    func operators() async throws {
        let syntax = await Syntax.java
        #expect(await syntax.operators2.contains(.escVVerticalTab))
        
        let ruby = await Syntax.ruby
        let reg = try await Regex(pattern: "a?bbb", syntax: ruby)
        #expect(try await reg.matches("abbb"))
        #expect(try await reg.matches("bbb"))
    }
    
    @Test("Syntax behaviors")
    func behaviors() async throws {
        let syntax = await Syntax.java
        #expect(await !syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        let ruby = await Syntax.ruby
        #expect(await ruby.behaviors.contains(.warnRedundantNestedRepeat))
    }
    
    @Test("Syntax MetaCharacters")
    func metaChars() async throws {
        let ruby = await Syntax.ruby
        #expect(await ruby.metaCharTable[.Escape].description == #"\"#)
    }

    @Test("MetaChar Description safety")
    func metaCharDescription() async throws {
        let syntax = await Syntax.ruby
        for key in Syntax.MetaCharIndex.allCases {
            _ = await syntax.metaCharTable[key].description
        }
    }
}
