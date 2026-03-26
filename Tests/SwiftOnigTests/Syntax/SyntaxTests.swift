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
        #expect(await syntax.operators.contains(.escCapitalGBeginAnchor))

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

    @Test("Python syntax preset and additional flags")
    func pythonSyntax() async throws {
        @OnigurumaActor
        func configureAdditionalFlags(on syntax: Syntax) {
            var operators2 = syntax.operators2
            operators2.insert(.qmarkLtNamedGroup)
            operators2.insert(.escPBraceCircumflexNot)
            operators2.insert(.escGSubexpCall)
            operators2.insert(.escCapitalNSuperDot)
            syntax.operators2 = operators2
        }

        let python = await Syntax.python
        #expect(await python.operators.contains(.escCapitalGBeginAnchor))

        let regex = try await Regex(pattern: #"(?P<word>\w+)(?P=word)"#, syntax: python)
        #expect(try await regex.matches("hellohello"))
        #expect(try await !regex.matches("helloworld"))

        let custom = await Syntax(copying: Syntax.default)
        await configureAdditionalFlags(on: custom)
        #expect(await custom.operators2.contains(.qmarkLtNamedGroup))
        #expect(await custom.operators2.contains(.escPBraceCircumflexNot))
        #expect(await custom.operators2.contains(.escGSubexpCall))
        #expect(await custom.operators2.contains(.escCapitalNSuperDot))
    }
}
