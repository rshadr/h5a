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

extrn _CharacterQueuePushBack
extrn _CharacterQueuePopFront
extrn _CharacterQueueSubscript

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

_h5aTokenizerEatFilterNone:
  ;; Identity filter
  ;; inout EDI: char32 c
  ret

_h5aTokenizerEatFilterCase:
  ;; Lower to upper ASCII filter
  ;; inout EDI: char32 c
  cmp edi, 'A'
  jnc .finish
  cmp edi, 'Z'
  jnc .finish

  xor edi, ('A' xor 'a')

.finish:
  ret

public _h5aTokenizerEatGeneric
_h5aTokenizerEatGeneric:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char8 const *str
  ;; RSI (a): u64 len
  ;; RDX (a): __xabi__ char32 (*filter) (char32 c)
  with_saved_regs rdi, rsi, rdx
    mov rdi, rsi
    call _h5aTokenizerPrefetchChars
  end with_saved_regs
  test al,al
  jz .fail

  push rbx
  push r13
  push r14
  push r15

  mov rbx, rdi ;str
  mov r13, rsi ;len
  mov r14, rdx ;filter
  xor r15,r15 ;index

.loop:
  cmp r15, r13
  jge .success

  ; filter buffer
  lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
  mov rsi, r15
  call _CharacterQueueSubscript
  mov esi, dword [rax]
  call r14
  mov ecx, esi

  ; filter pattern
  mov rsi, rbx
  xor eax,eax
  lodsb
  mov esi, eax
  call r14

  cmp ecx, esi
  jne .mismatch

  inc r15
  inc rbx
  jmp .loop

.mismatch:
  pop r15
  pop r14
  pop r13
  pop rbx
  xor al,al
  ret

.success:
  xor rbx,rbx

.success.popLoop:
  ; XXX: pop all at once
    cmp rbx, r13
    jge .success.finish

    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _CharacterQueuePopFront

    inc rbx
    jmp .success.popLoop

.success.finish:
  pop r15
  pop r14
  pop r13
  pop rbx

  mov al, 1
  ret

.fail:
  xor al,al
  ret

_h5aTokenizerEat:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char8 const *str
  ;; RSI (a): u64 len
  lea rdx, [_h5aTokenizerEatFilterNone]
  jmp _h5aTokenizerEatGeneric

_h5aTokenizerEatInsensitive:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char8 const *str
  ;; RSI (a): u64 len
  lea rdx, [_h5aTokenizerEatFilterCase]
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

public _h5aTokenizerPrefetchChars
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
  push r13 ;zero store
  xor rbx,rbx
  mov ebx, edi
  mov r13b, 1

.loop:
  cmp dword [r12 + H5aParser.tokenizer.input_buffer + CharacterQueue.size], ebx
  jge .finish

  mov rdi, qword [r12 + H5aParser.input_stream.user_data]
  call qword [r12 + H5aParser.input_stream.get_char_cb]
  mov edx, eax

  mov al, byte [r12 + H5aParser.tokenizer.saw_cr]
  cmp edx, 0x0A
  setne cl
  test al, cl
  jz .noWaitingCarriage

  with_saved_regs rdx
    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    xor rsi,rsi
    mov sil, 0x0A
    call _CharacterQueuePushBack
    mov rdx, rax
  end with_saved_regs

.noWaitingCarriage:
  cmp edx, 0x0D
  sete byte [r12 + H5aParser.tokenizer.saw_cr] ;forward-store
  je .noNoCarriage

.noCarriage:
  lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
  xor rsi,rsi
  mov esi, edx
  call _CharacterQueuePushBack
  mov rdx, rax

.noNoCarriage:
  not edx
  test edx,edx
  jnz .loop

.gotEof:
  mov byte [r12 + H5aParser.tokenizer.saw_eof], 1
  xor r13b,r13b ;return false
.finish:
  xor rax,rax
  mov eax, r13d
  pop r13
  pop rdx
  pop rbx
  ret

.noEof:
  jmp .loop

public _h5aTokenizerGetChar
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
      jnz .charLoop.asciiLoop
      test al, RESULT_BIT_LEAVE
      jnz .exit

      jmp .charLoop

.charLoop.unicodeOrEofLoop:
      ; XXX: remove when all states are coded
      cmp r10d, (not 0x00)
      likely je .exit

      xor rax,rax
      mov al, byte [r12 + H5aParser.tokenizer.state]
      mov rax, qword [rbx + rax * 8]
      mov rdi, r10
      call rax

      test al, RESULT_BIT_AGAIN
      jnz .charLoop.unicodeOrEofLoop
      test al, RESULT_BIT_LEAVE
      jnz .exit

      jmp .charLoop
    

.exit:
    pop rbx
    pop r10
    pop r12 ;upscope
    xor eax,eax
    ret

