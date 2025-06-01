;;;;
;;;; Copyright 2024 rshadr
;;;; See LICENSE for details
;;;;
include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn _h5aStringCreate
extrn _h5aStringDestroy
extrn _CharacterQueueConstruct
extrn _CharacterQueueDestroy
extrn _h5aTokenizerMain

public h5aCreateParser
public h5aDestroyParser
public h5aResumeParser
public k_h5a_parserSize


section '.text' executable

h5aCreateParser:
;; RDI: H5aParserCreateInfo *create_info
;; RSI: H5aParser *parser
  push rbp
  mov rbp, rsp

  with_saved_regs r12, r13
    mov r12, rsi
    mov r13, rdi

    mov rdi, r12
    xor al,al
    mov rcx, sizeof.H5aParser
    rep stosb

    mov rax, qword [r13 + H5aParserCreateInfo.input_get_char]
    mov qword [r12 + H5aParser.input_stream.get_char_cb], rax
    mov rcx, qword [r13 + H5aParserCreateInfo.input_user_data]
    mov qword [r12 + H5aParser.input_stream.user_data], rcx
    mov rdx, qword [r13 + H5aParserCreateInfo.sink_vtable]
    mov qword [r12 + H5aParser.sink.vtable], rdx
    mov r11, qword [r13 + H5aParserCreateInfo.sink_user_data]
    mov qword [r12 + H5aParser.sink.user_data], r11

    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _CharacterQueueConstruct
    lea rdi, [r12 + H5aParser.tokenizer.temp_buffer]
    call _CharacterQueueConstruct

    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.name]
    call _h5aStringCreate
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.public_id]
    call _h5aStringCreate
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.system_id]
    call _h5aStringCreate

    lea rdi, [r12 + H5aParser.tokenizer.comment]
    call _h5aStringCreate

    lea rdi, [r12 + H5aParser.tokenizer.tag + TagToken.name]
    call _h5aStringCreate

    ; XXX: attributes

  end with_saved_regs

  ;mov qword [rsi + H5aParser.tokenizer.state], DATA_STATE
  ;mov qword [rsi + H5aParser.treebuilder.mode], 0

  mov eax, H5A_SUCCESS

  leave
  ret

h5aDestroyParser:
;; RDI: H5aParser *parser
  with_saved_regs r12
    mov r12, rdi

    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _CharacterQueueDestroy
    lea rdi, [r12 + H5aParser.tokenizer.temp_buffer]
    call _CharacterQueueDestroy

    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.name]
    call _h5aStringDestroy
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.public_id]
    call _h5aStringDestroy
    lea rdi, [r12 + H5aParser.tokenizer.doctype + DoctypeToken.system_id]
    call _h5aStringDestroy

    lea rdi, [r12 + H5aParser.tokenizer.comment]
    call _h5aStringDestroy

    lea rdi, [r12 + H5aParser.tokenizer.tag + TagToken.name]
    call _h5aStringDestroy

  end with_saved_regs

  mov eax, H5A_SUCCESS
  ret

h5aResumeParser:
;; RDI: H5aParser *parser
;; -> [see _h5a_Tokenizer_main]
  push r12
  mov  r12, rdi
  jmp _h5aTokenizerMain

section '.rodata'

k_h5a_parserSize:
  dq sizeof.H5aParser

