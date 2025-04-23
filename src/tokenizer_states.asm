;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "tokenizer_states.g"

format ELF64

extrn _h5aTokenizerPrefetchChars
extrn _h5aTokenizerEat
extrn _h5aTokenizerEatInsensitive
extrn _h5aTokenizerEmitCharacter
extrn _h5aTokenizerEmitEof
extrn _h5aTokenizerHaveAppropriateEndTag
extrn _CharacterQueuePushFront

extrn _k_h5a_entityTable
extrn _k_h5a_entityValues
extrn _k_h5a_numEntities

public _k_h5a_Tokenizer_flags_table
public _k_h5a_Tokenizer_common_dispatch_table
public _k_h5a_Tokenizer_ascii_matrix
public _k_h5a_Tokenizer_unicode_table
public _k_h5a_Tokenizer_eof_table
public _k_h5a_Tokenizer_spc_action_table

public _h5aTokenizerHandle.DUMMY.any

section '.text' executable

_h5aTokenizerHandle.DUMMY.any:
  xor al,al
  ret

state data,DATA_STATE

  [[U+0026 AMPERSAND]]
    mov byte [r12 + H5aParser.tokenizer.return_state], DATA_STATE
    mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], TAG_OPEN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; XXX: error
    xor al,al
    ret

  [[EOF]]
    xor al,al
    ret

  [[Anything else]]
    xor al,al
    ret

end state


state rcdata,RCDATA_STATE

  [[U+0026 AMPERSAND]]
    mov byte [r12 + H5aParser.tokenizer.return_state], DATA_STATE
    mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state rawtext,RAWTEXT_STATE

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], RAWTEXT_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state scriptData,SCRIPT_DATA_STATE

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state plaintext,PLAINTEXT_STATE

  [[U+000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state tagOpen,TAG_OPEN_STATE

  [[U+0021 EXCLAMATION MARK]]
    mov byte [r12 + H5aParser.tokenizer.state], MARKUP_DECLARATION_OPEN_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    mov byte [r12 + H5aParser.tokenizer.state], END_TAG_OPEN_STATE
    xor al,al
    ret

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[U+003F QUESTION MARK]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], BOGUS_COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

  [[EOF]]
    ; ...
    xor edi,edi
    mov dil, '<'
    call _h5aTokenizerEmitCharacter
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor edi,edi
    mov dil, '<'
    call _h5aTokenizerEmitCharacter
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state endTagOpen,END_TAG_OPEN_STATE

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], BOGUS_COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state tagName,TAG_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ; emit
    xor al,al
    ret

  [[ASCII upper alpha]]
    ;; append
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; append
    xor al,al
    ret

end state


state rcdataLessThanSign,RCDATA_LESS_THAN_SIGN_STATE

  [[U+002F SOLIDUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_END_TAG_OPEN_STATE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state rcdataEndTagOpen,RCDATA_END_TAG_OPEN_STATE

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_END_TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state rcdataEndTagName,RCDATA_END_TAG_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ...
    xor al,al
    ret

  [[ASCII lower alpha]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state rawtextLessThanSign,RAWTEXT_LESS_THAN_SIGN_STATE

  [[U+002F SOLIDUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RAWTEXT_END_TAG_OPEN_STATE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RAWTEXT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state rawtextEndTagOpen,RAWTEXT_END_TAG_OPEN_STATE

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RCDATA_END_TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RAWTEXT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state rawtextEndTagName,RAWTEXT_END_TAG_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ...
    xor al,al
    ret

  [[ASCII lower alpha]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], RAWTEXT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataLessThanSign,SCRIPT_DATA_LESS_THAN_SIGN_STATE

  [[U+002F SOLIDUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_END_TAG_OPEN_STATE
    xor al,al
    ret

  [[U+0021 EXCLAMATION MARK]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPE_START_STATE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEndTagOpen,SCRIPT_DATA_END_TAG_OPEN_STATE

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_END_TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEndTagName,SCRIPT_DATA_END_TAG_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ...
    xor al,al
    ret

  [[ASCII lower alpha]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEscapeStart,SCRIPT_DATA_ESCAPE_START_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPE_START_DASH_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEscapeStartDash,SCRIPT_DATA_ESCAPE_START_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_DASH_DASH_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEscaped,SCRIPT_DATA_ESCAPED_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_DASH_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state scriptDataEscapedDash,SCRIPT_DATA_ESCAPED_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_DASH_DASH_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    xor al,al
    ret

end state


state scriptDataEscapedDashDash,SCRIPT_DATA_ESCAPED_DASH_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    xor al,al
    ret

end state


state scriptDataEscapedLessThanSign,SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE

  [[U+002F SOLIDUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE
    xor al,al
    ret

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEscapedEndTagOpen,SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE

  [[ASCII alpha]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataEscapedEndTagName,SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    call _h5aTokenizerHaveAppropriateEndTag
    test al,al

    goto_if! z anything_else

    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ; XXX: emit
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ...
    xor al,al
    ret

  [[ASCII lower alpha]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataDoubleEscapeStart,SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
  [[U+002F SOLIDUS]]
  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ...
    xor al,al
    ret

  [[ASCII lower alpha]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_ESCAPED_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state scriptDataDoubleEscaped,SCRIPT_DATA_DOUBLE_ESCAPED_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state scriptDataDoubleEscapedDash,SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_STATE
    xor al,al
    ret

end state


state scriptDataDoubleEscapedDashDash,SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_STATE
    xor al,al
    ret

end state


state scriptDataDoubleEscapedLessThanSign,SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE

  [[U+002F SOLIDUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_DOUBLE_ESCAPED_STATE
    mov al, RESULT_RECONSUME
    ret

end state

;; ...

state beforeAttributeName,BEFORE_ATTRIBUTE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov al, RESULT_IGNORE
    ret

  [[U+002F SOLIDUS]]
  [[U+003E GREATER-THAN SIGN]]
  [[EOF]]
    mov byte [r12 + H5aParser.tokenizer.state], AFTER_ATTRIBUTE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[U+003D EQUALS SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state attributeName,ATTRIBUTE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+0020 SPACE]]
  [[U+002F SOLIDUS]]
  [[U+003E GREATER-THAN SIGN]]
  [[EOF]]
    mov byte [r12 + H5aParser.tokenizer.state], AFTER_ATTRIBUTE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[U+003D EQUALS SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_VALUE_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ; ... append
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[U+0022 QUOTATION MARK]]
  [[U+0027 APOSTROPHE]]
  [[U+003C LESS-THAN SIGN]]
    ; ...
    goto! anything_else

  [[Anything else]]
    ; append
    xor al,al
    ret

end state


state afterAttributeName,AFTER_ATTRIBUTE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov al, RESULT_IGNORE
    ret

  [[U+002F SOLIDUS]]
    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003D EQUALS SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_VALUE_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state beforeAttributeValue,BEFORE_ATTRIBUTE_VALUE_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov al, RESULT_IGNORE
    ret

  [[U+0022 QUOTATION MARK]]
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE
    xor al,al
    ret

  [[U+0027 APOSTROPHE]]
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], ATTRIBUTE_VALUE_UNQUOTED_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state attributeValueDoubleQuoted,ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE

  [[U+0022 QUOTATION MARK]]
    mov byte [r12 + H5aParser.tokenizer.state], AFTER_ATTRIBUTE_VALUE_QUOTED_STATE
    xor al,al
    ret

  [[U+0026 AMPERSAND]]
    mov byte [r12 + H5aParser.tokenizer.return_state], ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE
    mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state attributeValueSingleQuoted,ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE

  [[U+0027 APOSTROPHE]]
    mov byte [r12 + H5aParser.tokenizer.state], AFTER_ATTRIBUTE_VALUE_QUOTED_STATE
    xor al,al
    ret

  [[U+0026 AMPERSAND]]
    mov byte [r12 + H5aParser.tokenizer.return_state], ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE
    mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state attributeValueUnquoted,ATTRIBUTE_VALUE_UNQUOTED_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+0026 AMPERSAND]]
    mov byte [r12 + H5aParser.tokenizer.return_state], ATTRIBUTE_VALUE_UNQUOTED_STATE
    mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ; emit
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[U+0022 QUOTATION MARK]]
  [[U+0027 APOSTROPHE]]
  [[U+003C LESS-THAN SIGN]]
  [[U+003D EQUALS SIGN]]
  [[U+0060 GRAVE ACCENT]]
    ; XXX: bad order!
    ; ...
    goto! anything_else

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state afterAttributeValueQuoted,AFTER_ATTRIBUTE_VALUE_QUOTED_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    xor al,al
    ret

  [[U+002F SOLIDUS]]
    mov byte [r12 + H5aParser.tokenizer.state], SELF_CLOSING_START_TAG_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ; emit
    xor al,al
    ret

  [[EOF]]
    ; ..
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_ATTRIBUTE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

end state

;; ...

state bogusComment,BOGUS_COMMENT_STATE

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ;emit
    xor al,al
    ret

  [[EOF]]
    ;emit comment
    jmp _h5aTokenizerEmitEof

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    ; append
    xor al,al
    ret

end state


state markupDeclarationOpen,MARKUP_DECLARATION_OPEN_STATE

  @NoConsume

  [[Exactly "--"]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_START_STATE
    xor al,al
    ret

  [[Case-insensitively "DOCTYPE"]]
    mov byte [r12 + H5aParser.tokenizer.state], DOCTYPE_STATE
    xor al,al
    ret

  [[Exactly "[CDATA["]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], BOGUS_COMMENT_STATE
    xor al,al
    ret

  [[Anything else]]
    xor al,al
    ret

end state


state commentStart,COMMENT_START_STATE

  [[U+002D HYPHEN-MINUS]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_START_DASH_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentStartDash,COMMENT_START_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state comment,COMMENT_STATE

  [[U+003C LESS-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_LESS_THAN_SIGN_STATE
    xor al,al
    ret

  [[U+002D HYPHEN-MINUS]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_DASH_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    xor al,al
    ret

end state


state commentLessThanSign,COMMENT_LESS_THAN_SIGN_STATE

  [[U+0021 EXCLAMATION MARK]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_LESS_THAN_SIGN_BANG_STATE
    xor al,al
    ret

  [[U+003C LESS-THAN SIGN]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentLessThanSignBang,COMMENT_LESS_THAN_SIGN_BANG_STATE

  [[U+002D HYPHEN-MINUS]]
    xor al,al
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_LESS_THAN_SIGN_BANG_DASH_STATE
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentLessThanSignBangDash,COMMENT_LESS_THAN_SIGN_BANG_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_LESS_THAN_SIGN_BANG_DASH_DASH_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_DASH_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentLessThanSignBangDashDash,COMMENT_LESS_THAN_SIGN_BANG_DASH_DASH_STATE

  [[U+003E GREATER-THAN SIGN]]
  [[EOF]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentEndDash,COMMENT_END_DASH_STATE

  [[U+002D HYPHEN-MINUS]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_STATE
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentEnd,COMMENT_END_STATE

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    mov al, RESULT_RECONSUME
    ret

  [[U+0021 EXCLAMATION MARK]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_END_BANG_STATE
    xor al,al
    ret

  [[U+002D HYPHEN-MINUS]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state commentEndBang,COMMENT_END_BANG_STATE

  [[U+002D HYPHEN-MINUS]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[EOF]]
    ; ...
    jmp _h5aTokenizerEmitEof
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.tokenizer.state], COMMENT_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state doctype,DOCTYPE_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_DOCTYPE_NAME_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_DOCTYPE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

  [[EOF]]
    ;; error
    ;; create doctype
    ;; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ;; error
    mov byte [r12 + H5aParser.tokenizer.state], BEFORE_DOCTYPE_NAME_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state beforeDoctypeName,BEFORE_DOCTYPE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov al, RESULT_IGNORE
    ret

  [[ASCII upper alpha]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], DOCTYPE_NAME_STATE
    xor al,al
    ret

  [[U+0000 NULL]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], DOCTYPE_NAME_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ;; emit
    xor al,al
    ret

  [[EOF]]
    ;; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], DOCTYPE_NAME_STATE
    xor al,al
    ret

end state


state doctypeName,DOCTYPE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov byte [r12 + H5aParser.tokenizer.state], AFTER_DOCTYPE_NAME_STATE
    xor al,al
    ret

  [[U+003E GREATER-THAN SIGN]]
    ;; emit
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[ASCII upper alpha]]
    ;; ...
    xor al,al
    ret

  [[U+0000 NULL]]
    ;; ...
    xor al,al
    ret

  [[EOF]]
    ;; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ;; ...
    xor al,al
    ret

end state


state afterDoctypeName,AFTER_DOCTYPE_NAME_STATE

  [[U+0009 CHARACTER TABULATION]]
  [[U+000A LINE FEED]]
  [[U+000C FORM FEED]]
  [[U+0020 SPACE]]
    mov al, RESULT_IGNORE
    ret

  [[U+003E GREATER-THAN SIGN]]
    ; emit
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    xor al,al
    ret

  [[EOF]]
    ;; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    ;; XXX: local-scoped labels???
    mov byte [r12 + H5aParser.tokenizer.state], BOGUS_DOCTYPE_STATE
    mov al, RESULT_RECONSUME
    ret

end state


;; ...

state bogusDoctype,BOGUS_DOCTYPE_STATE

  [[U+003E GREATER-THAN SIGN]]
    mov byte [r12 + H5aParser.tokenizer.state], DATA_STATE
    ;; emit
    xor al,al
    ret

  [[U+0000 NULL]]
    ;; ...
    mov al, RESULT_IGNORE
    ret

  [[EOF]]
    ;; ...
    jmp _h5aTokenizerEmitEof

  [[Anything else]]
    mov al, RESULT_IGNORE
    ret

end state

;; ...

state characterReference,CHARACTER_REFERENCE_STATE
  ;; clear tmpbuf

  [[ASCII alphanumeric]]
    ;; NOTE: differs from spec. We do not reconsume because "named character reference state"
    ;; doesn't have single-character actions; it attempts to consume the whole named ref
    ;; at once, e.g.:
    ;; "lt;" instead of ("l" THEN "t;") or "&lt;"
    mov rsi, rdi
    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _CharacterQueuePushFront
    mov byte [r12 + H5aParser.tokenizer.state], NAMED_CHARACTER_REFERENCE_STATE

    ;mov al, RESULT_RECONSUME
    xor al,al
    ret

  [[U+0023 NUMBER SIGN]]
    ;; append
    mov byte [r12 + H5aParser.tokenizer.state], NUMERIC_CHARACTER_REFERENCE_STATE
    xor al,al
    ret

  [[Anything else]]
    ;; flush code points...
    mov al, byte [r12 + H5aParser.tokenizer.return_state]
    mov byte [r12 + H5aParser.tokenizer.state], al
    mov al, RESULT_RECONSUME
    ret

end state


state namedCharacterReference,NAMED_CHARACTER_REFERENCE_STATE

  @NoConsume

entity_resolve:

  with_saved_regs rbx, r13, r14
    lea rbx, [_k_h5a_entityTable]
    xor r13,r13
    xor r14,r14
    mov r14d, dword [_k_h5a_numEntities]

.loop:
    cmp r13, r14
    unlikely jge .no_match

    xor rdi,rdi
    mov rcx, r13
    shl rcx, 1
    mov edi, dword [rbx + rcx * 8 + 4]
    call _h5aTokenizerPrefetchChars
    ; ...
    ; call _h5aTokenizerEatInsensitive

    inc r13
    jmp .loop

.match:

.no_match:
  ;fallthrough

.finish:
  xor al,al
  end with_saved_regs
  ret

end state


;; ...

state numericCharacterReference,NUMERIC_CHARACTER_REFERENCE_STATE

  [[U+0078 LATIN SMALL LETTER X]]
  [[U+0058 LATIN CAPITAL LETTER X]]
    ;; append
    mov byte [r12 + H5aParser.tokenizer.state], HEXADECIMAL_CHARACTER_REFERENCE_START_STATE
    xor al,al
    ret

  [[Anything else]]
    mov byte [r12 + H5aParser.tokenizer.state], DECIMAL_CHARACTER_REFERENCE_START_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state hexadecimalCharacterReferenceStart,HEXADECIMAL_CHARACTER_REFERENCE_START_STATE

  [[ASCII hex digit]]
    mov byte [r12 + H5aParser.tokenizer.state], HEXADECIMAL_CHARACTER_REFERENCE_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    ;; ...
    mov cl, byte [r12 + H5aParser.tokenizer.return_state]
    mov byte [r12 + H5aParser.tokenizer.state], cl
    mov al, RESULT_RECONSUME
    ret

end state


state decimalCharacterReferenceStart,DECIMAL_CHARACTER_REFERENCE_START_STATE

  [[ASCII digit]]
    mov byte [r12 + H5aParser.tokenizer.state], DECIMAL_CHARACTER_REFERENCE_STATE
    mov al, RESULT_RECONSUME
    ret

  [[Anything else]]
    mov cl, byte [r12 + H5aParser.tokenizer.return_state]
    mov byte [r12 + H5aParser.tokenizer.state], cl
    mov al, RESULT_RECONSUME
    ret

end state


state hexadecimalCharacterReference,HEXADECIMAL_CHARACTER_REFERENCE_STATE

  [[ASCII digit]]
    mov rdx, qword [r12 + H5aParser.tokenizer.char_ref]
    shl rdx, 4
    sub di, 0x30
    add rdx, rdi
    mov qword [r12 + H5aParser.tokenizer.char_ref], rdx
    xor al,al
    ret

  [[ASCII upper hex digit]]
    mov rdx, qword [r12 + H5aParser.tokenizer.char_ref]
    shl rdx, 4
    sub di, 0x37
    add rdx, rdi
    mov qword [r12 + H5aParser.tokenizer.char_ref], rdx
    xor al,al
    ret

  [[ASCII lower hex digit]]
    mov rdx, qword [r12 + H5aParser.tokenizer.char_ref]
    shl rdx, 4
    sub di, 0x57
    add rdx, rdi
    mov qword [r12 + H5aParser.tokenizer.char_ref], rdx
    xor al,al
    ret

  [[U+003B SEMICOLON]]
    mov byte [r12 + H5aParser.tokenizer.state], NUMERIC_CHARACTER_REFERENCE_END_STATE
    xor al,al
    ret

  [[Anything else]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], NUMERIC_CHARACTER_REFERENCE_END_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state decimalCharacterReference,DECIMAL_CHARACTER_REFERENCE_STATE

  [[ASCII digit]]
    mov rax, qword [r12 + H5aParser.tokenizer.char_ref]
    xor rcx,rcx
    mov cl, 10
    mul rcx
    sub di, 0x30
    add rax, rdi
    mov qword [r12 + H5aParser.tokenizer.char_ref], rax
    xor al,al
    ret

  [[U+003B SEMICOLON]]
    mov byte [r12 + H5aParser.tokenizer.state], NUMERIC_CHARACTER_REFERENCE_END_STATE
    xor al,al
    ret

  [[Anything else]]
    ;; ...
    mov byte [r12 + H5aParser.tokenizer.state], NUMERIC_CHARACTER_REFERENCE_END_STATE
    mov al, RESULT_RECONSUME
    ret

end state


state numericCharacterReferenceEnd,NUMERIC_CHARACTER_REFERENCE_END_STATE

  @NoConsume



  ; ...
  mov cl, byte [r12 + H5aParser.tokenizer.return_state]
  mov byte [r12 + H5aParser.tokenizer.state], cl
  xor al,al
  ret

end state



section '.rodata'
generate_tables


