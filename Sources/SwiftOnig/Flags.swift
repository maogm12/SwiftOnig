//
//  Flags.swift
//  
//
//  Created by Gavin Mao on 3/27/21.
//

import COnig

/// Regex parsing and compilation options.
public struct RegexOptions: OptionSet {
    public let rawValue: OnigOptionType
    
    public init(rawValue: OnigOptionType) {
        self.rawValue = rawValue
    }

    /// Default options.
    public static let none = RegexOptions(rawValue: ONIG_OPTION_NONE)

    /// Ambiguity match on.
    public static let ignoreCase = RegexOptions(rawValue: ONIG_OPTION_IGNORECASE)
    
    /// Extended pattern form.
    public static let extend = RegexOptions(rawValue: ONIG_OPTION_EXTEND)

    /// `'.'` match with newline.
    public static let multiLine = RegexOptions(rawValue: ONIG_OPTION_MULTILINE);
    
    /// `'^'` -> `'\A'`, `'$'` -> `'\Z'`.
    public static let singleLine = RegexOptions(rawValue: ONIG_OPTION_SINGLELINE);
    
    /// Find longest match.
    public static let findLongest = RegexOptions(rawValue: ONIG_OPTION_FIND_LONGEST);
    
    /// Ignore empty match.
    public static let findNotEmpty = RegexOptions(rawValue: ONIG_OPTION_FIND_NOT_EMPTY);

    /// Clear `OPTION_SINGLELINE` which is enabled on
    /// `SYNTAX_POSIX_BASIC`, `SYNTAX_POSIX_EXTENDED`,
    /// `SYNTAX_PERL`, `SYNTAX_PERL_NG`, `SYNTAX_JAVA`.
    public static let negateSingleLine = RegexOptions(rawValue: ONIG_OPTION_NEGATE_SINGLELINE);

    /// Only named group captured.
    public static let dontCaptureGroup = RegexOptions(rawValue: ONIG_OPTION_DONT_CAPTURE_GROUP);

    /// Named and no-named group captured.
    public static let captureGroup = RegexOptions(rawValue: ONIG_OPTION_CAPTURE_GROUP);
}

/// Regex evaluation options.
public struct SearchOptions: OptionSet {
    public let rawValue: OnigOptionType
    
    public init(rawValue: OnigOptionType) {
        self.rawValue = rawValue
    }

    /// Default options.
    public static let none = SearchOptions(rawValue: ONIG_OPTION_NONE);
    
    /// Do not regard the beginning of the (str) as the beginning of the line and the beginning of the string
    public static let notBol = SearchOptions(rawValue: ONIG_OPTION_NOTBOL);

    /// Do not regard the (end) as the end of a line and the end of a string
    public static let notEol = SearchOptions(rawValue: ONIG_OPTION_NOTEOL);
    
    /// Do not regard the beginning of the (str) as the beginning of a string  (* fail \A)
    public static let notBeginString = SearchOptions(rawValue: ONIG_OPTION_NOT_BEGIN_STRING)
    
    /// Do not regard the (end) as a string endpoint  (* fail \z, \Z)
    public static let notEndString = SearchOptions(rawValue: ONIG_OPTION_NOT_END_STRING)
    
    /// Do not regard the (start) as start position of search  (* fail \G)
    public static let notBeginPosition = SearchOptions(rawValue: ONIG_OPTION_NOT_BEGIN_POSITION)
}

public struct SyntaxOperator: OptionSet {
    public let rawValue: UInt64
    
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    public init(onigSyntaxOp: UInt32, onigSyntaxOp2: UInt32) {
        self.rawValue = UInt64(onigSyntaxOp) | (UInt64(onigSyntaxOp2) << 32)
    }

    public static let variableMetaCharacters = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_VARIABLE_META_CHARACTERS))

    /// .
    public static let dotAnychar = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_DOT_ANYCHAR))

    /// *
    public static let asteriskZeroInf = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ASTERISK_ZERO_INF))


    public static let escAsteriskZeroInf = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_ASTERISK_ZERO_INF))

    /// +
    public static let plusOneInf = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_PLUS_ONE_INF))


    public static let escPlusOneInf = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_PLUS_ONE_INF))

    /// ?
    public static let qmarkZeroOne = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_QMARK_ZERO_ONE))


    public static let escQmarkZeroOne = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_QMARK_ZERO_ONE))

    /// {lower,upper}
    public static let braceInterval = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_BRACE_INTERVAL))

    /// \{lower,upper\}
    public static let escBraceInterval = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_BRACE_INTERVAL))

    /// |
    public static let vbarAlt = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_VBAR_ALT))

    /// \|
    public static let escVbarAlt = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_VBAR_ALT))

    /// (...)
    public static let lparenSubexp = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_LPAREN_SUBEXP))

    /// \(...\)
    public static let escLparenSubexp = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_LPAREN_SUBEXP))

    /// \A, \Z, \z
    public static let escAzBufAnchor = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_AZ_BUF_ANCHOR))

    /// \G
    public static let escCapitalGBeginAnchor = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_CAPITAL_G_BEGIN_ANCHOR))

    /// \num
    public static let decimalBackref = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_DECIMAL_BACKREF))

    /// [...]
    public static let bracketCc = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_BRACKET_CC))

    /// \w, \W
    public static let escWWord = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_W_WORD))

    /// \<. \>
    public static let escLtgtWordBeginEnd = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END))

    /// \b, \B
    public static let escBWordBound = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_B_WORD_BOUND))

    /// \s, \S
    public static let escSWhiteSpace = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_S_WHITE_SPACE))

    /// \d, \D
    public static let escDDigit = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_D_DIGIT))

    /// ^, $
    public static let lineAnchor = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_LINE_ANCHOR))

    /// [:xxxx:]
    public static let posixBracket = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_POSIX_BRACKET))

    /// ??,*?,+?,{n,m}?
    public static let qmarkNonGreedy = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_QMARK_NON_GREEDY))

    /// \n,\r,\t,\a ...
    public static let escControlChars = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_CONTROL_CHARS))

    /// \cx
    public static let escCControl = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_C_CONTROL))

    /// \OOO
    public static let escOctal3 = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_OCTAL3))

    /// \xHH
    public static let escXHex2 = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_X_HEX2))

    /// \x{7HHHHHHH}
    public static let escXBraceHex8 = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_X_BRACE_HEX8))

    /// \o{1OOOOOOOOOO}
    public static let escOBraceOctal = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP_ESC_O_BRACE_OCTAL))


    /// \Q...\E
    public static let escCapitalQQuote = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_Q_QUOTE) << 32)

    /// (?...)
    public static let qmarkGroupEffect = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_GROUP_EFFECT) << 32)

    /// (?imsx),(?-imsx)
    public static let optionPerl = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_OPTION_PERL) << 32)

    /// (?imx), (?-imx)
    public static let optionRuby = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_OPTION_RUBY) << 32)

    /// ?+,*+,++
    public static let plusPossessiveRepeat = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_REPEAT) << 32)

    /// {n,m}+
    public static let plusPossessiveInterval = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL) << 32)

    /// [...&&..[..]..]
    public static let cclassSetOp = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_CCLASS_SET_OP) << 32)

    /// (?<name>...)
    public static let qmarkLtNamedGroup = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP) << 32)

    /// \k<name>
    public static let escKNamedBackref = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_K_NAMED_BACKREF) << 32)

    /// \g<name>, \g<n>
    public static let escGSubexpCall = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_G_SUBEXP_CALL) << 32)

    /// (?@..),(?@<x>..)
    public static let atmarkCaptureHistory = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY) << 32)

    /// \C-x
    public static let escCapitalCBarControl = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_C_BAR_CONTROL) << 32)

    /// \M-x
    public static let escCapitalMBarMeta = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_M_BAR_META) << 32)

    /// \v as VTAB
    public static let escVVtab = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_V_VTAB) << 32)

    /// \uHHHH
    public static let escUHex4 = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_U_HEX4) << 32)

    /// \`, \'
    public static let escGnuBufAnchor = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_GNU_BUF_ANCHOR) << 32)

    /// \p{...}, \P{...}
    public static let escPBraceCharProperty = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CHAR_PROPERTY) << 32)

    /// \p{^..}, \P{^..}
    public static let escPBraceCircumflexNot = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT) << 32)


    /// \h, \H
    public static let escHXdigit = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_H_XDIGIT) << 32)

    /// \
    public static let ineffectiveEscape = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_INEFFECTIVE_ESCAPE) << 32)

    /// (?(n)) (?(...)...|...)
    public static let qmarkLparenIfElse = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE) << 32)

    /// \K
    public static let escCapitalKKeep = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_K_KEEP) << 32)

    /// \R \r\n else [\x0a-\x0d]
    public static let escCapitalRGeneralNewline = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE) << 32)

    /// \N (?-m:.), \O (?m:.)
    public static let escCapitalNOSuperDot = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT) << 32)

    /// (?~...)
    public static let qmarkTildeAbsentGroup = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_TILDE_ABSENT_GROUP) << 32)

    /// obsoleted: use next
    public static let escXYGraphemeCluster = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_GRAPHEME_CLUSTER) << 32)

    /// \X \y \Y
    public static let escXYTextSegment = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT) << 32)

    /// (?R), (?&name)...
    public static let qmarkPerlSubexpCall = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_PERL_SUBEXP_CALL) << 32)

    /// (?{...}) (?{{...}})
    public static let qmarkBraceCalloutContents = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS) << 32)

    /// (*name) (*name{a,..})
    public static let asteriskCalloutName = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME) << 32)

    /// (?imxWDSPy)
    public static let optionOniguruma = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_OPTION_ONIGURUMA) << 32)

//    /// (?P<name>...) (?P=name)
//    public static let qmarkCapitalPName = SyntaxOperator(rawValue: UInt64(ONIG_SYN_OP2_QMARK_CAPITAL_P_NAME) << 32)
    
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
