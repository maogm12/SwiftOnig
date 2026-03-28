import Foundation
import OnigurumaC
import Testing
@testable import SwiftOnig

@OnigurumaActor
enum UpstreamOnigurumaSupport {
    enum SourceLiteralMode: Sendable {
        case utf8
        case rawSingleByteScalars
    }

    enum SearchDirection: Sendable {
        case forward
        case backward
    }

    enum RegexExpectation: Sendable {
        case match(range: Range<Int>, group: Int)
        case noMatch
        case error(OnigError)
    }

    struct RegexCase: Sendable {
        let suite: String
        let pattern: [UInt8]
        let input: [UInt8]
        let encoding: Encoding
        let syntax: Syntax?
        let compileOptions: Regex.Options
        let searchOptions: Regex.SearchOptions
        let direction: SearchDirection
        let expectation: RegexExpectation
    }

    enum RegsetInput: Sendable {
        case literal([UInt8])
        case fixture(String)
    }

    enum RegsetExpectation: Sendable {
        case match(range: Range<Int>, group: Int)
        case noMatch
    }

    struct RegsetCase: Sendable {
        let suite: String
        let patterns: [[UInt8]]
        let input: RegsetInput
        let lead: RegexSet.Lead
        let expectation: RegsetExpectation
    }

    static func verifyRegexSuite(_ cases: [RegexCase]) async {
        for (index, testCase) in cases.enumerated() {
            do {
                let regex = try Regex(patternBytes: testCase.pattern,
                                            encoding: testCase.encoding,
                                            options: testCase.compileOptions,
                                            syntax: testCase.syntax)

                let region: Region?
                switch testCase.direction {
                case .forward:
                    region = try regex.firstMatch(in: testCase.input, options: testCase.searchOptions)
                case .backward:
                    region = try backwardSearch(regex: regex, input: testCase.input)
                }

                switch testCase.expectation {
                case .match(let range, let group):
                    guard let region else {
                        Issue.record("Missing match for \(testCase.suite) case \(index): \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                        continue
                    }
                    if range.lowerBound < 0 && range.upperBound < 0 {
                        if region[group] != nil {
                            Issue.record("Expected inactive capture \(group) for \(testCase.suite) case \(index), but it participated: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                        }
                        continue
                    }
                    guard let subregion = region[group] else {
                        Issue.record("Missing capture \(group) for \(testCase.suite) case \(index): \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                        continue
                    }
                    if subregion.range != range {
                        Issue.record("Wrong range for \(testCase.suite) case \(index): expected \(range), got \(subregion.range) :: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                    }
                case .noMatch:
                    if region != nil {
                        Issue.record("Unexpected match for \(testCase.suite) case \(index): \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                    }
                case .error(let expectedError):
                    Issue.record("Expected error \(expectedError) for \(testCase.suite) case \(index), but regex/search succeeded: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                }
            } catch let error as OnigError {
                switch testCase.expectation {
                case .error(let expectedError):
                    if error != expectedError {
                        Issue.record("Wrong error for \(testCase.suite) case \(index): expected \(expectedError), got \(error) :: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                    }
                default:
                    Issue.record("Unexpected error for \(testCase.suite) case \(index): \(error) :: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
                }
            } catch {
                Issue.record("Non-OnigError failure for \(testCase.suite) case \(index): \(error) :: \(debugBytes(testCase.pattern)) :: \(debugBytes(testCase.input))")
            }
        }
    }

    static func verifyRegsetSuite(_ cases: [RegsetCase]) async {
        for (index, testCase) in cases.enumerated() {
            let inputBytes: [UInt8]
            switch testCase.input {
            case .literal(let bytes):
                inputBytes = bytes
            case .fixture(let name):
                guard let bytes = fixtureBytes(named: name) else {
                    continue
                }
                inputBytes = bytes
            }

            do {
                var regexes = [Regex]()
                regexes.reserveCapacity(testCase.patterns.count)
                for pattern in testCase.patterns {
                    regexes.append(try Regex(patternBytes: pattern, encoding: .utf8))
                }
                let regset = try await RegexSet(regexes: regexes)
                let result = try regset.firstSetMatch(in: inputBytes, lead: testCase.lead)

                switch testCase.expectation {
                case .match(let range, let group):
                    guard let result else {
                        Issue.record("Missing regset match for \(testCase.suite) case \(index)")
                        continue
                    }
                    guard let subregion = result.region[group] else {
                        Issue.record("Missing regset capture \(group) for \(testCase.suite) case \(index)")
                        continue
                    }
                    if subregion.range != range {
                        Issue.record("Wrong regset range for \(testCase.suite) case \(index): expected \(range), got \(subregion.range)")
                    }
                case .noMatch:
                    if result != nil {
                        Issue.record("Unexpected regset match for \(testCase.suite) case \(index)")
                    }
                }
            } catch {
                Issue.record("Regset failure for \(testCase.suite) case \(index): \(error)")
            }
        }
    }

    static func loadUTF8Suite() throws -> [RegexCase] {
        try parseMacroDrivenRegexSuite(fileName: "test_utf8.c",
                                       suiteName: "test_utf8.c",
                                       encoding: .utf8,
                                       compileOptions: .none,
                                       searchOptions: .none,
                                       syntax: nil,
                                       direction: .forward)
    }

    static func loadOptionsSuite() throws -> [RegexCase] {
        let source = try loadSource(named: "test_options.c")
        let mainBody = try extractFunctionBody(named: "main", from: source)
        return try extractCalls(in: mainBody, names: ["x2", "x3", "n"]).map { call in
            let optionExpression = call.arguments[0]
            let compileOptions = try regexOptions(from: optionExpression)
            let searchOptions = try searchOptions(from: optionExpression)

            switch call.name {
            case "x2":
                return RegexCase(suite: "test_options.c",
                                 pattern: try parseCStringBytes(from: call.arguments[1]),
                                 input: try parseCStringBytes(from: call.arguments[2]),
                                 encoding: .utf8,
                                 syntax: nil,
                                 compileOptions: compileOptions,
                                 searchOptions: searchOptions,
                                 direction: .forward,
                                 expectation: .match(range: try parseRange(lower: call.arguments[3], upper: call.arguments[4]), group: 0))
            case "x3":
                return RegexCase(suite: "test_options.c",
                                 pattern: try parseCStringBytes(from: call.arguments[1]),
                                 input: try parseCStringBytes(from: call.arguments[2]),
                                 encoding: .utf8,
                                 syntax: nil,
                                 compileOptions: compileOptions,
                                 searchOptions: searchOptions,
                                 direction: .forward,
                                 expectation: .match(range: try parseRange(lower: call.arguments[3], upper: call.arguments[4]),
                                                     group: try parseInt(call.arguments[5])))
            case "n":
                return RegexCase(suite: "test_options.c",
                                 pattern: try parseCStringBytes(from: call.arguments[1]),
                                 input: try parseCStringBytes(from: call.arguments[2]),
                                 encoding: .utf8,
                                 syntax: nil,
                                 compileOptions: compileOptions,
                                 searchOptions: searchOptions,
                                 direction: .forward,
                                 expectation: .noMatch)
            default:
                throw ParserError.unsupportedCall(call.name)
            }
        }
    }

    static func loadBackSuite() throws -> [RegexCase] {
        try parseMacroDrivenRegexSuite(fileName: "test_back.c",
                                       suiteName: "test_back.c",
                                       encoding: .utf8,
                                       compileOptions: .none,
                                       searchOptions: .none,
                                       syntax: nil,
                                       direction: .backward)
    }

    static func loadCTestSuite() throws -> [RegexCase] {
        try parseMacroDrivenRegexSuite(fileName: "testc.c",
                                       suiteName: "testc.c",
                                       encoding: .eucJP,
                                       compileOptions: .none,
                                       searchOptions: .none,
                                       syntax: nil,
                                       direction: .forward,
                                       sourceLiteralMode: .rawSingleByteScalars,
                                       supportsErrors: false)
    }

    static func loadUTF16Suite() throws -> [RegexCase] {
        try parseMacroDrivenRegexSuite(fileName: "testu.c",
                                       suiteName: "testu.c",
                                       encoding: .utf16BigEndian,
                                       compileOptions: .none,
                                       searchOptions: .none,
                                       syntax: nil,
                                       direction: .forward,
                                       supportsErrors: false).map {
            RegexCase(suite: $0.suite,
                      pattern: trimNullTerminator(in: $0.pattern, unitWidth: 2),
                      input: trimNullTerminator(in: $0.input, unitWidth: 2),
                      encoding: $0.encoding,
                      syntax: $0.syntax,
                      compileOptions: $0.compileOptions,
                      searchOptions: $0.searchOptions,
                      direction: $0.direction,
                      expectation: $0.expectation)
        }
    }

    static func loadSyntaxSuite() throws -> [RegexCase] {
        let source = try loadSource(named: "test_syntax.c")
        let helperNames = [
            "test_reluctant_interval",
            "test_possessive_interval",
            "test_isolated_option",
            "test_prec_read",
            "test_look_behind",
            "test_char_class",
            "test_python_option_ascii",
            "test_python_z",
            "test_python_single_multi",
            "test_BRE_anchors",
        ]

        var helperCalls = [String: [Call]]()
        for name in helperNames {
            let body = try extractFunctionBody(named: name, from: source)
            helperCalls[name] = try extractCalls(in: body, names: ["x2", "x3", "n", "e"])
        }

        let mainBody = try extractFunctionBody(named: "main", from: source)
        let events = try extractEvents(in: mainBody,
                                       calls: Set(helperNames + ["x2", "x3", "n", "e"]),
                                       assignments: ["Syntax"])

        var syntax: Syntax?
        var cases = [RegexCase]()

        for event in events {
            switch event {
            case .assignment(let name, let value):
                guard name == "Syntax" else { continue }
                syntax = try parseSyntax(from: value)
            case .call(let call):
                if let nested = helperCalls[call.name] {
                    for helperCall in nested {
                        cases.append(try regexCase(from: helperCall,
                                                   suiteName: "test_syntax.c",
                                                   encoding: .utf8,
                                                   compileOptions: .none,
                                                   searchOptions: .none,
                                                   syntax: syntax,
                                                   direction: .forward))
                    }
                } else {
                    cases.append(try regexCase(from: call,
                                               suiteName: "test_syntax.c",
                                               encoding: .utf8,
                                               compileOptions: .none,
                                               searchOptions: .none,
                                               syntax: syntax,
                                               direction: .forward))
                }
            }
        }

        return cases
    }

    static func loadRegsetSuite() throws -> [RegsetCase] {
        let source = try loadSource(named: "test_regset.c")
        let patternSets = try parsePatternArrays(from: source)
        let mainBody = try extractFunctionBody(named: "main", from: source)
        let events = try extractEvents(in: mainBody,
                                       calls: ["X2", "X3", "N", "NZERO"],
                                       assignments: ["XX_LEAD"])

        var lead: RegexSet.Lead = .positionLead
        var cases = [RegsetCase]()

        for event in events {
            switch event {
            case .assignment(let name, let value):
                guard name == "XX_LEAD" else { continue }
                lead = try parseRegsetLead(from: value)
            case .call(let call):
                switch call.name {
                case "NZERO":
                    cases.append(RegsetCase(suite: "test_regset.c",
                                            patterns: [],
                                            input: .literal(try parseCStringBytes(from: call.arguments[0])),
                                            lead: lead,
                                            expectation: .noMatch))
                case "N":
                    cases.append(RegsetCase(suite: "test_regset.c",
                                            patterns: try lookupPatternSet(named: call.arguments[0], in: patternSets),
                                            input: try parseRegsetInput(from: call.arguments[1]),
                                            lead: lead,
                                            expectation: .noMatch))
                case "X2":
                    cases.append(RegsetCase(suite: "test_regset.c",
                                            patterns: try lookupPatternSet(named: call.arguments[0], in: patternSets),
                                            input: try parseRegsetInput(from: call.arguments[1]),
                                            lead: lead,
                                            expectation: .match(range: try parseRange(lower: call.arguments[2], upper: call.arguments[3]), group: 0)))
                case "X3":
                    cases.append(RegsetCase(suite: "test_regset.c",
                                            patterns: try lookupPatternSet(named: call.arguments[0], in: patternSets),
                                            input: try parseRegsetInput(from: call.arguments[1]),
                                            lead: lead,
                                            expectation: .match(range: try parseRange(lower: call.arguments[2], upper: call.arguments[3]),
                                                                group: try parseInt(call.arguments[4]))))
                default:
                    throw ParserError.unsupportedCall(call.name)
                }
            }
        }

        return cases
    }

    private static func parseMacroDrivenRegexSuite(fileName: String,
                                                   suiteName: String,
                                                   encoding: Encoding,
                                                   compileOptions: Regex.Options,
                                                   searchOptions: Regex.SearchOptions,
                                                   syntax: Syntax?,
                                                   direction: SearchDirection,
                                                   sourceLiteralMode: SourceLiteralMode = .utf8,
                                                   supportsErrors: Bool = true) throws -> [RegexCase] {
        let source = try loadSource(named: fileName)
        let mainBody = try extractFunctionBody(named: "main", from: source)
        let callNames = supportsErrors ? ["x2", "x3", "n", "e"] : ["x2", "x3", "n"]
        return try extractCalls(in: mainBody, names: Set(callNames)).map {
            try regexCase(from: $0,
                          suiteName: suiteName,
                          encoding: encoding,
                          compileOptions: compileOptions,
                          searchOptions: searchOptions,
                          syntax: syntax,
                          direction: direction,
                          sourceLiteralMode: sourceLiteralMode)
        }
    }

    private static func regexCase(from call: Call,
                                  suiteName: String,
                                  encoding: Encoding,
                                  compileOptions: Regex.Options,
                                  searchOptions: Regex.SearchOptions,
                                  syntax: Syntax?,
                                  direction: SearchDirection,
                                  sourceLiteralMode: SourceLiteralMode = .utf8) throws -> RegexCase {
        switch call.name {
        case "x2":
            return RegexCase(suite: suiteName,
                             pattern: try parseCStringBytes(from: call.arguments[0], sourceLiteralMode: sourceLiteralMode),
                             input: try parseCStringBytes(from: call.arguments[1], sourceLiteralMode: sourceLiteralMode),
                             encoding: encoding,
                             syntax: syntax,
                             compileOptions: compileOptions,
                             searchOptions: searchOptions,
                             direction: direction,
                             expectation: .match(range: try parseRange(lower: call.arguments[2], upper: call.arguments[3]), group: 0))
        case "x3":
            return RegexCase(suite: suiteName,
                             pattern: try parseCStringBytes(from: call.arguments[0], sourceLiteralMode: sourceLiteralMode),
                             input: try parseCStringBytes(from: call.arguments[1], sourceLiteralMode: sourceLiteralMode),
                             encoding: encoding,
                             syntax: syntax,
                             compileOptions: compileOptions,
                             searchOptions: searchOptions,
                             direction: direction,
                             expectation: .match(range: try parseRange(lower: call.arguments[2], upper: call.arguments[3]),
                                                 group: try parseInt(call.arguments[4])))
        case "n":
            return RegexCase(suite: suiteName,
                             pattern: try parseCStringBytes(from: call.arguments[0], sourceLiteralMode: sourceLiteralMode),
                             input: try parseCStringBytes(from: call.arguments[1], sourceLiteralMode: sourceLiteralMode),
                             encoding: encoding,
                             syntax: syntax,
                             compileOptions: compileOptions,
                             searchOptions: searchOptions,
                             direction: direction,
                             expectation: .noMatch)
        case "e":
            return RegexCase(suite: suiteName,
                             pattern: try parseCStringBytes(from: call.arguments[0], sourceLiteralMode: sourceLiteralMode),
                             input: try parseCStringBytes(from: call.arguments[1], sourceLiteralMode: sourceLiteralMode),
                             encoding: encoding,
                             syntax: syntax,
                             compileOptions: compileOptions,
                             searchOptions: searchOptions,
                             direction: direction,
                             expectation: .error(try parseError(from: call.arguments[2])))
        default:
            throw ParserError.unsupportedCall(call.name)
        }
    }

    private static func backwardSearch(regex: Regex, input: [UInt8]) throws -> Region? {
        try input.withOnigurumaString(requestedEncoding: regex.encoding) { start, count throws -> Region? in
            let region = try Region(regex: regex, str: input)
            let result = try callOnigFunction {
                onig_search(regex.rawValue,
                            start,
                            start.advanced(by: count),
                            start.advanced(by: count),
                            start,
                            region.rawValue,
                            Regex.SearchOptions.none.rawValue)
            }

            if result == ONIG_MISMATCH {
                return nil
            }

            return region
        }
    }

    private static func fixtureBytes(named name: String) -> [UInt8]? {
        let url = repositoryRoot.appendingPathComponent(name)
        return try? Data(contentsOf: url).map { $0 }
    }

    private static func loadSource(named name: String) throws -> String {
        let url = repositoryRoot
            .appendingPathComponent("Vendor")
            .appendingPathComponent("Oniguruma")
            .appendingPathComponent("test")
            .appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        throw ParserError.invalidSyntax("Unable to decode \(name)")
    }

    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static func parsePatternArrays(from source: String) throws -> [String: [[UInt8]]] {
        var result = [String: [[UInt8]]]()
        let chars = Array(source)
        var index = 0

        while index < chars.count {
            if sourceMatches(chars, at: index, token: "static char*") {
                index += "static char*".count
                skipTrivia(chars, &index)
                let name = parseIdentifier(chars, &index)
                skipTrivia(chars, &index)
                guard index < chars.count, chars[index] == "[" else {
                    continue
                }
                while index < chars.count, chars[index] != "{" {
                    index += 1
                }
                guard index < chars.count else { break }
                let block = try extractDelimited(chars, &index, open: "{", close: "}")
                result[name] = try extractStringLiterals(from: block).map { try parseCStringBytes(from: $0) }
            } else {
                index += 1
            }
        }

        return result
    }

    private static func extractStringLiterals(from text: String) throws -> [String] {
        let chars = Array(text)
        var index = 0
        var result = [String]()

        while index < chars.count {
            if chars[index] == "\"" {
                let start = index
                index += 1
                while index < chars.count {
                    if chars[index] == "\\" {
                        index += 2
                        continue
                    }
                    if chars[index] == "\"" {
                        index += 1
                        break
                    }
                    index += 1
                }
                result.append(String(chars[start..<index]))
            } else {
                index += 1
            }
        }

        return result
    }

    private static func extractFunctionBody(named name: String, from source: String) throws -> String {
        guard let range = source.range(of: "\(name)(") else {
            throw ParserError.missingFunction(name)
        }
        let chars = Array(source)
        let startOffset = source.distance(from: source.startIndex, to: range.lowerBound)
        var index = startOffset
        while index < chars.count, chars[index] != "{" {
            index += 1
        }
        guard index < chars.count else {
            throw ParserError.missingFunction(name)
        }
        return try extractDelimited(chars, &index, open: "{", close: "}")
    }

    private static func extractCalls(in body: String, names: Set<String>) throws -> [Call] {
        try extractEvents(in: body, calls: names, assignments: []).compactMap {
            if case .call(let call) = $0 { return call }
            return nil
        }
    }

    private static func extractEvents(in body: String,
                                      calls: Set<String>,
                                      assignments: Set<String>) throws -> [BodyEvent] {
        let chars = Array(body)
        var index = 0
        var events = [BodyEvent]()

        while index < chars.count {
            if skipComment(chars, &index) {
                continue
            }

            if isIdentifierStart(chars[index]) {
                let name = parseIdentifier(chars, &index)
                var probe = index
                skipTrivia(chars, &probe)

                if calls.contains(name), probe < chars.count, chars[probe] == "(" {
                    index = probe
                    let arguments = try parseArgumentList(chars, &index)
                    events.append(.call(Call(name: name, arguments: arguments)))
                    continue
                }

                if assignments.contains(name), probe < chars.count, chars[probe] == "=" {
                    index = probe + 1
                    let value = try parseUntilSemicolon(chars, &index)
                    events.append(.assignment(name: name, value: value))
                    continue
                }
            }

            index += 1
        }

        return events
    }

    private static func parseArgumentList(_ chars: [Character], _ index: inout Int) throws -> [String] {
        let content = try extractDelimited(chars, &index, open: "(", close: ")")
        return splitTopLevelArguments(content)
    }

    private static func splitTopLevelArguments(_ content: String) -> [String] {
        let chars = Array(content)
        var depth = 0
        var index = 0
        var start = 0
        var inString = false
        var escaped = false
        var arguments = [String]()

        while index < chars.count {
            let char = chars[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                index += 1
                continue
            }

            switch char {
            case "\"":
                inString = true
            case "(":
                depth += 1
            case ")":
                depth -= 1
            case "," where depth == 0:
                arguments.append(String(chars[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines))
                start = index + 1
            default:
                break
            }

            index += 1
        }

        if start < chars.count {
            arguments.append(String(chars[start..<chars.count]).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return arguments
    }

    private static func parseUntilSemicolon(_ chars: [Character], _ index: inout Int) throws -> String {
        let start = index
        var depth = 0
        var inString = false
        var escaped = false

        while index < chars.count {
            let char = chars[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                index += 1
                continue
            }

            if skipComment(chars, &index) {
                continue
            }

            switch char {
            case "\"":
                inString = true
            case "(":
                depth += 1
            case ")":
                depth -= 1
            case ";" where depth == 0:
                let value = String(chars[start..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
                index += 1
                return value
            default:
                break
            }

            index += 1
        }

        throw ParserError.invalidSyntax("Missing semicolon")
    }

    private static func extractDelimited(_ chars: [Character],
                                         _ index: inout Int,
                                         open: Character,
                                         close: Character) throws -> String {
        guard index < chars.count, chars[index] == open else {
            throw ParserError.invalidSyntax("Expected \(open)")
        }

        let start = index + 1
        index += 1
        var depth = 1
        var inString = false
        var escaped = false

        while index < chars.count {
            let char = chars[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
                index += 1
                continue
            }

            if skipComment(chars, &index) {
                continue
            }

            if char == "\"" {
                inString = true
            } else if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
                if depth == 0 {
                    let result = String(chars[start..<index])
                    index += 1
                    return result
                }
            }

            index += 1
        }

        throw ParserError.invalidSyntax("Unterminated \(open)\(close) block")
    }

    private static func parseCStringBytes(from expression: String,
                                          sourceLiteralMode: SourceLiteralMode = .utf8) throws -> [UInt8] {
        let chars = Array(expression.trimmingCharacters(in: .whitespacesAndNewlines))
        var index = 0
        var bytes = [UInt8]()

        while index < chars.count {
            skipTrivia(chars, &index)
            guard index < chars.count else { break }
            guard chars[index] == "\"" else {
                throw ParserError.invalidCString(expression)
            }
            index += 1

            while index < chars.count {
                let char = chars[index]
                if char == "\"" {
                    index += 1
                    break
                }

                if char != "\\" {
                    appendSourceCharacterBytes(char, to: &bytes, sourceLiteralMode: sourceLiteralMode)
                    index += 1
                    continue
                }

                index += 1
                guard index < chars.count else {
                    throw ParserError.invalidCString(expression)
                }

                let escaped = chars[index]
                switch escaped {
                case "a":
                    bytes.append(0x07)
                    index += 1
                case "b":
                    bytes.append(0x08)
                    index += 1
                case "f":
                    bytes.append(0x0C)
                    index += 1
                case "n":
                    bytes.append(0x0A)
                    index += 1
                case "r":
                    bytes.append(0x0D)
                    index += 1
                case "t":
                    bytes.append(0x09)
                    index += 1
                case "v":
                    bytes.append(0x0B)
                    index += 1
                case "\\":
                    bytes.append(UInt8(ascii: "\\"))
                    index += 1
                case "\"":
                    bytes.append(UInt8(ascii: "\""))
                    index += 1
                case "'":
                    bytes.append(UInt8(ascii: "'"))
                    index += 1
                case "?":
                    bytes.append(UInt8(ascii: "?"))
                    index += 1
                case "x":
                    index += 1
                    var hex = ""
                    while index < chars.count, chars[index].isHexDigit {
                        hex.append(chars[index])
                        index += 1
                    }
                    guard let value = UInt8(hex, radix: 16) else {
                        throw ParserError.invalidCString(expression)
                    }
                    bytes.append(value)
                case "0"..."7":
                    var octal = String(escaped)
                    index += 1
                    var consumed = 1
                    while index < chars.count, consumed < 3, chars[index].isOctalDigit {
                        octal.append(chars[index])
                        consumed += 1
                        index += 1
                    }
                    guard let value = UInt8(octal, radix: 8) else {
                        throw ParserError.invalidCString(expression)
                    }
                    bytes.append(value)
                default:
                    bytes.append(UInt8(ascii: "\\"))
                    appendSourceCharacterBytes(escaped, to: &bytes, sourceLiteralMode: sourceLiteralMode)
                    index += 1
                }
            }
        }

        return bytes
    }

    private static func parseRange(lower: String, upper: String) throws -> Range<Int> {
        try parseInt(lower)..<parseInt(upper)
    }

    private static func parseInt(_ value: String) throws -> Int {
        guard let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ParserError.invalidInteger(value)
        }
        return number
    }

    private static func regexOptions(from expression: String) throws -> Regex.Options {
        try optionTokens(from: expression).reduce(into: Regex.Options.none) { result, token in
            switch token {
            case "ONIG_OPTION_NONE":
                break
            case "ONIG_OPTION_IGNORECASE":
                result.insert(.ignoreCase)
            case "ONIG_OPTION_IGNORECASE_IS_ASCII":
                result.insert(.ignoreCaseIsASCII)
            case "ONIG_OPTION_EXTEND":
                result.insert(.extend)
            case "ONIG_OPTION_MULTILINE":
                result.insert(.multiLine)
            case "ONIG_OPTION_SINGLELINE":
                result.insert(.singleLine)
            case "ONIG_OPTION_FIND_LONGEST":
                result.insert(.findLongest)
            case "ONIG_OPTION_FIND_NOT_EMPTY":
                result.insert(.findNotEmpty)
            case "ONIG_OPTION_WORD_IS_ASCII":
                result.insert(.wordIsASCII)
            case "ONIG_OPTION_DIGIT_IS_ASCII":
                result.insert(.digitIsASCII)
            case "ONIG_OPTION_SPACE_IS_ASCII":
                result.insert(.spaceIsASCII)
            case "ONIG_OPTION_POSIX_IS_ASCII":
                result.insert(.posixIsASCII)
            case "ONIG_OPTION_MATCH_WHOLE_STRING":
                break
            case "ONIG_OPTION_NOTBOL", "ONIG_OPTION_NOTEOL", "ONIG_OPTION_NOT_BEGIN_STRING", "ONIG_OPTION_NOT_END_STRING":
                break
            default:
                throw ParserError.invalidOptionExpression(expression)
            }
        }
    }

    private static func searchOptions(from expression: String) throws -> Regex.SearchOptions {
        try optionTokens(from: expression).reduce(into: Regex.SearchOptions.none) { result, token in
            switch token {
            case "ONIG_OPTION_NONE":
                break
            case "ONIG_OPTION_NOTBOL":
                result.insert(.notBol)
            case "ONIG_OPTION_NOTEOL":
                result.insert(.notEol)
            case "ONIG_OPTION_NOT_BEGIN_STRING":
                result.insert(.notBeginString)
            case "ONIG_OPTION_NOT_END_STRING":
                result.insert(.notEndString)
            case "ONIG_OPTION_MATCH_WHOLE_STRING":
                result.insert(.matchWholeString)
            case "ONIG_OPTION_IGNORECASE", "ONIG_OPTION_IGNORECASE_IS_ASCII", "ONIG_OPTION_EXTEND",
                 "ONIG_OPTION_MULTILINE", "ONIG_OPTION_SINGLELINE", "ONIG_OPTION_FIND_LONGEST",
                 "ONIG_OPTION_FIND_NOT_EMPTY", "ONIG_OPTION_WORD_IS_ASCII", "ONIG_OPTION_DIGIT_IS_ASCII",
                 "ONIG_OPTION_SPACE_IS_ASCII", "ONIG_OPTION_POSIX_IS_ASCII":
                break
            default:
                throw ParserError.invalidOptionExpression(expression)
            }
        }
    }

    private static func optionTokens(from expression: String) throws -> [String] {
        let normalized = expression.replacingOccurrences(of: "OIA",
                                                         with: "ONIG_OPTION_IGNORECASE | ONIG_OPTION_IGNORECASE_IS_ASCII")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return normalized
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func parseSyntax(from expression: String) throws -> Syntax {
        switch expression.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ONIG_SYNTAX_PERL":
            return Syntax.perl
        case "ONIG_SYNTAX_JAVA":
            return Syntax.java
        case "ONIG_SYNTAX_PYTHON":
            return Syntax.python
        case "ONIG_SYNTAX_POSIX_BASIC":
            return Syntax.posixBasic
        case "ONIG_SYNTAX_GREP":
            return Syntax.grep
        case "ONIG_SYNTAX_EMACS":
            return Syntax.emacs
        case "ONIG_SYNTAX_PERL_NG":
            return Syntax.perlNg
        default:
            throw ParserError.invalidSyntax(expression)
        }
    }

    private static func parseRegsetLead(from expression: String) throws -> RegexSet.Lead {
        switch expression.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ONIG_REGSET_POSITION_LEAD":
            return .positionLead
        case "ONIG_REGSET_REGEX_LEAD":
            return .regexLead
        default:
            throw ParserError.invalidSyntax(expression)
        }
    }

    private static func parseError(from expression: String) throws -> OnigError {
        switch expression.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "ONIGERR_END_PATTERN_WITH_UNMATCHED_PARENTHESIS":
            return .endPatternWithUnmatchedParenthesis
        case "ONIGERR_INVALID_BACKREF":
            return .invalidBackref
        case "ONIGERR_INVALID_CODE_POINT_VALUE":
            return .invalidCodePointValue
        case "ONIGERR_INVALID_GROUP_OPTION":
            return .invalidGroupOption
        case "ONIGERR_INVALID_LOOK_BEHIND_PATTERN":
            return .invalidLookBehindPattern
        case "ONIGERR_INVALID_POSIX_BRACKET_TYPE":
            return .invalidPosixBracketType
        case "ONIGERR_NEVER_ENDING_RECURSION":
            return .neverEndingRecursion
        case "ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED":
            return .numberedBackrefOrCallNotAllowed
        case "ONIGERR_PREMATURE_END_OF_CHAR_CLASS":
            return .prematureEndOfCharClass
        case "ONIGERR_TARGET_OF_REPEAT_OPERATOR_INVALID":
            return .targetOfRepeatOperatorInvalid
        case "ONIGERR_TARGET_OF_REPEAT_OPERATOR_NOT_SPECIFIED":
            return .targetOfRepeatOperatorNotSpecified
        case "ONIGERR_TOO_BIG_NUMBER_FOR_REPEAT_RANGE":
            return .tooBigNumberForRepeatRange
        case "ONIGERR_TOO_BIG_WIDE_CHAR_VALUE":
            return .tooBigWideCharValue
        case "ONIGERR_TOO_LONG_WIDE_CHAR_VALUE":
            return .tooLongWideCharValue
        case "ONIGERR_UNDEFINED_CALLOUT_NAME":
            return .undefinedCalloutName
        case "ONIGERR_UNDEFINED_OPERATOR":
            return .undefinedOperator
        case "ONIGERR_UNMATCHED_RANGE_SPECIFIER_IN_CHAR_CLASS":
            return .unmatchedRangeSpecifierInCharClass
        default:
            throw ParserError.invalidError(expression)
        }
    }

    private static func lookupPatternSet(named name: String, in sets: [String: [[UInt8]]]) throws -> [[UInt8]] {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let patterns = sets[key] else {
            throw ParserError.missingPatternSet(key)
        }
        return patterns
    }

    private static func parseRegsetInput(from expression: String) throws -> RegsetInput {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\"") {
            return .literal(try parseCStringBytes(from: trimmed))
        }
        if trimmed == "s" {
            return .fixture("kofu-utf8.txt")
        }
        throw ParserError.invalidSyntax(expression)
    }

    private static func trimNullTerminator(in bytes: [UInt8], unitWidth: Int) -> [UInt8] {
        guard bytes.count >= unitWidth else {
            return bytes
        }
        if bytes.suffix(unitWidth).allSatisfy({ $0 == 0 }) {
            return Array(bytes.dropLast(unitWidth))
        }
        return bytes
    }

    private static func debugBytes(_ bytes: [UInt8]) -> String {
        if let string = String(bytes: bytes, encoding: .utf8),
           string.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t" }) {
            return string
        }
        return bytes.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private static func appendSourceCharacterBytes(_ character: Character,
                                                   to bytes: inout [UInt8],
                                                   sourceLiteralMode: SourceLiteralMode) {
        for scalar in String(character).unicodeScalars {
            if sourceLiteralMode == .rawSingleByteScalars, scalar.value <= 0xFF {
                bytes.append(UInt8(scalar.value))
            } else {
                bytes.append(contentsOf: String(scalar).utf8)
            }
        }
    }

    private static func sourceMatches(_ chars: [Character], at index: Int, token: String) -> Bool {
        guard index + token.count <= chars.count else { return false }
        return String(chars[index..<(index + token.count)]) == token
    }

    private static func parseIdentifier(_ chars: [Character], _ index: inout Int) -> String {
        let start = index
        while index < chars.count, isIdentifierContinue(chars[index]) {
            index += 1
        }
        return String(chars[start..<index])
    }

    private static func skipTrivia(_ chars: [Character], _ index: inout Int) {
        while index < chars.count, chars[index].isWhitespace {
            index += 1
        }
    }

    private static func skipComment(_ chars: [Character], _ index: inout Int) -> Bool {
        guard index + 1 < chars.count, chars[index] == "/" else {
            return false
        }

        if chars[index + 1] == "/" {
            index += 2
            while index < chars.count, chars[index] != "\n" {
                index += 1
            }
            return true
        }

        if chars[index + 1] == "*" {
            index += 2
            while index + 1 < chars.count {
                if chars[index] == "*", chars[index + 1] == "/" {
                    index += 2
                    return true
                }
                index += 1
            }
            return true
        }

        return false
    }

    private static func isIdentifierStart(_ char: Character) -> Bool {
        char == "_" || char.isLetter
    }

    private static func isIdentifierContinue(_ char: Character) -> Bool {
        isIdentifierStart(char) || char.isNumber
    }

    private enum BodyEvent {
        case assignment(name: String, value: String)
        case call(Call)
    }

    private struct Call: Sendable {
        let name: String
        let arguments: [String]
    }

    enum ParserError: Error {
        case missingFunction(String)
        case unsupportedCall(String)
        case invalidCString(String)
        case invalidInteger(String)
        case invalidError(String)
        case invalidOptionExpression(String)
        case invalidSyntax(String)
        case missingPatternSet(String)
    }
}

private extension Character {
    var isHexDigit: Bool {
        ("0"..."9").contains(self) || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self)
    }

    var isOctalDigit: Bool {
        ("0"..."7").contains(self)
    }
}
