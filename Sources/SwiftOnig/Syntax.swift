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
public struct Syntax {
    var rawValue: OnigSyntaxType
    
    /// Plain text syntax
    public static let asis = Syntax(rawValue: OnigSyntaxASIS)
    
    /// POSIX Basic RE syntax
    public static let posixBasic = Syntax(rawValue: OnigSyntaxPosixBasic)
    
    /// POSIX Extended RE syntax
    public static let posixExtended = Syntax(rawValue: OnigSyntaxPosixExtended)

    public static var `default`: Syntax {
        get {
            return Syntax(rawValue: OnigDefaultSyntax.pointee)
        }
    }
}
