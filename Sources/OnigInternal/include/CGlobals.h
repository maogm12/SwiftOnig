#ifndef C_GLOBALS_H
#define C_GLOBALS_H

#include <oniguruma.h>

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

unsigned int get_onig_option_extend();
unsigned int get_onig_option_multiline();
unsigned int get_onig_option_singleline();
unsigned int get_onig_option_find_longest();
unsigned int get_onig_option_find_not_empty();
unsigned int get_onig_option_negate_singleline();
unsigned int get_onig_option_dont_capture_group();
unsigned int get_onig_option_capture_group();
unsigned int get_onig_option_notbol();
unsigned int get_onig_option_noteol();
unsigned int get_onig_option_not_begin_string();
unsigned int get_onig_option_not_end_string();
unsigned int get_onig_option_not_begin_position();

unsigned int get_onig_syn_op_variable_meta_characters();
unsigned int get_onig_syn_op_dot_anychar();
unsigned int get_onig_syn_op_asterisk_zero_inf();
unsigned int get_onig_syn_op_esc_asterisk_zero_inf();
unsigned int get_onig_syn_op_plus_one_inf();
unsigned int get_onig_syn_op_esc_plus_one_inf();
unsigned int get_onig_syn_op_qmark_zero_one();
unsigned int get_onig_syn_op_esc_qmark_zero_one();
unsigned int get_onig_syn_op_bracket_cc();
unsigned int get_onig_syn_op_esc_brace_interval();
unsigned int get_onig_syn_op_vbar_alt();
unsigned int get_onig_syn_op_esc_vbar_alt();
unsigned int get_onig_syn_op_lparen_subexp();
unsigned int get_onig_syn_op_esc_lparen_subexp();
unsigned int get_onig_syn_op_esc_o_brace_octal();

unsigned int get_onig_syn_op2_qmark_lt_named_group();
unsigned int get_onig_syn_op2_esc_p_brace_circumflex_not();
unsigned int get_onig_syn_op2_esc_x_y_text_segment();
unsigned int get_onig_syn_op2_esc_v_vtab();
unsigned int get_onig_syn_op2_esc_u_hex4();
unsigned int get_onig_syn_op2_esc_h_xdigit();
unsigned int get_onig_syn_op2_esc_k_named_backref();
unsigned int get_onig_syn_op2_esc_g_subexp_call();
unsigned int get_onig_syn_op2_qmark_lparen_if_else();
unsigned int get_onig_syn_op2_esc_capital_r_general_newline();
unsigned int get_onig_syn_op2_esc_capital_n_o_super_dot();
unsigned int get_onig_syn_op2_atmark_capture_history();
unsigned int get_onig_syn_op2_qmark_brace_callout_contents();

unsigned int get_onig_syn_allow_unmatched_close_subexp();
unsigned int get_onig_syn_allow_interval_low_abbrev();
unsigned int get_onig_syn_allow_empty_range_in_cc();
unsigned int get_onig_syn_warn_cc_op_not_escaped();

#endif
