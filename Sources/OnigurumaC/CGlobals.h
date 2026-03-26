#ifndef C_GLOBALS_H
#define C_GLOBALS_H

#include "vendor/oniguruma.h"

OnigEncoding get_onig_ascii();
OnigEncoding get_onig_iso8859_1();
OnigEncoding get_onig_iso8859_2();
OnigEncoding get_onig_iso8859_3();
OnigEncoding get_onig_iso8859_4();
OnigEncoding get_onig_iso8859_5();
OnigEncoding get_onig_iso8859_6();
OnigEncoding get_onig_iso8859_7();
OnigEncoding get_onig_iso8859_8();
OnigEncoding get_onig_iso8859_9();
OnigEncoding get_onig_iso8859_10();
OnigEncoding get_onig_iso8859_11();
OnigEncoding get_onig_iso8859_13();
OnigEncoding get_onig_iso8859_14();
OnigEncoding get_onig_iso8859_15();
OnigEncoding get_onig_iso8859_16();
OnigEncoding get_onig_utf8();
OnigEncoding get_onig_utf16be();
OnigEncoding get_onig_utf16le();
OnigEncoding get_onig_utf32be();
OnigEncoding get_onig_utf32le();
OnigEncoding get_onig_eucjp();
OnigEncoding get_onig_euctw();
OnigEncoding get_onig_euckr();
OnigEncoding get_onig_euccn();
OnigEncoding get_onig_sjis();
OnigEncoding get_onig_koi8r();
OnigEncoding get_onig_cp1251();
OnigEncoding get_onig_big5();
OnigEncoding get_onig_gb18030();

OnigSyntaxType* get_onig_asis();
OnigSyntaxType* get_onig_posix_basic();
OnigSyntaxType* get_onig_posix_extended();
OnigSyntaxType* get_onig_emacs();
OnigSyntaxType* get_onig_grep();
OnigSyntaxType* get_onig_gnu_regex();
OnigSyntaxType* get_onig_java();
OnigSyntaxType* get_onig_perl();
OnigSyntaxType* get_onig_perl_ng();
OnigSyntaxType* get_onig_ruby();
OnigSyntaxType* get_onig_oniguruma();
OnigSyntaxType* get_onig_default_syntax();

#endif
