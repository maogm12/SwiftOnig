//
//  Syntax.swift
//  
//
//  Created by Guangming Mao on 4/4/21.
//

import OnigurumaC

/**
 A wrapper of oniguruma `OnigSyntaxType`.
 
 In `SwiftOnig`, `Syntax` is mutable but isolated by `@OnigurumaActor`.
 
 For most users, there's no need to create a `Syntax` object, but using the static predefined syntax objects is recommended.
 */
@OnigurumaActor
final public class Syntax: Sendable {
    private enum Ownership: Equatable {
        case borrowedPreset
        case ownedCopy
    }

    internal nonisolated(unsafe) var rawValue: UnsafeMutablePointer<OnigSyntaxType>
    private var ownership: Ownership

    private init(rawValue: UnsafeMutablePointer<OnigSyntaxType>, ownership: Ownership) {
        self.rawValue = rawValue
        self.ownership = ownership
    }

    /**
     Create a new syntax object by copying from an existing syntax.
     - Parameter other: The syntax to copy from.
     */
    public init(copying other: Syntax) {
        let rawValue = UnsafeMutablePointer<OnigSyntaxType>.allocate(capacity: 1)
        onig_copy_syntax(rawValue, other.rawValue)
        self.rawValue = rawValue
        self.ownership = .ownedCopy
    }

    deinit {
        if ownership == .ownedCopy {
            rawValue.deallocate()
        }
    }

    /**
     Predefined syntax objects
     */
    public static var asis: Syntax { Syntax(rawValue: OnigCGlobals.asis, ownership: .borrowedPreset) }
    public static var posixBasic: Syntax { Syntax(rawValue: OnigCGlobals.posixBasic, ownership: .borrowedPreset) }
    public static var posixExtended: Syntax { Syntax(rawValue: OnigCGlobals.posixExtended, ownership: .borrowedPreset) }
    public static var emacs: Syntax { Syntax(rawValue: OnigCGlobals.emacs, ownership: .borrowedPreset) }
    public static var grep: Syntax { Syntax(rawValue: OnigCGlobals.grep, ownership: .borrowedPreset) }
    public static var gnuRegex: Syntax { Syntax(rawValue: OnigCGlobals.gnuRegex, ownership: .borrowedPreset) }
    public static var java: Syntax { Syntax(rawValue: OnigCGlobals.java, ownership: .borrowedPreset) }
    public static var perl: Syntax { Syntax(rawValue: OnigCGlobals.perl, ownership: .borrowedPreset) }
    public static var perlNg: Syntax { Syntax(rawValue: OnigCGlobals.perlNg, ownership: .borrowedPreset) }
    public static var ruby: Syntax { Syntax(rawValue: OnigCGlobals.ruby, ownership: .borrowedPreset) }
    public static var oniguruma: Syntax { Syntax(rawValue: OnigCGlobals.oniguruma, ownership: .borrowedPreset) }
    public static var `default`: Syntax { Syntax(rawValue: OnigCGlobals.defaultSyntax, ownership: .borrowedPreset) }

    /**
     Convert the syntax to an owned one if it's not. 
     Predefined syntax objects should not be modified directly.
     */
    internal func convertToOwnedIfNeeded() {
        if ownership == .borrowedPreset {
            let newRawValue = UnsafeMutablePointer<OnigSyntaxType>.allocate(capacity: 1)
            onig_copy_syntax(newRawValue, rawValue)
            self.rawValue = newRawValue
            self.ownership = .ownedCopy
        }
    }

    /**
     Syntax operators.
     */
    public var operators: Operators {
        get {
            return Operators(rawValue: UInt64(onig_get_syntax_op(self.rawValue)))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_op(self.rawValue, UInt32(newValue.rawValue))
        }
    }

    /**
     Syntax operators 2.
     */
    public var operators2: Operators2 {
        get {
            return Operators2(rawValue: UInt64(onig_get_syntax_op2(self.rawValue)))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_op2(self.rawValue, UInt32(newValue.rawValue))
        }
    }

    /**
     Syntax options.
     */
    public var options: Regex.Options {
        get {
            return Regex.Options(rawValue: onig_get_syntax_options(self.rawValue))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_options(self.rawValue, newValue.rawValue)
        }
    }

    /**
     Syntax behaviors.
     */
    public var behaviors: Behaviors {
        get {
            return Behaviors(rawValue: onig_get_syntax_behavior(self.rawValue))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_behavior(self.rawValue, newValue.rawValue)
        }
    }
}

/**
 Syntax operators
 */
extension Syntax {
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
        public static let escCapitalUHex4 = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_U_HEX4))
        public static let escVVerticalTab = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_V_VTAB))
        public static let escHHorizontalTab = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_H_XDIGIT))
        public static let escCapitalKKeep = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_K_NAMED_BACKREF))
        public static let escCapitalRLinebreak = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE))
        public static let escCapitalXExtendedGraphemeCluster = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT))
        public static let qmarkLparenCondition = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE))
        public static let qmarkBraceCallout = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS))
        public static let asteriskBraceCallout = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY))
    }

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

    public enum MetaChar: Sendable {
        case Ineffective
        case CodePoint(OnigCodePoint)
        
        public var description: String {
            switch self {
            case .Ineffective:
                return ""
            case .CodePoint(let codePoint):
                // To avoid overlapping access during description, copy to local variable
                var cp = codePoint
                let count = codePoint > 0xFFFFFF ? 4 : (codePoint > 0xFFFF ? 3 : (codePoint > 0xFF ? 2 : 1))
                return withUnsafeBytes(of: &cp) { buf in
                    let bytes = buf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
                }
            }
        }
    }

    public struct MetaCharTable: Sendable {
        public let syntax: Syntax
        
        @OnigurumaActor
        public subscript(index: MetaCharIndex) -> MetaChar {
            get {
                let codePoint: OnigCodePoint
                switch index {
                case .Escape: codePoint = self.syntax.rawValue.pointee.meta_char_table.esc
                case .AnyChar: codePoint = self.syntax.rawValue.pointee.meta_char_table.anychar
                case .AnyTime: codePoint = self.syntax.rawValue.pointee.meta_char_table.anytime
                case .ZeroOrOne: codePoint = self.syntax.rawValue.pointee.meta_char_table.zero_or_one_time
                case .OneOrMore: codePoint = self.syntax.rawValue.pointee.meta_char_table.one_or_more_time
                case .AnyCharAnytime: codePoint = self.syntax.rawValue.pointee.meta_char_table.anychar_anytime
                }
                
                if codePoint == OnigCodePoint(ONIG_INEFFECTIVE_META_CHAR) {
                    return .Ineffective
                } else {
                    return .CodePoint(codePoint)
                }
            }
            
            set {
                self.syntax.convertToOwnedIfNeeded()
                let codePoint: OnigCodePoint
                switch newValue {
                case .Ineffective: codePoint = OnigCodePoint(bitPattern: Int32(ONIG_INEFFECTIVE_META_CHAR))
                case .CodePoint(let cp): codePoint = cp
                }
                onig_set_meta_char(self.syntax.rawValue, OnigUInt(index.rawValue), codePoint)
            }
        }
    }

    public var metaCharTable: MetaCharTable {
        @OnigurumaActor get {
            MetaCharTable(syntax: self)
        }
    }
}
extension Syntax {
    @OnigurumaActor
    internal convenience init(rawValue: UnsafeMutablePointer<OnigSyntaxType>) {
        self.init(rawValue: rawValue, ownership: .borrowedPreset)
    }
}
