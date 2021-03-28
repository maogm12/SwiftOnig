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
    
    /// String head isn't considered as begin of line.
    public static let notBol = SearchOptions(rawValue: ONIG_OPTION_NOTBOL);

    /// String end isn't considered as end of line.
    public static let notEol = SearchOptions(rawValue: ONIG_OPTION_NOTEOL);
}
