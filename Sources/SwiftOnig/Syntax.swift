//
//  Syntax.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

/// Onig Syntax Wrapper
///
/// Each syntax dfines a flavour of regex syntax. This type allows
/// interaction with the built-in syntaxes through the static accessor
/// (`Syntax.emacs`, `Syntax.default` etc.) and the
/// creation of custom syntaxes.
public class Syntax {
    internal var rawValue: OnigSyntaxType

    init(rawValue: OnigSyntaxType) {
        self.rawValue = rawValue
    }

    /// Plain text syntax
    public static var asis: Syntax {
        return Syntax(rawValue: OnigSyntaxASIS)
    }
    
    /// POSIX Basic RE syntax
    public static var posixBasic: Syntax {
        return Syntax(rawValue: OnigSyntaxPosixBasic)
    }
    
    /// POSIX Extended RE syntax
    public static var posixExtended: Syntax {
        return Syntax(rawValue: OnigSyntaxPosixExtended)
    }

    /// Emacs syntax
    public static var emacs: Syntax {
        return Syntax(rawValue: OnigSyntaxEmacs)
    }
    
    /// Grep syntax
    public static var grep: Syntax {
        return Syntax(rawValue: OnigSyntaxGrep)
    }
    
    /// GNU regex syntax
    public static var gnuRegex: Syntax {
        return Syntax(rawValue: OnigSyntaxGnuRegex)
    }
    
    /// Java syntax
    public static var java: Syntax {
        return Syntax(rawValue: OnigSyntaxJava)
    }
    
    /// Perl syntax
    public static var perl: Syntax {
        return Syntax(rawValue: OnigSyntaxPerl)
    }
    
    /// Perl + named group syntax
    public static var perlNg: Syntax {
        return Syntax(rawValue: OnigSyntaxPerl_NG)
    }
    
    /// Ruby syntax
    public static var ruby: Syntax {
        return Syntax(rawValue: OnigSyntaxRuby)
    }
    
    /// Oniguruma syntax
    public static var oniguruma: Syntax {
        return Syntax(rawValue: OnigSyntaxOniguruma)
    }
    
    /// Default syntax
    public static var `default`: Syntax {
        get {
            return Syntax(rawValue: OnigDefaultSyntax.pointee)
        }
        
        set {
            var raw = newValue.rawValue
            onig_set_default_syntax(&raw)
        }
    }

    /**
     Get or set the syntax options for this syntax.
     */
    public var options: RegexOptions {
        get {
            return RegexOptions(rawValue: onig_get_syntax_options(&self.rawValue))
        }
        
        set {
            onig_set_syntax_options(&self.rawValue, newValue.rawValue)
        }
    }
}

/**
 Syntax operators
 */
extension Syntax {
    public struct Operators: OptionSet {
        public let rawValue: UInt64

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }
        
        public init(onigSyntaxOp: UInt32, onigSyntaxOp2: UInt32) {
            self.rawValue = UInt64(onigSyntaxOp) | (UInt64(onigSyntaxOp2) << 32)
        }

        public static let variableMetaCharacters = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_VARIABLE_META_CHARACTERS))

        /// .
        public static let dotAnychar = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_DOT_ANYCHAR))

        /// *
        public static let asteriskZeroInf = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ASTERISK_ZERO_INF))


        public static let escAsteriskZeroInf = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_ASTERISK_ZERO_INF))

        /// +
        public static let plusOneInf = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_PLUS_ONE_INF))


        public static let escPlusOneInf = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_PLUS_ONE_INF))

        /// ?
        public static let qmarkZeroOne = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_QMARK_ZERO_ONE))


        public static let escQmarkZeroOne = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_QMARK_ZERO_ONE))

        /// {lower,upper}
        public static let braceInterval = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_BRACE_INTERVAL))

        /// \{lower,upper\}
        public static let escBraceInterval = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_BRACE_INTERVAL))

        /// |
        public static let vbarAlt = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_VBAR_ALT))

        /// \|
        public static let escVbarAlt = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_VBAR_ALT))

        /// (...)
        public static let lparenSubexp = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_LPAREN_SUBEXP))

        /// \(...\)
        public static let escLparenSubexp = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LPAREN_SUBEXP))

        /// \A, \Z, \z
        public static let escAzBufAnchor = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR))

        /// \G
        public static let escCapitalGBeginAnchor = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CAPITAL_G_BEGIN_ANCHOR))

        /// \num
        public static let decimalBackref = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_DECIMAL_BACKREF))

        /// [...]
        public static let bracketCc = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_BRACKET_CC))

        /// \w, \W
        public static let escWWord = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_W_WORD))

        /// \<. \>
        public static let escLtgtWordBeginEnd = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END))

        /// \b, \B
        public static let escBWordBound = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_B_WORD_BOUND))

        /// \s, \S
        public static let escSWhiteSpace = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_S_WHITE_SPACE))

        /// \d, \D
        public static let escDDigit = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_D_DIGIT))

        /// ^, $
        public static let lineAnchor = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_LINE_ANCHOR))

        /// [:xxxx:]
        public static let posixBracket = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_POSIX_BRACKET))

        /// ??,*?,+?,{n,m}?
        public static let qmarkNonGreedy = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_QMARK_NON_GREEDY))

        /// \n,\r,\t,\a ...
        public static let escControlChars = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_CONTROL_CHARS))

        /// \cx
        public static let escCControl = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_C_CONTROL))

        /// \OOO
        public static let escOctal3 = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_OCTAL3))

        /// \xHH
        public static let escXHex2 = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_HEX2))

        /// \x{7HHHHHHH}
        public static let escXBraceHex8 = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_X_BRACE_HEX8))

        /// \o{1OOOOOOOOOO}
        public static let escOBraceOctal = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP_ESC_O_BRACE_OCTAL))


        /// \Q...\E
        public static let escCapitalQQuote = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_Q_QUOTE) << 32)

        /// (?...)
        public static let qmarkGroupEffect = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_GROUP_EFFECT) << 32)

        /// (?imsx),(?-imsx)
        public static let optionPerl = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_OPTION_PERL) << 32)

        /// (?imx), (?-imx)
        public static let optionRuby = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_OPTION_RUBY) << 32)

        /// ?+,*+,++
        public static let plusPossessiveRepeat = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_REPEAT) << 32)

        /// {n,m}+
        public static let plusPossessiveInterval = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL) << 32)

        /// [...&&..[..]..]
        public static let cclassSetOp = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_CCLASS_SET_OP) << 32)

        /// (?<name>...)
        public static let qmarkLtNamedGroup = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP) << 32)

        /// \k<name>
        public static let escKNamedBackref = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_K_NAMED_BACKREF) << 32)

        /// \g<name>, \g<n>
        public static let escGSubexpCall = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_G_SUBEXP_CALL) << 32)

        /// (?@..),(?@<x>..)
        public static let atmarkCaptureHistory = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY) << 32)

        /// \C-x
        public static let escCapitalCBarControl = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_C_BAR_CONTROL) << 32)

        /// \M-x
        public static let escCapitalMBarMeta = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_M_BAR_META) << 32)

        /// \v as VTAB
        public static let escVVtab = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_V_VTAB) << 32)

        /// \uHHHH
        public static let escUHex4 = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_U_HEX4) << 32)

        /// \`, \'
        public static let escGnuBufAnchor = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_GNU_BUF_ANCHOR) << 32)

        /// \p{...}, \P{...}
        public static let escPBraceCharProperty = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CHAR_PROPERTY) << 32)

        /// \p{^..}, \P{^..}
        public static let escPBraceCircumflexNot = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT) << 32)


        /// \h, \H
        public static let escHXdigit = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_H_XDIGIT) << 32)

        /// \
        public static let ineffectiveEscape = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_INEFFECTIVE_ESCAPE) << 32)

        /// (?(n)) (?(...)...|...)
        public static let qmarkLparenIfElse = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE) << 32)

        /// \K
        public static let escCapitalKKeep = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_K_KEEP) << 32)

        /// \R \r\n else [\x0a-\x0d]
        public static let escCapitalRGeneralNewline = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE) << 32)

        /// \N (?-m:.), \O (?m:.)
        public static let escCapitalNOSuperDot = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT) << 32)

        /// (?~...)
        public static let qmarkTildeAbsentGroup = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_TILDE_ABSENT_GROUP) << 32)

        /// obsoleted: use next
        public static let escXYGraphemeCluster = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_GRAPHEME_CLUSTER) << 32)

        /// \X \y \Y
        public static let escXYTextSegment = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT) << 32)

        /// (?R), (?&name)...
        public static let qmarkPerlSubexpCall = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_PERL_SUBEXP_CALL) << 32)

        /// (?{...}) (?{{...}})
        public static let qmarkBraceCalloutContents = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS) << 32)

        /// (*name) (*name{a,..})
        public static let asteriskCalloutName = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME) << 32)

        /// (?imxWDSPy)
        public static let optionOniguruma = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_OPTION_ONIGURUMA) << 32)

    //    /// (?P<name>...) (?P=name)
    //    public static let qmarkCapitalPName = Syntax.Operators(rawValue: UInt64(ONIG_SYN_OP2_QMARK_CAPITAL_P_NAME) << 32)
        
        public var onigSyntaxOp: UInt32 {
            get {
                return UInt32(self.rawValue & 0xFFFFFFFF)
            }
        }
        
        public var onigSyntaxOp2: UInt32 {
            get {
                return UInt32(self.rawValue >> 32)
            }
        }
    }

    /**
     Get or set the operators for this syntax.
     */
    public var operators: Syntax.Operators {
        get {
            return Syntax.Operators(onigSyntaxOp: onig_get_syntax_op(&self.rawValue),
                                    onigSyntaxOp2: onig_get_syntax_op2(&self.rawValue))
        }
        
        set {
            onig_set_syntax_op(&self.rawValue, newValue.onigSyntaxOp)
            onig_set_syntax_op2(&self.rawValue, newValue.onigSyntaxOp2)
        }
    }
    
    /**
     Enable operators for this syntax.
     - Parameters:
        - operators: operators to be enabled.
     */
    public func enableOperators(operators: Syntax.Operators) {
        var currentOperators = self.operators
        currentOperators.insert(operators)
        self.operators = currentOperators
    }
    
    /**
     Disable operators for this syntax.
     - Parameters:
        - operators: operators to be disabled.
     */
    public func disableOperators(operators: Syntax.Operators) {
        var currentOperators = self.operators
        currentOperators.remove(operators)
        self.operators = currentOperators
    }
}

/**
 Syntax behaviors
 */
extension Syntax {
    public struct Behaviors: OptionSet {
        public let rawValue: UInt32
        
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
        
        // syntax (behavior)

        /// ?, *, +, {n,m}
        public static let contextIndepRepeatOps = Syntax.Behaviors(rawValue: ONIG_SYN_CONTEXT_INDEP_REPEAT_OPS)

        /// error or ignore
        public static let contextInvalidRepeatOps = Syntax.Behaviors(rawValue: ONIG_SYN_CONTEXT_INVALID_REPEAT_OPS)

        /// ...)...
        public static let allowUnmatchedCloseSubexp = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_UNMATCHED_CLOSE_SUBEXP)

        /// {???
        public static let allowInvalidInterval = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_INVALID_INTERVAL)

        /// {,n} => {0,n}
        public static let allowIntervalLowAbbrev = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV)

        /// /(\1)/,/\1()/ ..
        public static let strictCheckBackref = Syntax.Behaviors(rawValue: ONIG_SYN_STRICT_CHECK_BACKREF)

        /// (?<=a|bc)
        public static let differentLenAltLookBehind = Syntax.Behaviors(rawValue: ONIG_SYN_DIFFERENT_LEN_ALT_LOOK_BEHIND)

        /// see doc/RE
        public static let captureOnlyNamedGroup = Syntax.Behaviors(rawValue: ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)

        /// (?<x>)(?<x>)
        public static let allowMultiplexDefinitionName = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_MULTIPLEX_DEFINITION_NAME)

        /// a{n}?=(?:a{n})?
        public static let fixedIntervalIsGreedyOnly = Syntax.Behaviors(rawValue: ONIG_SYN_FIXED_INTERVAL_IS_GREEDY_ONLY)

        /// ..(?i)...|...
        public static let isolatedOptionContinueBranch = Syntax.Behaviors(rawValue: ONIG_SYN_ISOLATED_OPTION_CONTINUE_BRANCH)

        /// (?<=a+|..)
        public static let variableLenLookBehind = Syntax.Behaviors(rawValue: ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND)

        /// \UHHHHHHHH
    //    public static let python = Syntax.Behaviors(rawValue: ONIG_SYN_PYTHON)

        // syntax (behavior) in char class [...]

        /// [^...]
        public static let notNewlineInNegativeCc = Syntax.Behaviors(rawValue: ONIG_SYN_NOT_NEWLINE_IN_NEGATIVE_CC)

        /// [..\w..] etc..
        public static let backslashEscapeInCc = Syntax.Behaviors(rawValue: ONIG_SYN_BACKSLASH_ESCAPE_IN_CC)

        public static let allowEmptyRangeInCc = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC)

        /// [0-9-a]=[0-9\-a]
        public static let allowDoubleRangeOpInCc = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_DOUBLE_RANGE_OP_IN_CC)

        public static let allowInvalidCodeEndOfRangeInCc = Syntax.Behaviors(rawValue: ONIG_SYN_ALLOW_INVALID_CODE_END_OF_RANGE_IN_CC)

        // syntax (behavior) warning

        /// [,-,]
        public static let warnCcOpNotEscaped = Syntax.Behaviors(rawValue: ONIG_SYN_WARN_CC_OP_NOT_ESCAPED)

        /// (?:a*)+
        public static let warnRedundantNestedRepeat = Syntax.Behaviors(rawValue: ONIG_SYN_WARN_REDUNDANT_NESTED_REPEAT)
    }

    /**
     Get or set the syntax behaviours
     */
    public var behaviors: Syntax.Behaviors {
        get {
            var onigSyntax = self.rawValue
            return Syntax.Behaviors(rawValue: onig_get_syntax_behavior(&onigSyntax))
        }
        
        set {
            onig_set_syntax_behavior(&self.rawValue, newValue.rawValue)
        }
    }
    
    /**
     Enable given behaviours for this syntax.
     - Parameters:
        - behavior: behaviors to be enabled.
     */
    public func enableBehaviors(behaviors: Syntax.Behaviors) {
        var currentBehavior = self.behaviors
        currentBehavior.insert(behaviors)
        self.behaviors = currentBehavior
    }
    
    /**
     Disable given behaviors for this syntax.
     - Parameters:
        - behaviors: behaviors to be disabled.
     */
    public func disableBehaviors(behaviors: Syntax.Behaviors) {
        var currentBehavior = self.behaviors
        currentBehavior.remove(behaviors)
        self.behaviors = currentBehavior
    }
}

/**
 Syntax metachars
 */
extension Syntax {
    /**
     Meta character specifiers
     */
    public enum MetaCharType: UInt32 {
        /// The escape character
        case escape = 0
        /// The any (.) character
        case anyChar = 1
        /// The any number of repeats (*) character
        case anyTime = 2
        /// The optinoal (?) chracter
        case zeroOrOneTime = 3
        /// The at least once (+) character
        case oneOrMoreTime = 4
        /// The glob character for this syntax (.*)
        case anyCharAnyTime = 5
    }
    
    public enum MetaChar: Equatable {
        /// The meta character is not enabled
        case Ineffective
        /// The meta character is set to the chosen `char`s, the max length of the a codepoint is 4 chars.
        case CodePoint([UInt8])
        
        public init(codePoint: UInt32) {
            if codePoint == ONIG_INEFFECTIVE_META_CHAR {
                self = .Ineffective
            } else {
                var bytes = [UInt8]()
                var codePoint = codePoint
                while codePoint != 0 {
                    bytes.append(UInt8(codePoint & 0xFF))
                    codePoint = codePoint >> 8
                }

                bytes.reverse()
                self = .CodePoint(bytes)
            }
        }
        
        /**
         Init a `MetaChar` with a string, if the string is empty or its `utf8` view has more than *4* bytes, the result will be `.Ineffective`
         */
        public init(chars: String) {
            let bytes = [UInt8](chars.utf8)
            if (bytes.count == 0 || bytes.count > 4) {
                self = .Ineffective
            } else {
                self = .CodePoint(bytes)
            }
        }
    }

    public struct MetaCharTable {
        fileprivate var syntax: Syntax
        
        subscript(index: MetaCharType) -> MetaChar {
            get {
                switch (index) {
                case .escape:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.esc)
                case .anyChar:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.anychar)
                case .anyTime:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.anytime)
                case .zeroOrOneTime:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.zero_or_one_time)
                case .oneOrMoreTime:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.one_or_more_time)
                case .anyCharAnyTime:
                    return MetaChar(codePoint: self.syntax.rawValue.meta_char_table.anychar_anytime)
                }
            }
            
            set {
                let what = index.rawValue
                var code: UInt32 = 0
                switch (newValue) {
                    case .Ineffective:
                        code = UInt32(ONIG_INEFFECTIVE_META_CHAR)
                    case .CodePoint(let codePoint):
                        if codePoint.count == 0 {
                            code = UInt32(ONIG_INEFFECTIVE_META_CHAR)
                        } else {
                            for i in 0 ..< min(codePoint.count, 4) {
                                code = (code << 8) | UInt32(codePoint[i])
                            }
                        }
                }

                onig_set_meta_char(&self.syntax.rawValue, what, code)
            }
        }
    }
    
    /**
     Meta char table of the syntax.
     */
    public var metaCharTable: MetaCharTable {
        get {
            return MetaCharTable(syntax: self)
        }

        set {
        }
    }
}
