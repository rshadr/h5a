;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "tokenizer_states.g"

format ELF64

extrn _h5aTokenizerEat
extrn _h5aTokenizerEatInsensitive
extrn _h5aTokenizerEmitCharacter
extrn _h5aTokenizerEmitEof

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

;; ...

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

;; ...


state markupDeclarationOpen,MARKUP_DECLARATION_OPEN_STATE

  @no_consume

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

;; ...


section '.rodata'
generate_tables

