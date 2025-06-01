;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
include 'align.inc'
include 'macro/struct.inc'
include "util.inc"
include "local.inc"

format ELF64


extrn _h5aStringClear
extrn _CharacterQueuePushBack
extrn _CharacterQueuePopFront
extrn _CharacterQueueSubscript
extrn _h5aTreeBuilderAcceptToken

extrn _k_h5a_Tokenizer_flags_table
extrn _k_h5a_Tokenizer_spc_action_table
extrn _k_h5a_Tokenizer_common_dispatch_table

public _h5aTokenizerError
public _h5aTokenizerEat
public _h5aTokenizerEatSensitive
public _h5aTokenizerEatInsensitive
public _h5aTokenizerCreateDoctype
public _h5aTokenizerCreateComment
public _h5aTokenizerCreateStartTag
public _h5aTokenizerCreateEndTag
public _h5aTokenizerStartAttribute
public _h5aTokenizerEmitDoctype
public _h5aTokenizerEmitComment
public _h5aTokenizerEmitCharacter
public _h5aTokenizerEmitTag
public _h5aTokenizerEmitEof
public _h5aTokenizerHaveAppropriateEndTag
public _h5aTokenizerFlushEntityChars
public _h5aTokenizerCharRefInAttr
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

  xor dil, ('A' xor 'a')

.finish:
  ret

public _h5aTokenizerEatGeneric
_h5aTokenizerEatGeneric:
  ;; R12 (s): H5aParser *parser
  ;; RDI (a): char8 const *str
  ;; RSI (a): u64 len
  ;; RDX (a): __xabi__ char32 (*filter) (char32 c)
  push rbp
  mov rbp, rsp

  with_saved_regs rdi, rsi, rdx, rcx
    ; RCX for stack alignment
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
  leave
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
  leave
  ret

.fail:
  xor al,al
  leave
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

_h5aTokenizerEatSensitive:
  lea rdx, [_h5aTokenizerEatFilterNone]
  jmp _h5aTokenizerEatGeneric

_h5aTokenizerCreateDoctype:
  ;; R12 (s): H5aParser *parser
  with_stack_frame
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.name]
    call _h5aStringClear
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.public_id]
    call _h5aStringClear
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.system_id]
    call _h5aStringClear
    mov byte [r12 + H5aParser.tokenizer.doctype + DoctypeToken.have_public_id], 0x00
    mov byte [r12 + H5aParser.tokenizer.doctype + DoctypeToken.have_system_id], 0x00
    mov byte [r12 + H5aParser.tokenizer.doctype + DoctypeToken.force_quirks_flag], 0x00
  end with_stack_frame
  ret

_h5aTokenizerCreateComment:
;; R12 (s): H5aParser *parser
  with_stack_frame
    lea rdi, [r12 + H5aParser.tokenizer.comment]
    call _h5aStringClear
  end with_stack_frame
  ret

_h5aTokenizerCreateTag:
;; R12 (s): H5aParser *parser
;; RDI (arg): H5aTokenType type
;; -> void
  with_stack_frame
    mov byte [r12 + H5aParser.tokenizer.tag_type], dil
    lea rdi, [r12 + H5aParser.tokenizer.tag + TagToken.name]
    call _h5aStringClear
    ; XXX: clear attributes
    xor al,al
    mov byte [r12 + H5aParser.tokenizer.tag + TagToken.self_closing_flag], al
    mov byte [r12 + H5aParser.tokenizer.tag + TagToken.acknowledged_self_closing_flag], al
  end with_stack_frame
  ret

_h5aTokenizerCreateStartTag:
  xor rdi,rdi
  mov dil, TOKEN_START_TAG
  jmp _h5aTokenizerCreateTag

_h5aTokenizerCreateEndTag:
  xor rdi,rdi
  mov dil, TOKEN_END_TAG
  jmp _h5aTokenizerCreateTag

_h5aTokenizerStartAttribute:
; XXX ...
  ret

public _h5aTokenizerEmitToken
_h5aTokenizerEmitToken:
;; R12 (s): H5aParser *parser
;; RDI (a): union Token token
;; RSI (a): e8 type
;; -> void
  with_stack_frame
    call _h5aTreeBuilderAcceptToken
  end with_stack_frame
  ret


_h5aTokenizerEmitDoctype:
;; R12 (s): H5aParser *parser
  lea rdi, [r12 + H5aParser.tokenizer.doctype]
  xor rsi,rsi
  mov sil, TOKEN_DOCTYPE
  jmp _h5aTokenizerEmitToken


_h5aTokenizerEmitComment:
;; R12 (s): H5aParser *parser
  lea rdi, [r12 + H5aParser.tokenizer.comment]
  xor rsi,rsi
  mov sil, TOKEN_COMMENT
  jmp _h5aTokenizerEmitToken


_h5aTokenizerEmitCharacter:
;; R12 (s): H5aParser *parser
;; RDI (EDI): char32_t c
;; -> void
  xor rsi,rsi
  mov sil, TOKEN_CHARACTER

  cmp esi, 0x09
  je .yes
  cmp esi, 0x0A
  je .yes
  cmp esi, 0x0C
  je .yes
  cmp esi, 0x20
  je .yes

.no:
  jmp _h5aTokenizerEmitToken

.yes:
  mov sil, TOKEN_WHITESPACE
  jmp _h5aTokenizerEmitToken


_h5aTokenizerEmitTag:
;; R12 (s): H5aParser *parser
;; -> void
  lea rdi, [r12 + H5aParser.tokenizer.tag]
  ; XXX
  ;movzx rsi, byte [r12 + H5aParser.tokeniz
  jmp _h5aTokenizerEmitToken


_h5aTokenizerEmitEof:
  ;; R12 (s): H5aParser *parser
  ;; [...]
  ;; -> uint8 status
  push rbp
  mov rbp, rsp

  xor edi,edi
  mov sil, TOKEN_EOF
  call _h5aTokenizerEmitToken
  mov al, RESULT_EOF_REACHED

  leave
  ret


_h5aTokenizerHaveAppropriateEndTag:
  ;; R12 (s): H5aParser *parser
  ;; -> RAX (AL): bool result
  push rbp
  mov rbp, rsp
  ;...
  xor rax,rax
  leave
  ret


_h5aTokenizerFlushEntityChars:
  ;; R12 (s): H5aParser *parser
  ;; -> void
  push rbp
  mov rbp, rsp

with_saved_regs r8, rbx
    call _h5aTokenizerCharRefInAttr
    mov r8b, al

.loop:
    mov eax, dword [r12 + H5aParser.tokenizer.input_buffer + CharacterQueue.size]
    test eax,eax
    jz .finish

    ; ...

    jmp .loop

.finish:
end with_saved_regs
  leave
  ret

_h5aTokenizerCharRefInAttr:
  ;; R12 (s): H5aParser *parser
  ;; -> RAX (AL): bool result
  xor rax,rax
  mov cl, byte [r12 + H5aParser.tokenizer.state]

  cmp cl, ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE
  je .yes
  cmp cl, ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE
  je .yes
  cmp cl, ATTRIBUTE_VALUE_UNQUOTED_STATE
  je .yes

  ret

.yes:
  mov al, 1
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

  push rcx ;stack-align
  push rbx ;count store
  push rdx ;char store
  push r13 ;zero store
  xor rbx,rbx
  mov ebx, edi
  mov r13b, 1
  ;;sub ebx, dword [r12 + H5aParser.tokenizer.input_buffer + CharacterQueue.size]

.loop:
  ;cmp dword [r12 + H5aParser.tokenizer.input_buffer + CharacterQueue.size], ebx
  mov ecx, dword [r12 + H5aParser.tokenizer.input_buffer + CharacterQueue.size]
  cmp ecx, ebx
  jge .finish

  mov rdi, qword [r12 + H5aParser.input_stream.user_data]
  call qword [r12 + H5aParser.input_stream.get_char_cb]
  mov edx, eax

  mov al, byte [r12 + H5aParser.tokenizer.saw_cr]
  cmp edx, 0x0A
  setne cl
  test al, cl
  jz .noWaitingCarriage

  with_saved_regs rdx, rcx
    ; also push RCX for stack-align
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
  ; falltrough
.finish:
  xor rax,rax
  mov eax, r13d
  pop r13
  pop rdx
  pop rbx
  pop rcx ;stack-align
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
  lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
  call _CharacterQueuePopFront

  ret


_h5aTokenizerMain:
;; stack entry: [r12, RET]
;; R12 (omni:lost): H5aParser *
;; -> EAX: enum H5aResult
  push r13
  push rbx
  xor r13,r13

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
      lea rdx, [_k_h5a_Tokenizer_spc_action_table]
      mov rcx, qword [rdx + rax * 8]
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
      jmp .charLoop
      
.charLoop.readChar:
      ;;mov  rdi, qword [r12 + H5aParser.input_stream.user_data]
      ;;call qword [r12 + H5aParser.input_stream.get_char_cb]
      call _h5aTokenizerGetChar
      mov  r13d, eax

.charLoop.hashChar:
      ;; hash result (RAX):
      ;;  0x00 : ASCII codepoint   (< 0x007F)
      ;;  0x01 : Unicode codepoint (> 0x007F and != ~0x00)
      ;;  0x02 : EOF               (== ~0x00)
      xor rax,rax
      xor rdi,rdi

      cmp   r13d, 0x7F
      seta  al
      cmp   r13d, (not 0x00)
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
      mov    rax, qword [rax + r13 * 8] ;load handler
      mov    rdi, r13
      call   rax

      test al, RESULT_BIT_AGAIN
      jnz .charLoop.asciiLoop
      test al, RESULT_BIT_LEAVE
      jnz .exit

      jmp .charLoop

.charLoop.unicodeOrEofLoop:
      ; XXX: remove when all states are coded
      cmp r13d, (not 0x00)
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
    pop r13
    pop r12 ;upscope
    xor rax,rax
    ret

