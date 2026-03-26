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
    @OnigurumaActor public static var ascii: Encoding { Encoding(rawValue: get_onig_ascii()) }

    /// ISO/IEC 8859-1, Latin-1, Western European
    @OnigurumaActor public static var iso8859Part1: Encoding { Encoding(rawValue: get_onig_iso8859_1()) }

    /// ISO/IEC 8859-2, Latin-2, Central European
    @OnigurumaActor public static var iso8859Part2: Encoding { Encoding(rawValue: get_onig_iso8859_2()) }

    /// ISO/IEC 8859-3, Latin-3, South European
    @OnigurumaActor public static var iso8859Part3: Encoding { Encoding(rawValue: get_onig_iso8859_3()) }

    /// ISO/IEC 8859-4, Latin-4, North European
    @OnigurumaActor public static var iso8859Part4: Encoding { Encoding(rawValue: get_onig_iso8859_4()) }

    /// ISO/IEC 8859-5, Latin/Cyrillic
    @OnigurumaActor public static var iso8859Part5: Encoding { Encoding(rawValue: get_onig_iso8859_5()) }

    /// ISO/IEC 8859-6, Latin/Arabic
    @OnigurumaActor public static var iso8859Part6: Encoding { Encoding(rawValue: get_onig_iso8859_6()) }

    /// ISO/IEC 8859-7, Latin/Greek
    @OnigurumaActor public static var iso8859Part7: Encoding { Encoding(rawValue: get_onig_iso8859_7()) }

    /// ISO/IEC 8859-8, Latin/Hebrew
    @OnigurumaActor public static var iso8859Part8: Encoding { Encoding(rawValue: get_onig_iso8859_8()) }

    /// ISO/IEC 8859-9, Latin-5/Turkish
    @OnigurumaActor public static var iso8859Part9: Encoding { Encoding(rawValue: get_onig_iso8859_9()) }

    /// ISO/IEC 8859-10, Latin-6, Nordic
    @OnigurumaActor public static var iso8859Part10: Encoding { Encoding(rawValue: get_onig_iso8859_10()) }

    /// ISO/IEC 8859-11, Latin/Thai
    @OnigurumaActor public static var iso8859Part11: Encoding { Encoding(rawValue: get_onig_iso8859_11()) }

    /// ISO/IEC 8859-13, Latin-7, Baltic Rim
    @OnigurumaActor public static var iso8859Part13: Encoding { Encoding(rawValue: get_onig_iso8859_13()) }

    /// ISO/IEC 8859-14, Latin-8, Celtic
    @OnigurumaActor public static var iso8859Part14: Encoding { Encoding(rawValue: get_onig_iso8859_14()) }

    /// ISO/IEC 8859-15, Latin-9
    @OnigurumaActor public static var iso8859Part15: Encoding { Encoding(rawValue: get_onig_iso8859_15()) }

    /// ISO/IEC 8859-16, Latin-10, South-Eastern European
    @OnigurumaActor public static var iso8859Part16: Encoding { Encoding(rawValue: get_onig_iso8859_16()) }
    
    /// UTF-8
    @OnigurumaActor public static var utf8: Encoding { Encoding(rawValue: get_onig_utf8()) }
    
    /// UTF-16 big endian
    @OnigurumaActor public static var utf16BigEndian: Encoding { Encoding(rawValue: get_onig_utf16be()) }
    
    /// UTF-16 little endian
    @OnigurumaActor public static var utf16LittleEndian: Encoding { Encoding(rawValue: get_onig_utf16le()) }
    
    /// UTF-32 big endian
    @OnigurumaActor public static var utf32BigEndian: Encoding { Encoding(rawValue: get_onig_utf32be()) }
    
    /// UTF-32 little endian
    @OnigurumaActor public static var utf32LittleEndian: Encoding { Encoding(rawValue: get_onig_utf32le()) }
    
    /// EUC JP
    @OnigurumaActor public static var eucJP: Encoding { Encoding(rawValue: get_onig_eucjp()) }
    
    /// EUC TW
    @OnigurumaActor public static var eucTW: Encoding { Encoding(rawValue: get_onig_euctw()) }

    /// EUC KR
    @OnigurumaActor public static var eucKR: Encoding { Encoding(rawValue: get_onig_euckr()) }

    /// EUC CN
    @OnigurumaActor public static var eucCN: Encoding { Encoding(rawValue: get_onig_euccn()) }

    /// Shift JIS
    @OnigurumaActor public static var shiftJIS: Encoding { Encoding(rawValue: get_onig_sjis()) }
    
    /// KOI8-R
    @OnigurumaActor public static var koi8r: Encoding { Encoding(rawValue: get_onig_koi8r()) }
    
    /// CP1251, Windows-1251
    @OnigurumaActor public static var cp1251: Encoding { Encoding(rawValue: get_onig_cp1251()) }
    
    /// BIG 5
    @OnigurumaActor public static var big5: Encoding { Encoding(rawValue: get_onig_big5()) }
    
    /// GB 18030
    @OnigurumaActor public static var gb18030: Encoding { Encoding(rawValue: get_onig_gb18030()) }

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

    /**
     Map `Encoding`to `String.Encoding`, only built-in encodings are supported.
     */
    private static func _stringEncoding(from onigEncoding: OnigEncoding) -> String.Encoding {
        if (onigEncoding == get_onig_ascii()) { // ACSII
            return .ascii
        } else if (onigEncoding == get_onig_iso8859_1()) { // ISO/IEC 8859-1, Latin-1, Western European
            return .isoLatin1
        } else if (onigEncoding == get_onig_iso8859_2()) { // ISO/IEC 8859-2, Latin-2, Central European
            return .isoLatin2
        } else if (onigEncoding == get_onig_iso8859_3()) { // ISO/IEC 8859-3, Latin-3, South European
            return String.Encoding.SwiftOnig.isoLatin3
        } else if (onigEncoding == get_onig_iso8859_4()) { // ISO/IEC 8859-4, Latin-4, North European
            return String.Encoding.SwiftOnig.isoLatin4
        } else if (onigEncoding == get_onig_iso8859_5()) { // ISO/IEC 8859-5, Latin/Cyrillic
            return String.Encoding.SwiftOnig.isoLatinCyrillic
        } else if (onigEncoding == get_onig_iso8859_6()) { // ISO/IEC 8859-6, Latin/Arabic
            return String.Encoding.SwiftOnig.isoLatinArabic
        } else if (onigEncoding == get_onig_iso8859_7()) { // ISO/IEC 8859-7, Latin/Greek
            return String.Encoding.SwiftOnig.isoLatinGreek
        } else if (onigEncoding == get_onig_iso8859_8()) { // ISO/IEC 8859-8, Latin/Hebrew
            return String.Encoding.SwiftOnig.isoLatinHebrew
        } else if (onigEncoding == get_onig_iso8859_9()) { // ISO/IEC 8859-9, Latin-5/Turkish
            return String.Encoding.SwiftOnig.isoLatin5
        } else if (onigEncoding == get_onig_iso8859_10()) { // ISO/IEC 8859-10, Latin-6, Nordic
            return String.Encoding.SwiftOnig.isoLatin6
        } else if (onigEncoding == get_onig_iso8859_11()) { // ISO/IEC 8859-11, Latin/Thai
            return String.Encoding.SwiftOnig.isoLatinThai
        } else if (onigEncoding == get_onig_iso8859_13()) { // ISO/IEC 8859-13, Latin-7, Baltic Rim
            return String.Encoding.SwiftOnig.isoLatin7
        } else if (onigEncoding == get_onig_iso8859_14()) { // ISO/IEC 8859-14, Latin-8, Celtic
            return String.Encoding.SwiftOnig.isoLatin8
        } else if (onigEncoding == get_onig_iso8859_15()) { // ISO/IEC 8859-15, Latin-9
            return String.Encoding.SwiftOnig.isoLatin9
        } else if (onigEncoding == get_onig_iso8859_16()) { // ISO/IEC 8859-16, Latin-10, South-Eastern European
            return String.Encoding.SwiftOnig.isoLatin10
        } else if (onigEncoding == get_onig_utf8()) { // UTF-8
            return .utf8
        } else if (onigEncoding == get_onig_utf16be()) { // UTF-16 big endian
            return .utf16BigEndian
        } else if (onigEncoding == get_onig_utf16le()) { // UTF-16 little endian
            return .utf16LittleEndian
        } else if (onigEncoding == get_onig_utf32be()) { // UTF-32 big endian
            return .utf32BigEndian
        } else if (onigEncoding == get_onig_utf32le()) { // UTF-32 little endian
            return .utf32LittleEndian
        } else if (onigEncoding == get_onig_eucjp()) { // EUC JP
            return .japaneseEUC
        } else if (onigEncoding == get_onig_euctw()) { // EUC TW
            return String.Encoding.SwiftOnig.eucTW
        } else if (onigEncoding == get_onig_euckr()) { // EUC KR
            return String.Encoding.SwiftOnig.euckr
        } else if (onigEncoding == get_onig_euccn()) { // EUC CN
            return String.Encoding.SwiftOnig.euccn
        } else if (onigEncoding == get_onig_sjis()) { // Shift JIS
            return .shiftJIS
        } else if (onigEncoding == get_onig_koi8r()) { // KOI8-R
            return String.Encoding.SwiftOnig.koi8r
        } else if (onigEncoding == get_onig_cp1251()) { // CP1251, Windows-1251
            return .windowsCP1251
        } else if (onigEncoding == get_onig_big5()) { // BIG 5
            return String.Encoding.SwiftOnig.big5
        } else if (onigEncoding == get_onig_gb18030()) { // GB 18030
            return String.Encoding.SwiftOnig.gb18030
        }
        
        fatalError("Unexpected encoding")
    }

    /*
     TODO:
     # UChar* onigenc_get_prev_char_head(OnigEncoding enc, const UChar* start, const UChar* s)

       Return previous character head address.

       arguments
       1 enc:   character encoding
       2 start: string address
       3 s:     target address of string


     # UChar* onigenc_get_left_adjust_char_head(OnigEncoding enc,
                                                const UChar* start, const UChar* s)

       Return left-adjusted head address of a character.

       arguments
       1 enc:   character encoding
       2 start: string address
       3 s:     target address of string


     # int onigenc_get_right_adjust_char_head(OnigEncoding enc,
                                              const UChar* start, const UChar* s)

       Return right-adjusted head address of a character.

       arguments
       1 enc:   character encoding
       2 start: string address
       3 s:     target address of string


     # int onigenc_strlen(OnigEncoding enc, const UChar* s, const UChar* end)
     # int onigenc_strlen_null(OnigEncoding enc, const UChar* s)
     # int onigenc_str_bytelen_null(OnigEncoding enc, const UChar* s)
     */
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
