;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

format ELF64

;; Lookup tables
extrn _k_h5a_Tokenizer_state_flags
extrn _k_h5a_Tokenizer_ascii_matrix
extrn _k_h5a_Tokenizer_unicode_table
extrn _k_h5a_Tokenizer_eof_table

extrn _h5aTreeBuilderAcceptToken

public _h5aTokenizerEat
public _h5aTokenizerEatInsensitive
public _h5aTokenizerMain
public _k_h5a_Tokenizer_common_handler_table

public _k_otherTable




section '.text' executable

_h5aTokenizerEat:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char const *seq
  ;; -> RAX: bool was_matched
  xor rax,rax
  ret

_h5aTokenizerEatInsensitive:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char const *seq
  ;; -> RAX: bool was_matched
  xor rax,rax
  ret

_h5aTokenizerEmitToken:
;; R12 (s): H5aParser *parser
;; RDI (arg): opaque64 data
;; RSI (arg): enum type
;; -> void
  lea  rax, [_h5aTreeBuilderAcceptToken]
  jmp  rax

_h5aTokenizerEmitCharacter:
;; R12 (s): H5aParser *parser
;; EDI (arg): u32 code
;; -> void
  xor rsi,rsi
  mov sil, TOKEN_CHARACTER
  jmp _h5aTokenizerEmitToken


_h5aTokenizerEmitTag:
;; R12 (s): H5aParser *parser
;; -> void
  jmp _h5aTokenizerEmitToken

_h5aTokenizerEmitEof:
  ;; R12 (s): H5aParser *parser
  ;; -> u8 status
  mov sil, TOKEN_EOF
  call _h5aTokenizerEmitToken
  mov al, RESULT_EOF_REACHED
  ret

_h5aTokenizerMain:
  ;; R12 (s/lost): H5aParser *
  ;; -> EAX: status
  push rbx
  push r10

  .charLoop:
    lea   rbx, [_k_h5a_Tokenizer_state_flags]
    mov   rax, qword [r12 + H5aParser.input_stream.user_data]
    xlatb

    test  al, STATE_BIT_SPC_ACTION
    LIKELY jz .charLoop.postSpcAction

    .charLoop.spcAction:
    ;; XXX: do spcAction

    .charLoop.postSpcAction:
      test  al, STATE_BIT_NO_GETCHAR
      LIKELY   jz .charLoop.readChar
      nop
      UNLIKELY jmp .charLoop

    .charLoop.readChar:
      mov   rdi, qword [r12 + H5aParser.input_stream.user_data]
      call  qword [r12 + H5aParser.input_stream.get_char_cb]
      mov   r10, rax ;keep for later
    
    .charLoop.hashChar:
      ;; hash result (AL):
      ;;  0x00 : ASCII codepoint   (< 0x007F)
      ;;  0x01 : Unicode codepoint (> 0x007F and != ~0x00)
      ;;  0x02 : EOF               (== ~0x00)
      xor    rax,rax
      xor    rdi,rdi

      ;test   r10d, (not 0x7F)
      ;setnz al
      cmp   r10d, 0x7F
      seta  al

      ;mov    ecx, r10d
      ;not    ecx
      ;test   ecx,ecx
      ;setz   dil
      cmp   r10d, (not 0x00)
      sete  dil

      add    al, dil

    .charLoop.dispatchCommon:
      lea   rbx, [_k_h5a_Tokenizer_common_handler_table]
      mov   rbx, qword [rbx + rax * 8]

      test  rax,rax ;unicode/EOF?
      UNLIKELY jnz .charLoop.unicodeOrEofLoop

    .charLoop.asciiLoop:
      mov  rax, qword [r12 + H5aParser.tokenizer.state]
      shl  rax, (bsr (128 * 8))
      lea  rax, [rbx + rax] ;load state's LUT
      lea  rax, [rax + r10 * 8] ;load handler
      mov  rdi, r10
      call qword [rax]

      test  eax, RESULT_BIT_AGAIN
      jnz   .exit
      test  eax, RESULT_BIT_LEAVE
      jnz   .charLoop.asciiLoop

      jmp .charLoop

    .charLoop.unicodeOrEofLoop:
      mov  rax, qword [r12 + H5aParser.tokenizer.state]
      shl  rax, (bsr (2 * 8))
      lea  rax, [rbx + r10 * 8] ;load handler
      call qword [rax]
      
      test  eax, RESULT_BIT_AGAIN
      jnz   .exit
      test  eax, RESULT_BIT_LEAVE
      jnz   .charLoop.unicodeOrEofLoop

      jmp .charLoop

  .exit:
    pop r10
    pop rbx
    pop r12 ;caller
    xor eax,eax
    ret

section '.rodata'
public myLabelAgain
myLabelAgain:
  dd 0xBEEFCAFE
  dq _h5aTreeBuilderAcceptToken


section '.rodata'
_k_h5a_Tokenizer_common_handler_table:
  ;; Heterogenous table
  dq _k_h5a_Tokenizer_ascii_matrix ;2d
  dq _k_h5a_Tokenizer_unicode_table ;1d
  dq _k_h5a_Tokenizer_eof_table ;1d
  dq _h5aTreeBuilderAcceptToken ;!!

_k_otherTable:
  dq _h5aTreeBuilderAcceptToken

db 0x00 ;sentinel
