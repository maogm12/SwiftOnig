//
//  Syntax.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig
import OnigInternal

/**
 Oniguruma syntax wrapper. This type also comes with static wrapper for oniguruma build-in syntaxes, i.e. `Syntax.oniguruma`, `Syntax.default`.
 */
public final class Syntax: Sendable {
    internal typealias OnigSyntaxPtr = UnsafeMutablePointer<OnigSyntaxType>
    internal nonisolated(unsafe) var rawValue: OnigSyntaxPtr!

    /**
     This `OnigSyntaxType` is owned by this object, for oniguruma built-in syntaxes, we only carry the pointer to them.
     */
    private nonisolated(unsafe) var ownedSyntax: OnigSyntaxType? = nil

    /**
     Create a empty syntax.
     */
    public init() {
        self.ownedSyntax = OnigSyntaxType()
        withUnsafeMutablePointer(to: &self.ownedSyntax!) {
            self.rawValue = $0
        }
    }

    internal init(rawValue: OnigSyntaxPtr!) {
        self.rawValue = rawValue
    }

    /**
     Create a syntax by copying from another syntax.
     - Parameter other: The syntax to copy from.
     */
    public init(copying other: Syntax) {
        self.ownedSyntax = other.rawValue.pointee
        withUnsafeMutablePointer(to: &self.ownedSyntax!) {
            self.rawValue = $0
        }
    }

    private func convertToOwnedIfNeeded() {
        if self.ownedSyntax == nil {
            self.ownedSyntax = self.rawValue.pointee
            withUnsafeMutablePointer(to: &self.ownedSyntax!) {
                self.rawValue = $0
            }
        }
    }

    /// Plain text syntax
    @OnigurumaActor public static var asis: Syntax { Syntax(rawValue: get_onig_asis()) }
    
    /// POSIX Basic RE syntax
    @OnigurumaActor public static var posixBasic: Syntax { Syntax(rawValue: get_onig_posix_basic()) }
    
    /// POSIX Extended RE syntax
    @OnigurumaActor public static var posixExtended: Syntax { Syntax(rawValue: get_onig_posix_extended()) }

    /// Emacs syntax
    @OnigurumaActor public static var emacs: Syntax { Syntax(rawValue: get_onig_emacs()) }
    
    /// Grep syntax
    @OnigurumaActor public static var grep: Syntax { Syntax(rawValue: get_onig_grep()) }
    
    /// GNU regex syntax
    @OnigurumaActor public static var gnuRegex: Syntax { Syntax(rawValue: get_onig_gnu_regex()) }
    
    /// Java syntax
    @OnigurumaActor public static var java: Syntax { Syntax(rawValue: get_onig_java()) }
    
    /// Perl syntax
    @OnigurumaActor public static var perl: Syntax { Syntax(rawValue: get_onig_perl()) }
    
    /// Perl + named group syntax
    @OnigurumaActor public static var perlNg: Syntax { Syntax(rawValue: get_onig_perl_ng()) }
    
    /// Ruby syntax
    @OnigurumaActor public static var ruby: Syntax { Syntax(rawValue: get_onig_ruby()) }
    
    /// Oniguruma syntax
    @OnigurumaActor public static var oniguruma: Syntax { Syntax(rawValue: get_onig_oniguruma()) }
    
    /// Default syntax
    @OnigurumaActor
    public static var `default`: Syntax {
        get {
            return Syntax(rawValue: get_onig_default_syntax())
        }
        
        set {
            onig_set_default_syntax(newValue.rawValue)
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

        public static let variableMetaCharacters = Operators(rawValue: UInt64(get_onig_syn_op_variable_meta_characters()))
        public static let dotAnyChar = Operators(rawValue: UInt64(get_onig_syn_op_dot_anychar()))
        public static let asteriskZeroOrMore = Operators(rawValue: UInt64(get_onig_syn_op_asterisk_zero_inf()))
        public static let escAsteriskZeroOrMore = Operators(rawValue: UInt64(get_onig_syn_op_esc_asterisk_zero_inf()))
        public static let plusOneOrMore = Operators(rawValue: UInt64(get_onig_syn_op_plus_one_inf()))
        public static let escPlusOneOrMore = Operators(rawValue: UInt64(get_onig_syn_op_esc_plus_one_inf()))
        public static let questionOneOrZero = Operators(rawValue: UInt64(get_onig_syn_op_qmark_zero_one()))
        public static let escQuestionOneOrZero = Operators(rawValue: UInt64(get_onig_syn_op_esc_qmark_zero_one()))
        public static let braceInterval = Operators(rawValue: UInt64(ONIG_SYN_OP_BRACE_INTERVAL))
        public static let escBraceInterval = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_BRACE_INTERVAL))
        public static let vbarAlt = Operators(rawValue: UInt64(ONIG_SYN_OP_VBAR_ALT))
        public static let escVbarAlt = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_VBAR_ALT))
        public static let lparenSubexp = Operators(rawValue: UInt64(ONIG_SYN_OP_LPAREN_SUBEXP))
        public static let escLparenSubexp = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LPAREN_SUBEXP))
        public static let escAzBufAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR))
        public static let escCapitalGBeginAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CAPITAL_G_BEGIN_ANCHOR))
        public static let decimalBackref = Operators(rawValue: UInt64(ONIG_SYN_OP_DECIMAL_BACKREF))
        public static let bracketAnychar = Operators(rawValue: UInt64(get_onig_syn_op_bracket_cc()))
        public static let escWWord = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_W_WORD))
        public static let escLtgtWordBeginEnd = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END))
        public static let escBWordBound = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_B_WORD_BOUND))
        public static let escSWhiteSpace = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_S_WHITE_SPACE))
        public static let escDDigit = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_D_DIGIT))
        public static let lineAnchor = Operators(rawValue: UInt64(ONIG_SYN_OP_LINE_ANCHOR))
        public static let posixBracket = Operators(rawValue: UInt64(ONIG_SYN_OP_POSIX_BRACKET))
        public static let qmarkNonGreedy = Operators(rawValue: UInt64(ONIG_SYN_OP_QMARK_NON_GREEDY))
        public static let escControlChars = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CONTROL_CHARS))
        public static let escCControl = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_C_CONTROL))
        public static let escOctal3 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_OCTAL3))
        public static let escXHex2 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_HEX2))
        public static let escXBraceHex8 = Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_BRACE_HEX8))
        public static let escCapOOption = Operators(rawValue: UInt64(get_onig_syn_op_esc_cap_o_option()))
    }

    public var operators: Operators {
        get {
            return Operators(rawValue: UInt64(onig_get_syntax_op(self.rawValue)))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_op(self.rawValue, UInt32(newValue.rawValue))
        }
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
        public static let cclassSetOp = Operators2(rawValue: UInt64(ONIG_SYN_OP2_CCLASS_SET_OP))
        public static let qmarkLtNamedGroup = Operators2(rawValue: UInt64(get_onig_syn_op2_qmark_lt_named_group()))
        public static let escKNamedBackref = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_k_named_backref()))
        public static let escGSubexpCall = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_g_subexp_call()))
        public static let atmarkCaptureHistory = Operators2(rawValue: UInt64(get_onig_syn_op2_atmark_capture_history()))
        public static let escCapitalCBarControl = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_C_BAR_CONTROL))
        public static let escCapitalMBarMeta = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_M_BAR_META))
        public static let escVVtab = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_v_vtab()))
        public static let escUHex4 = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_u_hex4()))
        public static let escGnuBufAnchor = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_GNU_BUF_ANCHOR))
        public static let escPBraceCharProperty = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CHAR_PROPERTY))
        public static let escPBraceCircumflexNot = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_p_brace_circumflex_not()))
        public static let escHXdigit = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_h_xdigit()))
        public static let ineffectiveEscape = Operators2(rawValue: UInt64(ONIG_SYN_OP2_INEFFECTIVE_ESCAPE))
        public static let qmarkLparenIfElse = Operators2(rawValue: UInt64(get_onig_syn_op2_qmark_lparen_if_else()))
        public static let escCapitalKKeep = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_K_KEEP))
        public static let escCapitalRGeneralNewline = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_capital_r_general_newline()))
        public static let escCapitalNOSuperDot = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_capital_n_o_super_dot()))
        public static let qmarkTildeAbsentGroup = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_TILDE_ABSENT_GROUP))
        public static let escXYTextSegment = Operators2(rawValue: UInt64(get_onig_syn_op2_esc_x_y_text_segment()))
        public static let qmarkPerlSubexpCall = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_PERL_SUBEXP_CALL))
        public static let qmarkBraceCalloutContents = Operators2(rawValue: UInt64(get_onig_syn_op2_qmark_brace_callout_contents()))
        public static let asteriskCalloutName = Operators2(rawValue: UInt64(ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME))
        public static let optionOniguruma = Operators2(rawValue: UInt64(ONIG_SYN_OP2_OPTION_ONIGURUMA))
        public static let qmarkCapitalPName = Operators2(rawValue: UInt64(ONIG_SYN_OP2_QMARK_CAPITAL_P_NAME))
    }

    public var operators2: Operators2 {
        get {
            return Operators2(rawValue: UInt64(onig_get_syntax_op2(self.rawValue)))
        }

        set {
            self.convertToOwnedIfNeeded()
            onig_set_syntax_op2(self.rawValue, UInt32(newValue.rawValue))
        }
    }
}

/**
 Syntax behaviors
 */
extension Syntax {
    public struct Behaviors: OptionSet, Sendable {
        public let rawValue: OnigUInt
        
        public init(rawValue: OnigUInt) {
            self.rawValue = rawValue
        }

        public static let contextIndepRepeatOps = Behaviors(rawValue: ONIG_SYN_CONTEXT_INDEP_REPEAT_OPS)
        public static let contextInvalidRepeatOps = Behaviors(rawValue: ONIG_SYN_CONTEXT_INVALID_REPEAT_OPS)
        public static let allowUnmatchedCloseSubexp = Behaviors(rawValue: get_onig_syn_allow_unmatched_close_subexp())
        public static let allowInvalidInterval = Behaviors(rawValue: ONIG_SYN_ALLOW_INVALID_INTERVAL)
        public static let allowIntervalLowAbbrev = Behaviors(rawValue: get_onig_syn_allow_interval_low_abbrev())
        public static let strictCheckBackref = Behaviors(rawValue: ONIG_SYN_STRICT_CHECK_BACKREF)
        public static let differentLengthAltLookBehind = Behaviors(rawValue: ONIG_SYN_DIFFERENT_LEN_ALT_LOOK_BEHIND)
        public static let captureOnlyNamedGroup = Behaviors(rawValue: ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)
        public static let allowMultiplexDefinitionName = Behaviors(rawValue: ONIG_SYN_ALLOW_MULTIPLEX_DEFINITION_NAME)
        public static let fixedIntervalIsGreedyOnly = Behaviors(rawValue: ONIG_SYN_FIXED_INTERVAL_IS_GREEDY_ONLY)
        public static let allowEmptyRangeInCc = Behaviors(rawValue: get_onig_syn_allow_empty_range_in_cc())
        public static let allowMultiplexCheckLength = Behaviors(rawValue: get_onig_syn_allow_multiplex_check_length())
        public static let backslashEscapeInCC = Behaviors(rawValue: ONIG_SYN_BACKSLASH_ESCAPE_IN_CC)
        public static let allowDoubleRangeOpInCC = Behaviors(rawValue: ONIG_SYN_ALLOW_DOUBLE_RANGE_OP_IN_CC)
        public static let warnCCOpNotEscaped = Behaviors(rawValue: get_onig_syn_warn_cc_op_not_escaped())
        public static let warnRedundantNestedRepeat = Behaviors(rawValue: ONIG_SYN_WARN_REDUNDANT_NESTED_REPEAT)
        public static let warnCCDup = Behaviors(rawValue: get_onig_syn_warn_cc_dup())
    }
}

extension Syntax {
    public enum MetaCharIndex: Int, Sendable {
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
                var cp = codePoint
                let count = codePoint > 0xFFFFFF ? 4 : (codePoint > 0xFFFF ? 3 : (codePoint > 0xFF ? 2 : 1))
                return withUnsafeBytes(of: &cp) {
                    let bytes = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
                }
            }
        }
    }

    public struct MetaCharTable {
        public let syntax: Syntax
        
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
                case .Ineffective: codePoint = OnigCodePoint(bitPattern: ONIG_INEFFECTIVE_META_CHAR)
                case .CodePoint(let cp): codePoint = cp
                }
                onig_set_meta_char(self.syntax.rawValue, OnigUInt(index.rawValue), codePoint)
            }
        }
    }

    public var metaCharTable: MetaCharTable {
        MetaCharTable(syntax: self)
    }
}
