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

    /// Emacs syntax
    public static let emacs = Syntax(rawValue: OnigSyntaxEmacs)
    
    /// Grep syntax
    public static let grep = Syntax(rawValue: OnigSyntaxGrep)
    
    /// GNU regex syntax
    public static let gnuRegex = Syntax(rawValue: OnigSyntaxGnuRegex)
    
    /// Java syntax
    public static let java = Syntax(rawValue: OnigSyntaxJava)
    
    /// Perl syntax
    public static let perl = Syntax(rawValue: OnigSyntaxPerl)
    
    /// Perl + named group syntax
    public static let perlNg = Syntax(rawValue: OnigSyntaxPerl_NG)
    
    /// Ruby syntax
    public static let ruby = Syntax(rawValue: OnigSyntaxRuby)
    
    /// Oniguruma syntax
    public static let oniguruma = Syntax(rawValue: OnigSyntaxOniguruma)
    
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
     Get or set the operators for this syntax.
     */
    public var operators: SyntaxOperator {
        get {
            var onigSyntax = self.rawValue
            let op = onig_get_syntax_op(&onigSyntax)
            let op2 = onig_get_syntax_op2(&onigSyntax)
            return SyntaxOperator(onigSyntaxOp: op, onigSyntaxOp2: op2)
        }
        
        set {
            var onigSyntax = self.rawValue
            onig_set_syntax_op(&onigSyntax, newValue.onigSyntaxOp)
            onig_set_syntax_op2(&onigSyntax, newValue.onigSyntaxOp2)
            self.rawValue = onigSyntax
        }
    }
    
    /**
     Enable operators for this syntax.
     - Parameters:
        - operators: operators to be enabled.
     */
    public mutating func enableOperators(operators: SyntaxOperator) {
        var currentOperators = self.operators
        currentOperators.insert(operators)
        self.operators = currentOperators
    }
    
    /**
     Disable operators for this syntax.
     - Parameters:
        - operators: operators to be disabled.
     */
    public mutating func disableOperators(operators: SyntaxOperator) {
        var currentOperators = self.operators
        currentOperators.remove(operators)
        self.operators = currentOperators
    }
}
