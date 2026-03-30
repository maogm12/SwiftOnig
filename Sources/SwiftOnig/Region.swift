//
//  Region.swift
//
//
//  Created by Guangming Mao on 3/27/21.
//

import OnigurumaC
import Foundation

/// A raw match result returned by Oniguruma.
///
/// `Region` stores match results in encoded byte offsets. It is the primary result type for
/// raw-input APIs on `Regex` and `RegexSet`.
///
/// For string-native matching, prefer `Regex.Match`, which resolves the same match into
/// `String.Index` ranges and `Substring` values.
public struct Region: Sendable {
    internal typealias OnigRegionPointer = UnsafeMutablePointer<OnigRegion>

    internal final class Storage: @unchecked Sendable {
        let rawValue: OnigRegionPointer
        let regex: Regex
        let str: any OnigurumaString

        init(regex: Regex, str: any OnigurumaString) throws {
            guard let rawValue = onig_region_new() else {
                throw OnigError.memory
            }

            self.rawValue = rawValue
            self.regex = regex
            self.str = str
        }

        init(copying other: Storage) throws {
            guard let rawValue = onig_region_new() else {
                throw OnigError.memory
            }

            self.rawValue = rawValue
            self.regex = other.regex
            self.str = other.str
            onig_region_copy(rawValue, other.rawValue)
        }

        init(copying rawValue: OnigRegionPointer!, regex: Regex, str: any OnigurumaString) throws {
            guard let copiedRegion = onig_region_new() else {
                throw OnigError.memory
            }

            self.rawValue = copiedRegion
            self.regex = regex
            self.str = str
            onig_region_copy(copiedRegion, rawValue)
        }

        deinit {
            onig_region_free(rawValue, 1 /* free_self */)
        }
    }

    internal let storage: Storage

    internal var rawValue: OnigRegionPointer {
        storage.rawValue
    }

    /**
     The regular expression used in match operation.
     */
    internal var regex: Regex {
        storage.regex
    }

    /**
     The string matched against.
     */
    internal var str: any OnigurumaString {
        storage.str
    }

    /**
     Create an empty `Region`.
     - Parameter regex: The associated `Regex` object.
     - Parameter text: The string matched against.
     - Throws: `OnigError.memory` when failing to allocated memory for the new `Region`.
     */
    internal init(regex: Regex, str: any OnigurumaString) throws {
        self.storage = try Storage(regex: regex, str: str)
    }

    /**
     Create a new `Region` by copying from other `Region`.
     */
    internal init(copying other: Region) throws {
        self.storage = try Storage(copying: other.storage)
    }
    
    /**
     Create a new `Region` by coping from an exsiting oniguruma `OnigRegion` pointer.
     */
    internal init(copying rawValue: OnigRegionPointer!, regex: Regex, str: any OnigurumaString) throws {
        self.storage = try Storage(copying: rawValue, regex: regex, str: str)
    }

    /// The number of capture slots in the region, including slot `0` for the whole match.
    public var count: Int {
        Int(rawValue.pointee.num_regs)
    }
    

    /// The encoded byte range of the whole match.
    ///
    /// This is a convenience accessor for capture slot `0`.
    public var byteRange: Range<Int> {
        precondition(count > 0, "Empty region")
        return _activeRange(of: 0)
    }

    /// Converts the whole match into a Swift string range for the provided input.
    ///
    /// Pass the same `String` or `Substring` value that produced this match. The conversion
    /// returns `nil` when the regex encoding cannot be mapped back to valid `String.Index`
    /// boundaries for that input.
    public func range<S: StringProtocol>(in input: S) -> Range<S.Index>? {
        precondition(count > 0, "Empty region")
        return _stringRange(in: input, encodedRange: _activeRange(of: 0), encoding: regex.encoding)
    }

    /// Returns the whole matched substring from the provided input.
    ///
    /// Pass the same `String` or `Substring` value that produced this match.
    public func substring<S: StringProtocol>(in input: S) -> S.SubSequence? {
        guard let range = self.range(in: input) else {
            return nil
        }

        return input[range]
    }

    /// Decodes the matched bytes into a `String`.
    ///
    /// This convenience is useful for raw-input workflows and may allocate or perform
    /// character decoding.
    public func decodedString() -> String? {
        precondition(count > 0, "Empty region")
        return _substring(in: _activeRange(of: 0))
    }
    
    /// Resolves the numeric group used for a named backreference under Oniguruma semantics.
    public func backReferencedGroupNumber<S: StringProtocol>(of name: S) -> Int {
        let result = name.withOnigurumaString(requestedEncoding: regex.encoding) { start, count in
            onig_name_to_backref_number(regex.rawValue,
                                        start,
                                        start.advanced(by: count),
                                        rawValue)
        }
        return Int(result)
    }
}

// MARK: Subregion

/// The raw match result for a single capture group.
public struct Subregion: Sendable {
    /// The capture group number. `0` is the whole match.
    public let groupNumber: Int

    /// The encoded byte range of this capture group.
    public let byteRange: Range<Int>

    internal let regex: Regex
    internal let str: any OnigurumaString

    /// Decodes the matched bytes of this capture group into a `String`.
    public func decodedString() -> String? {
        str.withOnigurumaString(requestedEncoding: regex.encoding) { start, _ in
            String(bytes: UnsafeBufferPointer(start: start.advanced(by: byteRange.lowerBound),
                                             count: byteRange.count),
                   encoding: regex.encoding.stringEncoding)
        }
    }

    /// Converts this capture group's byte range into a Swift string range for the provided input.
    public func range<S: StringProtocol>(in input: S) -> Range<S.Index>? {
        _stringRange(in: input, encodedRange: byteRange, encoding: regex.encoding)
    }

    /// Returns this capture group's substring in the provided input.
    public func substring<S: StringProtocol>(in input: S) -> S.SubSequence? {
        guard let range = self.range(in: input) else {
            return nil
        }

        return input[range]
    }
}

extension Region: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = Subregion?

    public var startIndex: Int {
        0
    }

    public var endIndex: Int {
        count
    }

    /// Returns the subregion for a numeric capture group.
    ///
    /// Returns `nil` for optional groups that did not participate in the match.
    public subscript(groupNumber: Int) -> Subregion? {
        precondition(groupNumber >= 0 && groupNumber < count, "Group number \(groupNumber) out of range")
        
        if _isGroupActive(groupNumber: groupNumber) {
            return Subregion(groupNumber: groupNumber,
                             byteRange: _activeRange(of: groupNumber),
                             regex: regex,
                             str: str)
        } else {
            return nil
        }
    }

    /// Returns all participating capture groups associated with the provided name.
    public subscript<S: StringProtocol>(name: S) -> [Subregion] {
        let nameStr = String(name)
        return regex.captureGroupNumbers(for: nameStr)
            .compactMap { self[$0] }
    }
    
    private func _isGroupActive(groupNumber: Int) -> Bool {
        rawValue.pointee.beg[groupNumber] != ONIG_REGION_NOTPOS
    }

    private func _activeRange(of groupNumber: Int) -> Range<Int> {
        let begin = Int(rawValue.pointee.beg[groupNumber])
        let end = Int(rawValue.pointee.end[groupNumber])
        return begin..<end
    }

    private func _substring(in range: Range<Int>) -> String? {
        str.withOnigurumaString(requestedEncoding: regex.encoding) { start, _ in
            String(bytes: UnsafeBufferPointer(start: start.advanced(by: range.lowerBound),
                                             count: range.count),
                   encoding: regex.encoding.stringEncoding)
        }
    }
}

private func _stringRange<S: StringProtocol>(in input: S,
                                             encodedRange: Range<Int>,
                                             encoding: Encoding) -> Range<S.Index>? {
    switch encoding.stringEncoding {
    case .utf8:
        return _utf8StringRange(in: input, utf8Range: encodedRange)
    case .utf16BigEndian, .utf16LittleEndian:
        guard encodedRange.lowerBound.isMultiple(of: 2), encodedRange.upperBound.isMultiple(of: 2) else {
            return nil
        }

        return _utf16StringRange(in: input,
                                 utf16Range: (encodedRange.lowerBound / 2)..<(encodedRange.upperBound / 2))
    default:
        return nil
    }
}

private func _utf8StringRange<S: StringProtocol>(in input: S, utf8Range: Range<Int>) -> Range<S.Index>? {
    let utf8 = input.utf8
    guard let lowerBound = utf8.index(utf8.startIndex,
                                      offsetBy: utf8Range.lowerBound,
                                      limitedBy: utf8.endIndex),
          let upperBound = utf8.index(utf8.startIndex,
                                      offsetBy: utf8Range.upperBound,
                                      limitedBy: utf8.endIndex),
          let stringLowerBound = S.Index(lowerBound, within: input),
          let stringUpperBound = S.Index(upperBound, within: input) else {
        return nil
    }

    return stringLowerBound..<stringUpperBound
}

private func _utf16StringRange<S: StringProtocol>(in input: S, utf16Range: Range<Int>) -> Range<S.Index>? {
    let utf16 = input.utf16
    guard let lowerBound = utf16.index(utf16.startIndex,
                                       offsetBy: utf16Range.lowerBound,
                                       limitedBy: utf16.endIndex),
          let upperBound = utf16.index(utf16.startIndex,
                                       offsetBy: utf16Range.upperBound,
                                       limitedBy: utf16.endIndex),
          let stringLowerBound = S.Index(lowerBound, within: input),
          let stringUpperBound = S.Index(upperBound, within: input) else {
        return nil
    }

    return stringLowerBound..<stringUpperBound
}
