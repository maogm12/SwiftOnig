#include "include/CGlobals.h"

OnigEncoding get_onig_ascii() { return ONIG_ENCODING_ASCII; }
OnigEncoding get_onig_iso8859_1() { return ONIG_ENCODING_ISO_8859_1; }
OnigEncoding get_onig_iso8859_2() { return ONIG_ENCODING_ISO_8859_2; }
OnigEncoding get_onig_iso8859_3() { return ONIG_ENCODING_ISO_8859_3; }
OnigEncoding get_onig_iso8859_4() { return ONIG_ENCODING_ISO_8859_4; }
OnigEncoding get_onig_iso8859_5() { return ONIG_ENCODING_ISO_8859_5; }
OnigEncoding get_onig_iso8859_6() { return ONIG_ENCODING_ISO_8859_6; }
OnigEncoding get_onig_iso8859_7() { return ONIG_ENCODING_ISO_8859_7; }
OnigEncoding get_onig_iso8859_8() { return ONIG_ENCODING_ISO_8859_8; }
OnigEncoding get_onig_iso8859_9() { return ONIG_ENCODING_ISO_8859_9; }
OnigEncoding get_onig_iso8859_10() { return ONIG_ENCODING_ISO_8859_10; }
OnigEncoding get_onig_iso8859_11() { return ONIG_ENCODING_ISO_8859_11; }
OnigEncoding get_onig_iso8859_13() { return ONIG_ENCODING_ISO_8859_13; }
OnigEncoding get_onig_iso8859_14() { return ONIG_ENCODING_ISO_8859_14; }
OnigEncoding get_onig_iso8859_15() { return ONIG_ENCODING_ISO_8859_15; }
OnigEncoding get_onig_iso8859_16() { return ONIG_ENCODING_ISO_8859_16; }
OnigEncoding get_onig_utf8() { return ONIG_ENCODING_UTF8; }
OnigEncoding get_onig_utf16be() { return ONIG_ENCODING_UTF16_BE; }
OnigEncoding get_onig_utf16le() { return ONIG_ENCODING_UTF16_LE; }
OnigEncoding get_onig_utf32be() { return ONIG_ENCODING_UTF32_BE; }
OnigEncoding get_onig_utf32le() { return ONIG_ENCODING_UTF32_LE; }
OnigEncoding get_onig_eucjp() { return ONIG_ENCODING_EUC_JP; }
OnigEncoding get_onig_euctw() { return ONIG_ENCODING_EUC_TW; }
OnigEncoding get_onig_euckr() { return ONIG_ENCODING_EUC_KR; }
OnigEncoding get_onig_euccn() { return ONIG_ENCODING_EUC_CN; }
OnigEncoding get_onig_sjis() { return ONIG_ENCODING_SJIS; }
OnigEncoding get_onig_koi8r() { return ONIG_ENCODING_KOI8_R; }
OnigEncoding get_onig_cp1251() { return ONIG_ENCODING_CP1251; }
OnigEncoding get_onig_big5() { return ONIG_ENCODING_BIG5; }
OnigEncoding get_onig_gb18030() { return ONIG_ENCODING_GB18030; }

OnigSyntaxType* get_onig_asis() { return ONIG_SYNTAX_ASIS; }
OnigSyntaxType* get_onig_posix_basic() { return ONIG_SYNTAX_POSIX_BASIC; }
OnigSyntaxType* get_onig_posix_extended() { return ONIG_SYNTAX_POSIX_EXTENDED; }
OnigSyntaxType* get_onig_emacs() { return ONIG_SYNTAX_EMACS; }
OnigSyntaxType* get_onig_grep() { return ONIG_SYNTAX_GREP; }
OnigSyntaxType* get_onig_gnu_regex() { return ONIG_SYNTAX_GNU_REGEX; }
OnigSyntaxType* get_onig_java() { return ONIG_SYNTAX_JAVA; }
OnigSyntaxType* get_onig_perl() { return ONIG_SYNTAX_PERL; }
OnigSyntaxType* get_onig_perl_ng() { return ONIG_SYNTAX_PERL_NG; }
OnigSyntaxType* get_onig_ruby() { return ONIG_SYNTAX_RUBY; }
OnigSyntaxType* get_onig_oniguruma() { return ONIG_SYNTAX_ONIGURUMA; }
OnigSyntaxType* get_onig_default_syntax() { return ONIG_SYNTAX_DEFAULT; }

unsigned int get_onig_option_extend() { return ONIG_OPTION_EXTEND; }
unsigned int get_onig_option_multiline() { return ONIG_OPTION_MULTILINE; }
unsigned int get_onig_option_singleline() { return ONIG_OPTION_SINGLELINE; }
unsigned int get_onig_option_find_longest() { return ONIG_OPTION_FIND_LONGEST; }
unsigned int get_onig_option_find_not_empty() { return ONIG_OPTION_FIND_NOT_EMPTY; }
unsigned int get_onig_option_negate_singleline() { return ONIG_OPTION_NEGATE_SINGLELINE; }
unsigned int get_onig_option_dont_capture_group() { return ONIG_OPTION_DONT_CAPTURE_GROUP; }
unsigned int get_onig_option_capture_group() { return ONIG_OPTION_CAPTURE_GROUP; }
unsigned int get_onig_option_notbol() { return ONIG_OPTION_NOTBOL; }
unsigned int get_onig_option_noteol() { return ONIG_OPTION_NOTEOL; }
unsigned int get_onig_option_not_begin_string() { return ONIG_OPTION_NOT_BEGIN_STRING; }
unsigned int get_onig_option_not_end_string() { return ONIG_OPTION_NOT_END_STRING; }
unsigned int get_onig_option_not_begin_position() { return ONIG_OPTION_NOT_BEGIN_POSITION; }

unsigned int get_onig_syn_op_variable_meta_characters() { return ONIG_SYN_OP_VARIABLE_META_CHARACTERS; }
unsigned int get_onig_syn_op_dot_anychar() { return ONIG_SYN_OP_DOT_ANYCHAR; }
unsigned int get_onig_syn_op_asterisk_zero_inf() { return ONIG_SYN_OP_ASTERISK_ZERO_INF; }
unsigned int get_onig_syn_op_esc_asterisk_zero_inf() { return ONIG_SYN_OP_ESC_ASTERISK_ZERO_INF; }
unsigned int get_onig_syn_op_plus_one_inf() { return ONIG_SYN_OP_PLUS_ONE_INF; }
unsigned int get_onig_syn_op_esc_plus_one_inf() { return ONIG_SYN_OP_ESC_PLUS_ONE_INF; }
unsigned int get_onig_syn_op_qmark_zero_one() { return ONIG_SYN_OP_QMARK_ZERO_ONE; }
unsigned int get_onig_syn_op_esc_qmark_zero_one() { return ONIG_SYN_OP_ESC_QMARK_ZERO_ONE; }
unsigned int get_onig_syn_op_bracket_cc() { return ONIG_SYN_OP_BRACKET_CC; }
unsigned int get_onig_syn_op_esc_brace_interval() { return ONIG_SYN_OP_ESC_BRACE_INTERVAL; }
unsigned int get_onig_syn_op_vbar_alt() { return ONIG_SYN_OP_VBAR_ALT; }
unsigned int get_onig_syn_op_esc_vbar_alt() { return ONIG_SYN_OP_ESC_VBAR_ALT; }
unsigned int get_onig_syn_op_lparen_subexp() { return ONIG_SYN_OP_LPAREN_SUBEXP; }
unsigned int get_onig_syn_op_esc_lparen_subexp() { return ONIG_SYN_OP_ESC_LPAREN_SUBEXP; }
unsigned int get_onig_syn_op_esc_o_brace_octal() { return ONIG_SYN_OP_ESC_O_BRACE_OCTAL; }

unsigned int get_onig_syn_op2_qmark_lt_named_group() { return ONIG_SYN_OP2_QMARK_LT_NAMED_GROUP; }
unsigned int get_onig_syn_op2_esc_p_brace_circumflex_not() { return ONIG_SYN_OP2_ESC_P_BRACE_CIRCUMFLEX_NOT; }
unsigned int get_onig_syn_op2_esc_x_y_text_segment() { return ONIG_SYN_OP2_ESC_X_Y_TEXT_SEGMENT; }
unsigned int get_onig_syn_op2_esc_v_vtab() { return ONIG_SYN_OP2_ESC_V_VTAB; }
unsigned int get_onig_syn_op2_esc_u_hex4() { return ONIG_SYN_OP2_ESC_U_HEX4; }
unsigned int get_onig_syn_op2_esc_h_xdigit() { return ONIG_SYN_OP2_ESC_H_XDIGIT; }
unsigned int get_onig_syn_op2_esc_k_named_backref() { return ONIG_SYN_OP2_ESC_K_NAMED_BACKREF; }
unsigned int get_onig_syn_op2_esc_g_subexp_call() { return ONIG_SYN_OP2_ESC_G_SUBEXP_CALL; }
unsigned int get_onig_syn_op2_qmark_lparen_if_else() { return ONIG_SYN_OP2_QMARK_LPAREN_IF_ELSE; }
unsigned int get_onig_syn_op2_esc_capital_r_general_newline() { return ONIG_SYN_OP2_ESC_CAPITAL_R_GENERAL_NEWLINE; }
unsigned int get_onig_syn_op2_esc_capital_n_o_super_dot() { return ONIG_SYN_OP2_ESC_CAPITAL_N_O_SUPER_DOT; }
unsigned int get_onig_syn_op2_atmark_capture_history() { return ONIG_SYN_OP2_ATMARK_CAPTURE_HISTORY; }
unsigned int get_onig_syn_op2_qmark_brace_callout_contents() { return ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS; }

unsigned int get_onig_syn_allow_unmatched_close_subexp() { return ONIG_SYN_ALLOW_UNMATCHED_CLOSE_SUBEXP; }
unsigned int get_onig_syn_allow_interval_low_abbrev() { return ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV; }
unsigned int get_onig_syn_allow_empty_range_in_cc() { return ONIG_SYN_ALLOW_EMPTY_RANGE_IN_CC; }
unsigned int get_onig_syn_warn_cc_op_not_escaped() { return ONIG_SYN_WARN_CC_OP_NOT_ESCAPED; }
