//
//  Encoding.swift
//  
//
//  Created by Guangming Mao on 4/3/21.
//

import OnigurumaC
import CoreFoundation
import Foundation

public struct Encoding: Equatable, CustomStringConvertible, Sendable {
    private struct BuiltInEncodingMapping: @unchecked Sendable {
        let onigEncoding: OnigEncoding
        let stringEncoding: String.Encoding
    }

    internal nonisolated(unsafe) let rawValue: OnigEncoding!

    /// The `String.Encoding` of the corresponding oniguruma encoding.
    public let stringEncoding: String.Encoding

    /**
     Create a `Encoding` with oniguruma `OnigEncoding` pointer.
     
     The `stringEncoding` is populated with a internal map, which only support built-in `OnigEncoding`.
     - Parameter rawValue: The raw oniguruma `OnigEncoding` pointer.
     */
    internal init(rawValue: OnigEncoding!) {
        self.rawValue = rawValue
        self.stringEncoding = Encoding._stringEncoding(from: self.rawValue)
    }

    /// ACSII
    public static var ascii: Encoding { Encoding(rawValue: get_onig_ascii()) }

    /// ISO/IEC 8859-1, Latin-1, Western European
    public static var iso8859Part1: Encoding { Encoding(rawValue: get_onig_iso8859_1()) }

    /// ISO/IEC 8859-2, Latin-2, Central European
    public static var iso8859Part2: Encoding { Encoding(rawValue: get_onig_iso8859_2()) }

    /// ISO/IEC 8859-3, Latin-3, South European
    public static var iso8859Part3: Encoding { Encoding(rawValue: get_onig_iso8859_3()) }

    /// ISO/IEC 8859-4, Latin-4, North European
    public static var iso8859Part4: Encoding { Encoding(rawValue: get_onig_iso8859_4()) }

    /// ISO/IEC 8859-5, Latin/Cyrillic
    public static var iso8859Part5: Encoding { Encoding(rawValue: get_onig_iso8859_5()) }

    /// ISO/IEC 8859-6, Latin/Arabic
    public static var iso8859Part6: Encoding { Encoding(rawValue: get_onig_iso8859_6()) }

    /// ISO/IEC 8859-7, Latin/Greek
    public static var iso8859Part7: Encoding { Encoding(rawValue: get_onig_iso8859_7()) }

    /// ISO/IEC 8859-8, Latin/Hebrew
    public static var iso8859Part8: Encoding { Encoding(rawValue: get_onig_iso8859_8()) }

    /// ISO/IEC 8859-9, Latin-5/Turkish
    public static var iso8859Part9: Encoding { Encoding(rawValue: get_onig_iso8859_9()) }

    /// ISO/IEC 8859-10, Latin-6, Nordic
    public static var iso8859Part10: Encoding { Encoding(rawValue: get_onig_iso8859_10()) }

    /// ISO/IEC 8859-11, Latin/Thai
    public static var iso8859Part11: Encoding { Encoding(rawValue: get_onig_iso8859_11()) }

    /// ISO/IEC 8859-13, Latin-7, Baltic Rim
    public static var iso8859Part13: Encoding { Encoding(rawValue: get_onig_iso8859_13()) }

    /// ISO/IEC 8859-14, Latin-8, Celtic
    public static var iso8859Part14: Encoding { Encoding(rawValue: get_onig_iso8859_14()) }

    /// ISO/IEC 8859-15, Latin-9
    public static var iso8859Part15: Encoding { Encoding(rawValue: get_onig_iso8859_15()) }

    /// ISO/IEC 8859-16, Latin-10, South-Eastern European
    public static var iso8859Part16: Encoding { Encoding(rawValue: get_onig_iso8859_16()) }
    
    /// UTF-8
    public static var utf8: Encoding { Encoding(rawValue: get_onig_utf8()) }
    
    /// UTF-16 big endian
    public static var utf16BigEndian: Encoding { Encoding(rawValue: get_onig_utf16be()) }
    
    /// UTF-16 little endian
    public static var utf16LittleEndian: Encoding { Encoding(rawValue: get_onig_utf16le()) }
    
    /// UTF-32 big endian
    public static var utf32BigEndian: Encoding { Encoding(rawValue: get_onig_utf32be()) }
    
    /// UTF-32 little endian
    public static var utf32LittleEndian: Encoding { Encoding(rawValue: get_onig_utf32le()) }
    
    /// EUC JP
    public static var eucJP: Encoding { Encoding(rawValue: get_onig_eucjp()) }
    
    /// EUC TW
    public static var eucTW: Encoding { Encoding(rawValue: get_onig_euctw()) }

    /// EUC KR
    public static var eucKR: Encoding { Encoding(rawValue: get_onig_euckr()) }

    /// EUC CN
    public static var eucCN: Encoding { Encoding(rawValue: get_onig_euccn()) }

    /// Shift JIS
    public static var shiftJIS: Encoding { Encoding(rawValue: get_onig_sjis()) }
    
    /// KOI8-R
    public static var koi8r: Encoding { Encoding(rawValue: get_onig_koi8r()) }
    
    /// CP1251, Windows-1251
    public static var cp1251: Encoding { Encoding(rawValue: get_onig_cp1251()) }
    
    /// BIG 5
    public static var big5: Encoding { Encoding(rawValue: get_onig_big5()) }
    
    /// GB 18030
    public static var gb18030: Encoding { Encoding(rawValue: get_onig_gb18030()) }

    /// Get or set the default encoding
    @OnigurumaActor
    public static var `default`: Encoding {
        get {
            Encoding(rawValue: onigenc_get_default_encoding())
        }

        set {
            _ = onigenc_set_default_encoding(newValue.rawValue)
        }
    }
    
    public var description: String {
        self.stringEncoding.description
    }

    private static let builtInEncodingMappings: [BuiltInEncodingMapping] = [
        BuiltInEncodingMapping(onigEncoding: get_onig_ascii(), stringEncoding: .ascii),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_1(), stringEncoding: .isoLatin1),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_2(), stringEncoding: .isoLatin2),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_3(), stringEncoding: String.Encoding.SwiftOnig.isoLatin3),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_4(), stringEncoding: String.Encoding.SwiftOnig.isoLatin4),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_5(), stringEncoding: String.Encoding.SwiftOnig.isoLatinCyrillic),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_6(), stringEncoding: String.Encoding.SwiftOnig.isoLatinArabic),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_7(), stringEncoding: String.Encoding.SwiftOnig.isoLatinGreek),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_8(), stringEncoding: String.Encoding.SwiftOnig.isoLatinHebrew),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_9(), stringEncoding: String.Encoding.SwiftOnig.isoLatin5),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_10(), stringEncoding: String.Encoding.SwiftOnig.isoLatin6),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_11(), stringEncoding: String.Encoding.SwiftOnig.isoLatinThai),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_13(), stringEncoding: String.Encoding.SwiftOnig.isoLatin7),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_14(), stringEncoding: String.Encoding.SwiftOnig.isoLatin8),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_15(), stringEncoding: String.Encoding.SwiftOnig.isoLatin9),
        BuiltInEncodingMapping(onigEncoding: get_onig_iso8859_16(), stringEncoding: String.Encoding.SwiftOnig.isoLatin10),
        BuiltInEncodingMapping(onigEncoding: get_onig_utf8(), stringEncoding: .utf8),
        BuiltInEncodingMapping(onigEncoding: get_onig_utf16be(), stringEncoding: .utf16BigEndian),
        BuiltInEncodingMapping(onigEncoding: get_onig_utf16le(), stringEncoding: .utf16LittleEndian),
        BuiltInEncodingMapping(onigEncoding: get_onig_utf32be(), stringEncoding: .utf32BigEndian),
        BuiltInEncodingMapping(onigEncoding: get_onig_utf32le(), stringEncoding: .utf32LittleEndian),
        BuiltInEncodingMapping(onigEncoding: get_onig_eucjp(), stringEncoding: .japaneseEUC),
        BuiltInEncodingMapping(onigEncoding: get_onig_euctw(), stringEncoding: String.Encoding.SwiftOnig.eucTW),
        BuiltInEncodingMapping(onigEncoding: get_onig_euckr(), stringEncoding: String.Encoding.SwiftOnig.euckr),
        BuiltInEncodingMapping(onigEncoding: get_onig_euccn(), stringEncoding: String.Encoding.SwiftOnig.euccn),
        BuiltInEncodingMapping(onigEncoding: get_onig_sjis(), stringEncoding: .shiftJIS),
        BuiltInEncodingMapping(onigEncoding: get_onig_koi8r(), stringEncoding: String.Encoding.SwiftOnig.koi8r),
        BuiltInEncodingMapping(onigEncoding: get_onig_cp1251(), stringEncoding: .windowsCP1251),
        BuiltInEncodingMapping(onigEncoding: get_onig_big5(), stringEncoding: String.Encoding.SwiftOnig.big5),
        BuiltInEncodingMapping(onigEncoding: get_onig_gb18030(), stringEncoding: String.Encoding.SwiftOnig.gb18030),
    ]

    /**
     Map `Encoding`to `String.Encoding`, only built-in encodings are supported.
     */
    private static func _stringEncoding(from onigEncoding: OnigEncoding) -> String.Encoding {
        if let mapping = builtInEncodingMappings.first(where: { $0.onigEncoding == onigEncoding }) {
            return mapping.stringEncoding
        }

        fatalError("Unexpected encoding")
    }

    /**
     Return the previous character head before the given byte offset, or `nil` if there is no previous character.
     */
    public func previousCharacterHead<S>(in bytes: S, before index: Int) -> Int? where S: Sequence, S.Element == UInt8 {
        withContiguousBytes(bytes) { start, count in
            precondition((0...count).contains(index), "Index out of bounds")
            guard let previous = onigenc_get_prev_char_head(self.rawValue, start, start.advanced(by: index)) else {
                return nil
            }
            return start.distance(to: previous)
        }
    }

    /**
     Return the left-adjusted character head at or before the given byte offset.
     */
    public func leftAdjustedCharacterHead<S>(in bytes: S, at index: Int) -> Int where S: Sequence, S.Element == UInt8 {
        withContiguousBytes(bytes) { start, count in
            precondition((0...count).contains(index), "Index out of bounds")
            let adjusted = onigenc_get_left_adjust_char_head(self.rawValue, start, start.advanced(by: index))!
            return start.distance(to: adjusted)
        }
    }

    /**
     Return the right-adjusted character head at or after the given byte offset.
     */
    public func rightAdjustedCharacterHead<S>(in bytes: S, at index: Int) -> Int where S: Sequence, S.Element == UInt8 {
        withContiguousBytes(bytes) { start, count in
            precondition((0...count).contains(index), "Index out of bounds")
            let adjusted = onigenc_get_right_adjust_char_head(self.rawValue, start, start.advanced(by: index))!
            return start.distance(to: adjusted)
        }
    }

    /**
     Return the number of encoded characters in the provided byte sequence.
     */
    public func characterCount<S>(in bytes: S) -> Int where S: Sequence, S.Element == UInt8 {
        withContiguousBytes(bytes) { start, count in
            Int(onigenc_strlen(self.rawValue, start, start.advanced(by: count)))
        }
    }

    /**
     Return the number of encoded characters in the provided bytes, treated as null-terminated.
     */
    public func nullTerminatedCharacterCount<S>(in bytes: S) -> Int where S: Sequence, S.Element == UInt8 {
        withNullTerminatedBytes(bytes) { start in
            Int(onigenc_strlen_null(self.rawValue, start))
        }
    }

    /**
     Return the byte length of the provided bytes, treated as null-terminated.
     */
    public func nullTerminatedByteCount<S>(in bytes: S) -> Int where S: Sequence, S.Element == UInt8 {
        withNullTerminatedBytes(bytes) { start in
            Int(onigenc_str_bytelen_null(self.rawValue, start))
        }
    }

    private func withContiguousBytes<S, Result>(_ bytes: S, _ body: (UnsafePointer<OnigUChar>, Int) -> Result) -> Result where S: Sequence, S.Element == UInt8 {
        let contiguous = ContiguousArray(bytes)
        return contiguous.withUnsafeBufferPointer { buffer in
            let baseAddress = buffer.baseAddress ?? UnsafePointer<UInt8>(bitPattern: 0x1)!
            return body(baseAddress, buffer.count)
        }
    }

    private func withNullTerminatedBytes<S, Result>(_ bytes: S, _ body: (UnsafePointer<OnigUChar>) -> Result) -> Result where S: Sequence, S.Element == UInt8 {
        var contiguous = ContiguousArray(bytes)
        contiguous.append(0)
        return contiguous.withUnsafeBufferPointer { buffer in
            let baseAddress = buffer.baseAddress ?? UnsafePointer<UInt8>(bitPattern: 0x1)!
            return body(baseAddress)
        }
    }
}

extension String.Encoding {
    public struct SwiftOnig {
        static let isoLatinThai = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatinThai.rawValue)))
        static let isoLatin8 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin8.rawValue)))
        static let isoLatin9 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin9.rawValue)))
        static let isoLatin10 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin10.rawValue)))
        static let isoLatin3 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin3.rawValue)))
        static let isoLatin4 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin4.rawValue)))
        static let isoLatinCyrillic = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin5.rawValue)))
        static let isoLatinArabic = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin6.rawValue)))
        static let isoLatinGreek = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin7.rawValue)))
        static let isoLatinHebrew = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin8.rawValue)))
        static let isoLatin5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin5.rawValue)))
        static let isoLatin6 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin6.rawValue)))
        static let isoLatin7 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.isoLatin7.rawValue)))

        static let eucTW = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_TW.rawValue)))
        static let euckr = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)))
        static let euccn = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_CN.rawValue)))
        
        static let koi8r = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.KOI8_R.rawValue)))
        static let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        static let big5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
    }
}
