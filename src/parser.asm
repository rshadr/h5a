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
extrn _h5aCharacterQueueConstruct
extrn _h5aCharacterQueueDestroy
extrn _h5aTokenizerMain


section '.text' executable

func h5aCreateParser, public
;; RDI: H5aParserCreateInfo *create_info
;; RSI: H5aParser *parser
;; -> RAX: H5aResult rc
  with_stack_frame
  with_saved_regs r12, r13
    mov r12, rsi
    mov r13, rdi

    zero_init r12, sizeof.H5aParser

    mov rax, qword [r13 + H5aParserCreateInfo.input_get_char]
    mov qword [r12 + H5aParser.input_stream.get_char_cb], rax
    mov rcx, qword [r13 + H5aParserCreateInfo.input_user_data]
    mov qword [r12 + H5aParser.input_stream.user_data], rcx
    mov rdx, qword [r13 + H5aParserCreateInfo.sink_vtable]
    mov qword [r12 + H5aParser.sink.vtable], rdx
    mov r11, qword [r13 + H5aParserCreateInfo.sink_user_data]
    mov qword [r12 + H5aParser.sink.user_data], r11

    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _h5aCharacterQueueConstruct
    lea rdi, [r12 + H5aParser.tokenizer.temp_buffer]
    call _h5aCharacterQueueConstruct

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
  end with_stack_frame

  ;mov qword [rsi + H5aParser.tokenizer.state], DATA_STATE
  ;mov qword [rsi + H5aParser.treebuilder.mode], 0

  mov eax, H5A_SUCCESS
  ret
end func


func h5aDestroyParser, public
;; RDI: H5aParser *parser
  with_saved_regs r12
    mov r12, rdi

    lea rdi, [r12 + H5aParser.tokenizer.input_buffer]
    call _h5aCharacterQueueDestroy
    lea rdi, [r12 + H5aParser.tokenizer.temp_buffer]
    call _h5aCharacterQueueDestroy

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
end func


func h5aResumeParser, public
;; RDI: H5aParser *parser
;; -> [see _h5a_Tokenizer_main]
;; Custom stack convention
  push r12
  mov  r12, rdi
  jmp _h5aTokenizerMain
end func


section '.rodata'

public k_h5a_parserSize
k_h5a_parserSize:
  dq sizeof.H5aParser

