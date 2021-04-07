//
//  Encoding.swift
//  
//
//  Created by Gavin Mao on 4/3/21.
//

import COnig

public struct Encoding {
    internal var rawValue: OnigEncoding!

    /// ACSII
    public static let ascii = Encoding(rawValue: &OnigEncodingASCII)

    /// ISO/IEC 8859-1, Latin-1, Western European
    public static let iso8859Part1 = Encoding(rawValue: &OnigEncodingISO_8859_1)

    /// ISO/IEC 8859-2, Latin-2, Central European
    public static let iso8859Part2 = Encoding(rawValue: &OnigEncodingISO_8859_2)

    /// ISO/IEC 8859-3, Latin-3, South European
    public static let iso8859Part3 = Encoding(rawValue: &OnigEncodingISO_8859_3)

    /// ISO/IEC 8859-4, Latin-4, North European
    public static let iso8859Part4 = Encoding(rawValue: &OnigEncodingISO_8859_4)

    /// ISO/IEC 8859-5, Latin/Cyrillic
    public static let iso8859Part5 = Encoding(rawValue: &OnigEncodingISO_8859_5)

    /// ISO/IEC 8859-6, Latin/Arabic
    public static let iso8859Part6 = Encoding(rawValue: &OnigEncodingISO_8859_6)

    /// ISO/IEC 8859-7, Latin/Greek
    public static let iso8859Part7 = Encoding(rawValue: &OnigEncodingISO_8859_7)

    /// ISO/IEC 8859-8, Latin/Hebrew
    public static let iso8859Part8 = Encoding(rawValue: &OnigEncodingISO_8859_8)

    /// ISO/IEC 8859-9, Latin-5/Turkish
    public static let iso8859Part9 = Encoding(rawValue: &OnigEncodingISO_8859_9)

    /// ISO/IEC 8859-10, Latin-6, Nordic
    public static let iso8859Part10 = Encoding(rawValue: &OnigEncodingISO_8859_10)

    /// ISO/IEC 8859-11, Latin/Thai
    public static let iso8859Part11 = Encoding(rawValue: &OnigEncodingISO_8859_11)

    /// ISO/IEC 8859-13, Latin-7, Baltic Rim
    public static let iso8859Part13 = Encoding(rawValue: &OnigEncodingISO_8859_13)

    /// ISO/IEC 8859-14, Latin-8, Celtic
    public static let iso8859Part14 = Encoding(rawValue: &OnigEncodingISO_8859_14)

    /// ISO/IEC 8859-15, Latin-9
    public static let iso8859Part15 = Encoding(rawValue: &OnigEncodingISO_8859_15)

    /// ISO/IEC 8859-16, Latin-10, South-Eastern European
    public static let iso8859Part16 = Encoding(rawValue: &OnigEncodingISO_8859_16)
    
    /// UTF-8
    public static let utf8 = Encoding(rawValue: &OnigEncodingUTF8)
    
    /// UTF-16 big endian
    public static let utf16BigEndian = Encoding(rawValue: &OnigEncodingUTF16_BE)
    
    /// UTF-16 little endian
    public static let utf16LittleEndian = Encoding(rawValue: &OnigEncodingUTF16_LE)
    
    /// UTF-32 big endian
    public static let utf32BigEndian = Encoding(rawValue: &OnigEncodingUTF32_BE)
    
    /// UTF-32 little endian
    public static let utf32LittleEndian = Encoding(rawValue: &OnigEncodingUTF32_LE)
    
    /// EUC JP
    public static let eucJP = Encoding(rawValue: &OnigEncodingEUC_JP)
    
    /// EUC TW
    public static let eucTW = Encoding(rawValue: &OnigEncodingEUC_TW)

    /// EUC KR
    public static let eucKR = Encoding(rawValue: &OnigEncodingEUC_KR)

    /// EUC CN
    public static let eucCN = Encoding(rawValue: &OnigEncodingEUC_CN)

    /// Shift JIS
    public static let shiftJIS = Encoding(rawValue: &OnigEncodingSJIS)
    
//    /// KOI-8
//    public static let koi8 = Encoding(rawValue: &OnigEncodingKOI8)
    
    /// KOI8-R
    public static let koi8r = Encoding(rawValue: &OnigEncodingKOI8_R)
    
    /// CP1251, Windows-1251
    public static let cp1251 = Encoding(rawValue: &OnigEncodingCP1251)
    
    /// BIG 5
    public static let big5 = Encoding(rawValue: &OnigEncodingBIG5)
    
    /// GB 18030
    public static let gb18030 = Encoding(rawValue: &OnigEncodingGB18030)

    /// Get or set the default encoding
    public static var `default`: Encoding {
        get {
            Encoding(rawValue: onigenc_get_default_encoding())
        }

        set {
            onigQueue.sync {
                _ = onigenc_set_default_encoding(newValue.rawValue)
            }
        }
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


     # UChar* onigenc_get_right_adjust_char_head(OnigEncoding enc,
                                                 const UChar* start, const UChar* s)

       Return right-adjusted head address of a character.

       arguments
       1 enc:   character encoding
       2 start: string address
       3 s:     target address of string


     # int onigenc_strlen(OnigEncoding enc, const UChar* s, const UChar* end)

       Return number of characters in the string.


     # int onigenc_strlen_null(OnigEncoding enc, const UChar* s)

       Return number of characters in the string.
       Do not pass invalid byte string in the character encoding.


     # int onigenc_str_bytelen_null(OnigEncoding enc, const UChar* s)

       Return number of bytes in the string.
       Do not pass invalid byte string in the character encoding.

     # void onig_copy_encoding(OnigEncoding to, OnigEncoding from)

       Copy encoding.

       arguments
       1 to:   destination address.
       2 from: source address.
     */
}
