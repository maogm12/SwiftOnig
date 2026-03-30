//
//  Syntax.swift
//  
//
//  Created by Guangming Mao on 4/4/21.
//

import OnigurumaC

/// A value snapshot of an Oniguruma regex syntax configuration.
///
/// `Syntax` controls how patterns are parsed during compilation. Most applications should use one
/// of the predefined presets such as `Syntax.default`, `Syntax.ruby`, or `Syntax.python`.
public struct Syntax: Sendable {
    private var rawSyntax: OnigSyntaxType

    private init(rawSyntax: OnigSyntaxType) {
        self.rawSyntax = rawSyntax
    }

    /// Creates a new mutable syntax value by copying an existing syntax snapshot.
    public init(copying other: Syntax) {
        self.rawSyntax = other.rawSyntax
    }

    private static func snapshot(_ rawValue: UnsafeMutablePointer<OnigSyntaxType>) -> Syntax {
        Syntax(rawSyntax: rawValue.pointee)
    }

    /// Built-in syntax presets provided by Oniguruma.
    public static var asis: Syntax { snapshot(OnigCGlobals.asis) }
    public static var posixBasic: Syntax { snapshot(OnigCGlobals.posixBasic) }
    public static var posixExtended: Syntax { snapshot(OnigCGlobals.posixExtended) }
    public static var emacs: Syntax { snapshot(OnigCGlobals.emacs) }
    public static var grep: Syntax { snapshot(OnigCGlobals.grep) }
    public static var gnuRegex: Syntax { snapshot(OnigCGlobals.gnuRegex) }
    public static var java: Syntax { snapshot(OnigCGlobals.java) }
    public static var perl: Syntax { snapshot(OnigCGlobals.perl) }
    public static var perlNg: Syntax { snapshot(OnigCGlobals.perlNg) }
    public static var python: Syntax { snapshot(OnigCGlobals.python) }
    public static var ruby: Syntax { snapshot(OnigCGlobals.ruby) }
    public static var oniguruma: Syntax { snapshot(OnigCGlobals.oniguruma) }
    public static var `default`: Syntax { snapshot(OnigCGlobals.defaultSyntax) }

    internal func allocateRawValueCopy() -> UnsafeMutablePointer<OnigSyntaxType> {
        let pointer = UnsafeMutablePointer<OnigSyntaxType>.allocate(capacity: 1)
        pointer.initialize(to: rawSyntax)
        return pointer
    }

    internal nonisolated func withRawValue<Result>(_ body: (UnsafeMutablePointer<OnigSyntaxType>) throws -> Result) rethrows -> Result {
        let pointer = allocateRawValueCopy()
        defer {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
        return try body(pointer)
    }

    /// The first set of syntax operators enabled for this syntax.
    public var operators: Operators {
        get {
            Operators(rawValue: UInt64(rawSyntax.op))
        }

        set {
            rawSyntax.op = UInt32(newValue.rawValue)
        }
    }

    /// The second set of syntax operators enabled for this syntax.
    public var operators2: Operators2 {
        get {
            Operators2(rawValue: UInt64(rawSyntax.op2))
        }

        set {
            rawSyntax.op2 = UInt32(newValue.rawValue)
        }
    }

    /// The default compile-time regex options attached to this syntax.
    public var options: Regex.Options {
        get {
            Regex.Options(rawValue: rawSyntax.options)
        }

        set {
            rawSyntax.options = newValue.rawValue
        }
    }

    /// Additional parser and behavior toggles attached to this syntax.
    public var behaviors: Behaviors {
        get {
            Behaviors(rawValue: rawSyntax.behavior)
        }

        set {
            rawSyntax.behavior = newValue.rawValue
        }
    }
}

extension Syntax {
    /// Primary syntax operator flags defined by Oniguruma.
    public struct Operators: OptionSet, Sendable {
        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        public static let variableMetaCharacters = Operators(rawValue: UInt64(ONIG_SYN_OP_VARIABLE_META_CHARACTERS))
        public static let dotAnyChar = Operators(rawValue: UInt64(ONIG_SYN_OP_DOT_ANYCHAR))
        public static let asteriskZeroOrMore = Operators(rawValue: UInt64(ONIG_SYN_OP_ASTERISK_ZERO_INF))
        public static let escAsteriskZeroOrMore = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_ASTERISK_ZERO_INF))
        public static let plusOneOrMore = Operators(rawValue: UInt64(ONIG_SYN_OP_PLUS_ONE_INF))
        public static let escPlusOneOrMore = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_PLUS_ONE_INF))
        public static let questionOneOrZero = Operators(rawValue: UInt64(ONIG_SYN_OP_QMARK_ZERO_ONE))
        public static let escQuestionOneOrZero = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_QMARK_ZERO_ONE))
        public static let braceInterval = Operators(rawValue: UInt64(ONIG_SYN_OP_BRACE_INTERVAL))
        public static let escBraceInterval = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_BRACE_INTERVAL))
        public static let vbarAlt = Operators(rawValue: UInt64(ONIG_SYN_OP_VBAR_ALT))
        public static let escVbarAlt = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_VBAR_ALT))
        public static let lparenSubexp = Operators(rawValue: UInt64(ONIG_SYN_OP_LPAREN_SUBEXP))
        public static let escLparenSubexp = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LPAREN_SUBEXP))
        public static let escAzBufAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR))
        public static let escCapitalGBeginAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CAPITAL_G_BEGIN_ANCHOR))
        public static let escWWord = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_W_WORD))
        public static let escLtGtWordBeginEnd = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END))
        public static let escBWordBound = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_B_WORD_BOUND))
        public static let escSWhiteSpace = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_S_WHITE_SPACE))
        public static let escDDigit = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_D_DIGIT))
        public static let lineAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_LINE_ANCHOR))
        public static let posixBracket = Operators(rawValue: UInt64(ONIG_SYN_OP_POSIX_BRACKET))
        public static let qmarkNonGreedy = Operators(rawValue: UInt64(ONIG_SYN_OP_QMARK_NON_GREEDY))
        public static let escControlChars = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CONTROL_CHARS))
        public static let decimalBackref = Operators(rawValue: UInt64(ONIG_SYN_OP_DECIMAL_BACKREF))
        public static let bracketAnycharHyphen = Operators(rawValue: UInt64(ONIG_SYN_OP_BRACKET_CC))
        public static let escOctal3 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_OCTAL3))
        public static let escXHex2 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_HEX2))
        public static let escXBraceHex8 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_BRACE_HEX8))
        public static let escOBraceOctal = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_O_BRACE_OCTAL))
    }

    /// Secondary syntax operator flags defined by Oniguruma.
    public struct Operators2: OptionSet, Sendable {
        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        public static let escCapitalQQuote = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_Q_QUOTE))
        public static let qmarkGroupEffect = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_GROUP_EFFECT))
        public static let optionPerl = Operators2(rawValue: UInt64(ONIG_SYN_OP2_OPTION_PERL))
        public static let optionRuby = Operators2(rawValue: UInt64(ONIG_SYN_OP2_OPTION_RUBY))
        public static let plusPossessiveRepeat = Operators2(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_REPEAT))
        public static let plusPossessiveInterval = Operators2(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL))
        public static let qmarkLtNamedGroup = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP))
        public static let escCapitalUHex4 = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_U_HEX4))
        public static let escVVerticalTab = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_V_VTAB))
        public static let escHHorizontalTab = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_H_XDIGIT))
        public static let escPBraceCircumflexNot = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT))
        public static let escCapitalKKeep = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_K_NAMED_BACKREF))
        public static let escGSubexpCall = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_G_SUBEXP_CALL))
        public static let escCapitalRLinebreak = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE))
        public static let escCapitalNSuperDot = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT))
        public static let escCapitalXExtendedGraphemeCluster = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT))
        public static let qmarkLparenCondition = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE))
        public static let qmarkBraceCallout = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS))
        public static let asteriskBraceCallout = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY))
    }

    /// Behavior toggles that further refine parser semantics for a syntax.
    public struct Behaviors: OptionSet, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let contextIndepAnchors = Behaviors(rawValue: ONIG_SYN_CONTEXT_INDEP_ANCHORS)
        public static let contextIndepRepeatOps = Behaviors(rawValue: ONIG_SYN_CONTEXT_INDEP_REPEAT_OPS)
        public static let contextInvalidRepeatOps = Behaviors(rawValue: ONIG_SYN_CONTEXT_INVALID_REPEAT_OPS)
        public static let allowUnmatchedCloseSubexp = Behaviors(rawValue: ONIG_SYN_ALLOW_UNMATCHED_CLOSE_SUBEXP)
        public static let allowInvalidInterval = Behaviors(rawValue: ONIG_SYN_ALLOW_INVALID_INTERVAL)
        public static let allowIntervalLowAbbrev = Behaviors(rawValue: ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV)
        public static let strictCheckBackref = Behaviors(rawValue: ONIG_SYN_STRICT_CHECK_BACKREF)
        public static let differentLengthAltLookBehind = Behaviors(rawValue: ONIG_SYN_DIFFERENT_LEN_ALT_LOOK_BEHIND)
        public static let captureOnlyNamedGroup = Behaviors(rawValue: ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)
        public static let allowMultiplexDefinitionName = Behaviors(rawValue: ONIG_SYN_ALLOW_MULTIPLEX_DEFINITION_NAME)
        public static let fixedIntervalIsGreedyOnly = Behaviors(rawValue: ONIG_SYN_FIXED_INTERVAL_IS_GREEDY_ONLY)
        public static let allowEmptyRangeInCc = Behaviors(rawValue: ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC)
        public static let backslashEscapeInCC = Behaviors(rawValue: ONIG_SYN_BACKSLASH_ESCAPE_IN_CC)
        public static let allowDoubleRangeOpInCC = Behaviors(rawValue: ONIG_SYN_ALLOW_DOUBLE_RANGE_OP_IN_CC)
        public static let warnCCOpNotEscaped = Behaviors(rawValue: ONIG_SYN_WARN_CC_OP_NOT_ESCAPED)
        public static let warnRedundantNestedRepeat = Behaviors(rawValue: ONIG_SYN_WARN_REDUNDANT_NESTED_REPEAT)
    }
}

extension Syntax {
    public enum MetaCharIndex: Int, Sendable, CaseIterable {
        case Escape = 0
        case AnyChar = 1
        case AnyTime = 2
        case ZeroOrOne = 3
        case OneOrMore = 4
        case AnyCharAnytime = 5
    }

    /// A configurable meta-character entry inside a syntax's meta-character table.
    public enum MetaChar: Sendable {
        case Ineffective
        case CodePoint(OnigCodePoint)
        
        public var description: String {
            switch self {
            case .Ineffective:
                return ""
            case .CodePoint(let codePoint):
                var cp = codePoint
                let count = codePoint > 0xFFFFFF ? 4 : (codePoint > 0xFFFF ? 3 : (codePoint > 0xFF ? 2 : 1))
                return withUnsafeBytes(of: &cp) { buf in
                    let bytes = buf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
                }
            }
        }
    }

    /// The configurable meta-character table for a syntax.
    public struct MetaCharTable: Sendable {
        fileprivate var rawValue: OnigMetaCharTableType

        public subscript(index: MetaCharIndex) -> MetaChar {
            get {
                let codePoint: OnigCodePoint
                switch index {
                case .Escape: codePoint = rawValue.esc
                case .AnyChar: codePoint = rawValue.anychar
                case .AnyTime: codePoint = rawValue.anytime
                case .ZeroOrOne: codePoint = rawValue.zero_or_one_time
                case .OneOrMore: codePoint = rawValue.one_or_more_time
                case .AnyCharAnytime: codePoint = rawValue.anychar_anytime
                }

                if codePoint == OnigCodePoint(ONIG_INEFFECTIVE_META_CHAR) {
                    return .Ineffective
                } else {
                    return .CodePoint(codePoint)
                }
            }

            set {
                let codePoint: OnigCodePoint
                switch newValue {
                case .Ineffective:
                    codePoint = OnigCodePoint(bitPattern: Int32(ONIG_INEFFECTIVE_META_CHAR))
                case .CodePoint(let cp):
                    codePoint = cp
                }

                switch index {
                case .Escape: rawValue.esc = codePoint
                case .AnyChar: rawValue.anychar = codePoint
                case .AnyTime: rawValue.anytime = codePoint
                case .ZeroOrOne: rawValue.zero_or_one_time = codePoint
                case .OneOrMore: rawValue.one_or_more_time = codePoint
                case .AnyCharAnytime: rawValue.anychar_anytime = codePoint
                }
            }
        }
    }

    public var metaCharTable: MetaCharTable {
        get {
            MetaCharTable(rawValue: rawSyntax.meta_char_table)
        }
        set {
            rawSyntax.meta_char_table = newValue.rawValue
        }
    }
}
