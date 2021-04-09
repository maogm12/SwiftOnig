//
//  RegexSet.swift
//  
//
//  Created by Gavin Mao on 4/2/21.
//

import COnig

final public class RegexSet {
    internal typealias OnigRegSet = OpaquePointer
    internal private(set) var rawValue: OnigRegSet!
    
    /**
     Cached regexes.
     */
    private var regexes = [Regex]()
    
    public init() {
        onig_regset_new(&self.rawValue, 0, nil)
    }

    public convenience init<S: Sequence>(_ regexes: S) throws where S.Element == Regex {
        self.init()
        for reg in regexes {
            do {
                try callOnigFunction{
                    onig_regset_add(self.rawValue, reg.rawValue)
                }
                
                self.regexes.append(reg)
            } catch {
                self.cleanUp()
                throw error
            }
        }
    }
    
    deinit {
        self.cleanUp()
    }
    
    /**
     Remove all regex objects.
     */
    public func removeAll() {
        if self.rawValue != nil {
            for i in (0..<self.count).reversed() {
                // mark all regex object in the regset to be nil
                onig_regset_replace(self.rawValue, OnigInt(i), nil)
            }
        }
        
        if !self.regexes.isEmpty {
            self.regexes.removeAll()
        }
    }
    
    /**
     Remvoe the regex object at specific index.
     - Parameter index: The index of the regex object to be removed.
     */
    public func remove(at index: Int) {
        onig_regset_replace(self.rawValue, OnigInt(index), nil)
        self.regexes.remove(at: index)
    }

    /**
     Add a `Regex` object into the `RegexSet`.
     - Note:
         1. The `Regex` object must have the same character encoding with the `RegexSet`.
         2. The `Regex` object is prohibited from having the `Regex.Options.findLongest` option.
     - Parameters:
        - newElement: The new `Regex` object to append to the `RegexSet`.
     - Throws: `OnigError`
     */
    public func append(_ newElement: Regex) throws {
        try callOnigFunction {
            onig_regset_add(self.rawValue, newElement.rawValue)
        }
        self.regexes.append(newElement)
    }
    
    /**
     Replace regex object at specific index.
     - TODO:
     Swift as of now (04/02/2021) doesn't support throwing subscripts, here is the task tracking it: <https://bugs.swift.org/browse/SR-238>.
     Once it's supported, should move this to `subscript`.
     - Parameters:
        - index: the index of the regex object to be replaced.
        - newElement: the new element put in this index.
     - Throws:
        `OnigError` if `onig_regset_replace` falied.
     */
    public func replace(regexAt index: Int, with newElement: Regex) throws {
        if index < 0 || index >= self.endIndex {
            return
        }

        try callOnigFunction {
            onig_regset_replace(self.rawValue, OnigInt(index), newElement.rawValue)
        }
        self.regexes[index] = newElement
    }

    /**
     Get the region object corresponding to the regex at specific index..
     - Parameters:
        - index: the index.
     */
    public func region(at index: Int) -> Region! {
        precondition(self.isIndexValid(index: index), "Invalid index in RegexSet")
        return Region(rawValue: onig_regset_get_region(self.rawValue, OnigInt(index)),
                      regex: self.regexes[index])
    }
    
    /**
     Perform a search in the target string.
     - Parameters:
        - str: The target string to search in.
        - lead: Outer loop element, Both `.positionLead` and `.regexLead` gurantee to return the *true* left most matched position, but in most cases `.positionLead` seems to be faster. `.priorityToRegexOrder` gurantee the returned regex index is the index of the *first* regex that coult match..
        - option: Search time option
        - matchParams: Match patams, count **must** be equal to count of regex, one match params for one regex in corresponding index.
     - Returns:
        A tuple of matched regex index and first matched index the string UTF-8 bytes. View `Lead` for more detailed information. `nil` if no regex matches.
     - Throws:
        `OnigError` if `matchParams` is not `nil` but count doesn't match the count of regex objects, or `onig_regset_search` returns error.
     */
    public func search<S: StringProtocol>(in str: S, lead: Lead, option: Regex.SearchOptions = .none, matchParams: [MatchParam]? = nil) throws -> (regexIndex: Int, utf8BytesIndex: Int)? {
        try self.search(in: str,
                        of: 0...,
                        lead: lead,
                        option: option,
                        matchParams: nil)
    }

    /**
     Perform a search in a range of the target string.
     - Parameters:
        - str: The target string to search in.
        - utf8BytesRange: The range of UTF-8 byte index representation of the target string. It will be clamped to the range of the whole string first.
        - lead: Outer loop element, Both `.positionLead` and `.regexLead` gurantee to return the *true* left most matched position, but in most cases `.positionLead` seems to be faster. `.priorityToRegexOrder` gurantee the returned regex index is the index of the *first* regex that coult match..
        - option: Search time option
        - matchParams: Match patams, count **must** be equal to count of regex, one match params for one regex in corresponding index.
     - Returns:
        A tuple of matched regex index and first matched index the string UTF-8 bytes. View `Lead` for more detailed information. `nil` if no regex matches.
     - Throws:
        `OnigError` if `matchParams` is not `nil` but count doesn't match the count of regex objects, or `onig_regset_search` returns error.
     */
    public func search<S: StringProtocol, R: RangeExpression>(in str: S, of utf8BytesRange: R, lead: Lead, option: Regex.SearchOptions = .none, matchParams: [MatchParam]? = nil) throws -> (regexIndex: Int, utf8BytesIndex: Int)? where R.Bound == Int {
        try self.search(in: str,
                        of: utf8BytesRange.relative(to: 0..<str.utf8.count),
                        lead: lead,
                        option: option,
                        matchParams: nil)
    }

    /**
     Perform a search in a range of the target string.
     - Parameters:
        - str: The target string to search in.
        - utf8BytesRange: The range of UTF-8 byte index representation of the target string. It will be clamped to the range of the whole string first.
        - lead: Outer loop element, Both `.positionLead` and `.regexLead` gurantee to return the *true* left most matched position, but in most cases `.positionLead` seems to be faster. `.priorityToRegexOrder` gurantee the returned regex index is the index of the *first* regex that coult match..
        - option: Search time option
        - matchParams: Match patams, count **must** be equal to count of regex, one match params for one regex in corresponding index.
     - Returns:
        A tuple of matched regex index and first matched index the string UTF-8 bytes. View `Lead` for more detailed information. `nil` if no regex matches.
     - Throws:
        `OnigError` if `matchParams` is not `nil` but count doesn't match the count of regex objects, or `onig_regset_search` returns error.
     */
    public func search<S: StringProtocol>(in str: S, of utf8BytesRange: Range<Int>, lead: Lead, option: Regex.SearchOptions = .none, matchParams: [MatchParam]? = nil) throws -> (regexIndex: Int, utf8BytesIndex: Int)? {
        guard matchParams == nil || matchParams!.count == self.count else {
            throw OnigError.invalidArgument
        }

        let byteCount = str.utf8.count
        let range = utf8BytesRange.clamped(to: 0..<byteCount)
        var bytesIndex: OnigInt = 0

        let result = try callOnigFunction {
            str.withCString {
                $0.withMemoryRebound(to: OnigUChar.self, capacity: byteCount) { strPtr -> OnigInt in
                    if let matchParams = matchParams {
                        let mps = UnsafeMutableBufferPointer<OpaquePointer?>.allocate(capacity: matchParams.count)
                        _ = mps.initialize(from: matchParams.map{ (matchParams) -> OpaquePointer? in
                            matchParams.rawValue
                        })
                        defer {
                            mps.deallocate()
                        }

                        return onig_regset_search_with_param(self.rawValue,
                                                             strPtr,
                                                             strPtr.advanced(by: byteCount),
                                                             strPtr.advanced(by: range.lowerBound),
                                                             strPtr.advanced(by: range.upperBound),
                                                             lead.onigRegSetLead,
                                                             option.rawValue,
                                                             mps.baseAddress,
                                                             &bytesIndex)
                    } else {
                        return onig_regset_search(self.rawValue,
                                                  strPtr,
                                                  strPtr.advanced(by: byteCount),
                                                  strPtr.advanced(by: range.lowerBound),
                                                  strPtr.advanced(by: range.upperBound),
                                                  lead.onigRegSetLead,
                                                  option.rawValue,
                                                  &bytesIndex)
                    }
                }
            }
        }
    
        if result == ONIG_MISMATCH {
            return nil
        } else {
            return(regexIndex: Int(result), utf8BytesIndex: Int(bytesIndex))
        }
    }
    
    

    /**
     Clean up oniruguma regset object and cached `Regex`.
     */
    private func cleanUp() {
        self.removeAll()

        if self.rawValue != nil {
            onig_regset_free(self.rawValue)
            self.rawValue = nil
        }
    }
    
    /**
     Is given index a valid index.
     - Parameters:
        - index: the index to check.
     */
    private func isIndexValid(index: Int) -> Bool {
        index >= self.startIndex && index < self.endIndex
    }
    
    /**
     Out loop element when performing search.
     */
    public enum Lead {
        /**
         When performing the search, the outer loop is for positons of the string, once some of the regex matches from this position, it returns, so it gurantees the returned first matched index is indeed the first position some of the regex could match.
         */
        case positionLead
        /**
         When performing the search, the outer loop is for indexes of regex objects, and return the most left matched position, it also gurantees the return first matched index is the first position some of the regex could matches.
         */
        case regexLead
        /**
         When performing the search, the outer loop is for indexes of regex objects, once one regex matches, it returns, so it gurantees the returned matched regex is the first regex that matches, but the return first matched index might not be the first position some of the regex could matches.
         */
        case priorityToRegexOrder
        
        public var onigRegSetLead: OnigRegSetLead {
            switch self {
            case .positionLead:
                return ONIG_REGSET_POSITION_LEAD
            case .regexLead:
                return ONIG_REGSET_REGEX_LEAD
            case .priorityToRegexOrder:
                return ONIG_REGSET_PRIORITY_TO_REGEX_ORDER
            }
        }
    }
}

extension RegexSet : RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Regex
    
    public var startIndex: Int {
        return 0
    }
    
    public var endIndex: Int {
        return Int(onig_regset_number_of_regex(self.rawValue))
    }

    public subscript(position: Int) -> Regex {
        return self.regexes[position]
    }
}
