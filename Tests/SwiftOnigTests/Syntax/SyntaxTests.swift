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
        let syntax = Syntax.java
        #expect(syntax.operators2.contains(.escVVerticalTab))
        #expect(syntax.operators.contains(.escCapitalGBeginAnchor))

        let ruby = Syntax.ruby
        let reg = try await Regex(pattern: "a?bbb", syntax: ruby)
        #expect(try reg.matches("abbb"))
        #expect(try reg.matches("bbb"))
    }
    
    @Test("Syntax behaviors")
    func behaviors() async throws {
        let syntax = Syntax.java
        #expect(!syntax.behaviors.contains(.warnRedundantNestedRepeat))
        
        let ruby = Syntax.ruby
        #expect(ruby.behaviors.contains(.warnRedundantNestedRepeat))
    }
    
    @Test("Syntax MetaCharacters")
    func metaChars() async throws {
        let ruby = Syntax.ruby
        #expect(ruby.metaCharTable[.Escape].description == #"\"#)
    }

    @Test("MetaChar Description safety")
    func metaCharDescription() async throws {
        let syntax = Syntax.ruby
        for key in Syntax.MetaCharIndex.allCases {
            _ = syntax.metaCharTable[key].description
        }
    }

    @Test("Python syntax preset and additional flags")
    func pythonSyntax() async throws {
        @OnigurumaActor
        func configureAdditionalFlags(on syntax: inout Syntax) {
            var operators2 = syntax.operators2
            operators2.insert(.qmarkLtNamedGroup)
            operators2.insert(.escPBraceCircumflexNot)
            operators2.insert(.escGSubexpCall)
            operators2.insert(.escCapitalNSuperDot)
            syntax.operators2 = operators2
        }

        let python = Syntax.python
        #expect(python.operators.contains(.escCapitalGBeginAnchor))

        let regex = try await Regex(pattern: #"(?P<word>\w+)(?P=word)"#, syntax: python)
        #expect(try regex.matches("hellohello"))
        #expect(try !regex.matches("helloworld"))

        var custom = Syntax(copying: Syntax.default)
        await configureAdditionalFlags(on: &custom)
        #expect(custom.operators2.contains(.qmarkLtNamedGroup))
        #expect(custom.operators2.contains(.escPBraceCircumflexNot))
        #expect(custom.operators2.contains(.escGSubexpCall))
        #expect(custom.operators2.contains(.escCapitalNSuperDot))
    }
}
