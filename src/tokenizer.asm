;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn _k_h5a_Tokenizer_flags_table
extrn _k_h5a_Tokenizer_spc_action_table
extrn _k_h5a_Tokenizer_common_dispatch_table

public _h5aTokenizerError
public _h5aTokenizerEat
public _h5aTokenizerEatInsensitive
public _h5aTokenizerEmitCharacter
public _h5aTokenizerEmitEof
public _h5aTokenizerMain


section '.text' executable

_h5aTokenizerError:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char const *errmsg
  ;; -> void
  ret

_h5aTokenizerEatGeneric:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char8 const *str
  ;; RSI (a): u64 len
  ;; RDX (a): __asm__ char32 (*filter) (char32 c)
  xor al,al
  ret

_h5aTokenizerEat:
  ;; ...
  jmp _h5aTokenizerEatGeneric

_h5aTokenizerEatInsensitive:
  ;; ...
  jmp _h5aTokenizerEatGeneric

_h5aTokenizerEmitToken:
  ;; ...
  xor al,al
  ret

_h5aTokenizerEmitCharacter:
;; R12 (s): H5aParser *parser
;; -> void
  jmp _h5aTokenizerEmitToken

_h5aTokenizerEmitEof:
  ;; R12 (s): H5aParser *parser
  ;; [...]
  ;; -> uint8 status
  xor edi,edi
  mov sil, TOKEN_EOF
  call _h5aTokenizerEmitToken
  mov al, RESULT_EOF_REACHED
  ret

_h5aTokenizerPrefetchChars:
;; R12 (omni): H5aParser *parser
;; RDI (a): u32 count
;; -> bool have_that_many

  mov al, byte [r12 + H5aParser.tokenizer.saw_eof]
  test al,al
  likely jz .inputLeft

  xor rax,rax
  ret

.inputLeft:

  push rbx ;count store
  push rdx ;char store
  push r13 ;[zero store
  mov ebx, edi
  mov r13b, 1

.loop:
  ;cmp dword [r12 + H5aParser.input_buffer.size], rbx ;!!!
  cmp rbx, 0
  ; XXX
  jge .finish

  mov rdi, qword [r12 + H5aParser.input_stream.user_data]
  call qword [r12 + H5aParser.input_stream.get_char_cb]
  mov edx, eax

  mov al, byte [r12 + H5aParser.tokenizer.saw_eof]
  cmp edx, '\n'
  setne cl
  test al,cl
  jz .noWaitingCarriage

  ; XXX: push_back '\n'

.noWaitingCarriage:
  cmp edx, '\r'
  sete byte [r12 + H5aParser.tokenizer.saw_cr] ;forward-store
  setne al

  test al,al
  jnz .noCarriage

.noCarriage:
  ; XXX: push_back c

  not edx
  test edx,edx
  jnz .noEof

  mov byte [r12 + H5aParser.tokenizer.saw_eof], 1
  xor r13b,r13b
.finish:
  xor rax,rax
  mov eax, r13d
  pop r13
  pop rdx
  pop rbx
  ret

.noEof:
  jmp .loop


_h5aTokenizerGetChar:
;; R12 (omni): H5aParser *parser

  xor rdi,rdi
  mov dil, 1
  call _h5aTokenizerPrefetchChars

  ; XXX: assert not empty

  xor eax,eax; XXX: pop_back
  ret


_h5aTokenizerMain:
;; R12 (omni:lost): H5aParser *
;; -> EAX: enum H5aResult
  push r10
  push rbx
  xor r10,r10

.charLoop:
  ; XXX: check SPC_ACTION
    lea  rbx, [_k_h5a_Tokenizer_flags_table]

    ;; Valgrind can't XLAT arrgh!!
    ;mov  al, byte [r12 + H5aParser.tokenizer.state]
    ;xlatb
    movzx rcx, byte [r12 + H5aParser.tokenizer.state]
    movzx rax, byte [rbx + rcx * 1]

    mov  bl, al
    test bl, STATE_BIT_SPC_ACTION
    likely jz .charLoop.afterSpcAction

.charLoop.spcAction:
      movzx rax, byte [r12 + H5aParser.tokenizer.state]
      lea rcx, [_k_h5a_Tokenizer_spc_action_table]
      mov rcx, [rcx + rax * 8]
      ;;push rbx
      call rcx
      ;;pop rbx
      test al, RESULT_BIT_PARTIAL
      likely jnz .charLoop
      nop
.charLoop.afterSpcAction:
      test bl, STATE_BIT_NO_GETCHAR
      likely jz .charLoop.readChar
      nop
      unlikely jmp .charLoop
      
.charLoop.readChar:
      mov  rdi, qword [r12 + H5aParser.input_stream.user_data]
      call qword [r12 + H5aParser.input_stream.get_char_cb]
      mov  r10d, eax

.charLoop.hashChar:
      ;; hash result (RAX):
      ;;  0x00 : ASCII codepoint   (< 0x007F)
      ;;  0x01 : Unicode codepoint (> 0x007F and != ~0x00)
      ;;  0x02 : EOF               (== ~0x00)
      xor rax,rax
      xor rdi,rdi

      cmp   r10d, 0x7F
      seta  al
      cmp   r10d, (not 0x00)
      sete  dil
      add   al, dil


.charLoop.dispatchCommon:
      lea  rbx, [_k_h5a_Tokenizer_common_dispatch_table]
      mov  rbx, qword [rbx + rax * 8]
      test al,al ;Unicode/EOF?
      unlikely jnz .charLoop.unicodeOrEofLoop

.charLoop.asciiLoop:
      movzx  rax, byte [r12 + H5aParser.tokenizer.state]
      shl    rax, (bsr (128 * 8))
      lea    rax, [rbx + rax] ;load state LUT base
      mov    rax, qword [rax + r10 * 8] ;load handler
      mov    rdi, r10
      call   rax

      test al, RESULT_BIT_AGAIN
      jnz .exit
      test al, RESULT_BIT_LEAVE
      jnz .charLoop.asciiLoop

      jmp .charLoop

.charLoop.unicodeOrEofLoop:
      ; XXX: remove when all states are coded
      cmp r10d, (not 0x00)
      likely je .exit

      xor rax,rax
      mov al, byte [r12 + H5aParser.tokenizer.state]
      mov rax, qword [rbx + rax * 8]
      call rax

      test al, RESULT_BIT_AGAIN
      jnz .exit
      test al, RESULT_BIT_LEAVE
      jnz .charLoop.unicodeOrEofLoop

      jmp .charLoop
    

.exit:
    pop rbx
    pop r10
    pop r12 ;upscope
    xor eax,eax
    ret

