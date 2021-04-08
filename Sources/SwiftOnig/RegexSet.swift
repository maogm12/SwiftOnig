//
//  RegexSet.swift
//  
//
//  Created by Gavin Mao on 4/2/21.
//

import COnig

public struct RegexSet {
    /**
     Internal storage of the regex set, it holds the pointer of a oniguruma regset and cached `Regex` array.
     */
    final internal class Storage {
        internal typealias OnigRegSet = OpaquePointer
        internal private(set) var rawValue: OnigRegSet!
        
        /**
         Cached `Regex` objects to make sure oniguruma objects are not freed.
         */
        internal var regexes = [Regex]()
        
        internal init() {
            onig_regset_new(&self.rawValue, 0, nil)
        }
        
        internal convenience init<S: Sequence>(_ regexes: S) throws where S.Element == Regex {
            self.init()
            for reg in regexes {
                do {
                    try callOnigFunction {
                        onig_regset_add(self.rawValue, reg.storage.rawValue)
                    }
                    self.regexes.append(reg)
                } catch {
                    self.cleanUp()
                    throw error
                }
            }
        }

        /**
         Create a `Storage` object by copying from other `Storage`.
         */
        internal convenience init(from other: Storage) {
            // These values are already added, so shouldn't throw
            try! self.init(other.regexes)
        }

        deinit {
            self.cleanUp()
        }
    
        /**
         Remove all regex objects.
         */
        internal func removeAll() {
            for i in (0..<self.regexes.count).reversed() {
                // mark all regex object in the regset to be nil
                onig_regset_replace(self.rawValue, Int32(i), nil)
            }
            
            self.regexes.removeAll()
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
        internal func append(_ newElement: Regex) throws {
            try callOnigFunction {
                onig_regset_add(self.rawValue, newElement.storage.rawValue)
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
        internal func replace(regexAt index: Int, with newElement: Regex) throws {
            if index < 0 || index >= self.count {
                return
            }

            try callOnigFunction {
                onig_regset_replace(self.rawValue, OnigInt(index), newElement.storage.rawValue)
            }

            self.regexes[index] = newElement
        }
        
        /**
         Remove the regex object at specific index.
         - Parameter index: The index of the regex object to be removed.
         */
        internal func remove(at index: Int) {
            if index < 0 || index >= self.count {
                return
            }

            onig_regset_replace(self.rawValue, OnigInt(index), nil)
            self.regexes.remove(at: index)
        }

        /**
         Get count of regex object in the storage.
         */
        internal var count: Int {
            Int(onig_regset_number_of_regex(self.rawValue))
        }
        
        internal subscript(position: Int) -> Regex {
            return self.regexes[position]
        }

        /**
         Clean up oniruguma regset object and cached `Regex`.
         */
        private func cleanUp() {
            if self.rawValue != nil {
                self.removeAll()
                onig_regset_free(self.rawValue)
                self.rawValue = nil
            }
        }
    }
    
    internal var storage: Storage

    public init() {
        self.storage = Storage()
    }
    
    public init<S: Sequence>(_ regexes: S) throws where S.Element == Regex {
        self.storage = try Storage(regexes)
    }

    /**
     Get the region object corresponding to the regex at specific index..
     - Parameters:
        - index: the index.
     */
    public func region(at index: Int) -> Region? {
        if self.storage.rawValue == nil {
            return nil
        }
        
        if !self.isIndexValid(index: index) {
            return nil
        }
        
        if let onigRegionPtr = onig_regset_get_region(self.storage.rawValue, OnigInt(index)) {
            return Region(rawValue: onigRegionPtr.pointee)
        }
        
        return nil
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

                        return onig_regset_search_with_param(self.storage.rawValue,
                                                             strPtr,
                                                             strPtr.advanced(by: byteCount),
                                                             strPtr.advanced(by: range.lowerBound),
                                                             strPtr.advanced(by: range.upperBound),
                                                             lead.onigRegSetLead,
                                                             option.rawValue,
                                                             mps.baseAddress,
                                                             &bytesIndex)
                    } else {
                        return onig_regset_search(self.storage.rawValue,
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
    
    /**
     If the storage is shared with others, create a owned copy.
     - Parameter copyContent: Copy regexes in old storage to the owned storage if `true`.
     */
    private mutating func makeUniqueIfNotUnique(copyContent: Bool) {
        if !isKnownUniquelyReferenced(&self.storage) {
            if copyContent {
                self.storage = Storage(from: self.storage)
            } else {
                self.storage = Storage()
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
        return self.storage.count
    }

    public subscript(position: Int) -> Regex {
        return self.storage[position]
    }
}

// mutating
extension RegexSet {
    /**
     Remove all regex objects.
     */
    public mutating func removeAll() {
        self.makeUniqueIfNotUnique(copyContent: false)
        self.storage.removeAll()
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
    public mutating func append(_ newElement: Regex) throws {
        self.makeUniqueIfNotUnique(copyContent: true)
        try self.storage.append(newElement)
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
    public mutating func replace(regexAt index: Int, with newElement: Regex) throws {
        self.makeUniqueIfNotUnique(copyContent: true)
        try self.storage.replace(regexAt: index, with: newElement)
    }
    
    /**
     Remove the regex object at specific index.
     - Parameter index: The index of the regex object to be removed.
     */
    public mutating func remove(at index: Int) {
        self.makeUniqueIfNotUnique(copyContent: true)
        self.storage.remove(at: index)
    }
}
