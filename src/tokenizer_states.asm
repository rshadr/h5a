include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "tokenizer_states.g"

format ELF64

extrn _h5aTokenizerEat
extrn _h5aTokenizerEatInsensitive

public _k_h5a_Tokenizer_ascii_matrix
public _k_h5a_Tokenizer_unicode_table
public _k_h5a_Tokenizer_eof_table
public _k_h5a_Tokenizer_spcAction_table
public _k_h5a_Tokenizer_state_flags

section '.text' executable

;; Dummy handler for development
_h5aTokenizerHandle.DUMMY.any:
  ;; XXX: error call?
  xor al,al
  ret

define_state data,DATA_STATE
  [[U+0026 AMPERSAND (&)]]
    ; store
    ; switch
    xor al,al
    ret
  ;...
  [[U+0000 NULL]]
    xor al,al
    ret
  [[EOF]]
    xor al,al
    ret
  [[Anything else]]
    ; emit
    xor al,al
    ret
end define_state

define_state tagOpen,TAG_OPEN_STATE
  [[U+0021 EXCLAMATION MARK (!)]]
    ; switch
    xor al,al
    ret
  [[U+002F SOLIDUS (/)]]
    ; switch
    xor al,al
    ret
  [[ASCII alpha]]
    ; ...
    xor al,al
    ret
  [[U+003F QUESTION MARK (?)]]
    ; ...
    xor al,al
    ret
  [[EOF]]
    ; error
    ; emit
    ; eof
    xor al,al
    ret
  [[Anything else]]
    xor al,al
    ret
end define_state

; ...

define_state markupDeclarationOpen,MARKUP_DECLARATION_OPEN_STATE
  [[Exactly "--"]]
    xor al,al
    ;[[fallthrough]]
    ret
  [[Case-insensitively "DOCTYPE"]]
    xor al,al
    ret
  [[Exactly "[CDATA["]]
    xor al,al
    ret
  [[Anything else]]
    xor al,al
    ret
end define_state


section '.rodata'
generate_tables

_k_h5a_Tokenizer_state_flags:
repeat NUM_STATES
  db 0x00
end repeat

public myFrickenLabel
myFrickenLabel:
  dq _h5aTokenizerEat

