
;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;


include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "tags.inc"


format ELF64

extrn _k_h5a_TreeBuilder_handlerTable

public _k_h5a_impliedTagsBasic
public _k_h5a_impliedTagsExt
public _k_h5a_impliedTagsBasic.size
public _k_h5a_impliedTagsExt.size

public _h5aTreeBuilderInsertCommentExplicit
public _h5aTreeBuilderInsertComment
public _h5aTreeBuilderInsertCharacterBuffer
public _h5aTreeBuilderInsertCharacter
public _h5aTreeBuilderGenerateImpliedEndTags
public _h5aTreeBuilderGenerateImpliedEndTagsExt
public _h5aTreeBuilderAcceptToken


section '.text' executable

_h5aTreeBuilderInsertCommentExplicit:
;; R12 (s): H5aParser *parser
;; RDI: Comment *comment
;; XXX: pos
;; -> void
  with_stack_frame
  end with_stack_frame
  ret

_h5aTreeBuilderInsertComment:
;; R12 (s); H5aParser *parser
;; RDI: Comment *comment
;; -> void
  ; XXX: fill regs
  jmp _h5aTreeBuilderInsertCommentExplicit

_h5aTreeBuilderGenericCommonParse:
;; -> void
  with_saved_regs r13
    mov r13, rdi
    ; XXX: insert
    mov byte [r12 + H5aParser.tokenizer.state], r8b
    mov cl, byte [r12 + H5aParser.treebuilder.mode]
    mov byte [r12 + H5aParser.treebuilder.original_mode], cl
    mov byte [r12 + H5aParser.treebuilder.mode], TEXT_MODE
  end with_saved_regs
  ret

_h5aTreeBuilderGenericRawTextParse:
  xor rdi,rdi
  mov dil, RAWTEXT_STATE
  jmp _h5aTreeBuilderGenericCommonParse

_h5aTreeBuilderGenericRcdataParse:
  xor rdi,rdi
  mov dil, RCDATA_STATE
  jmp _h5aTreeBuilderGenericCommonParse

_h5aTreeBuilderGenerateImpliedEndTags:
;; R12 (s): H5aParser *parser
;; RDI (EDI): Tag exclude
;; -> void
  with_stack_frame
    ; ...
  end with_stack_frame
  ret

_h5aTreeBuilderGenerateImpliedEndTagsExt:
;; R12 (s): H5aParser *parser
;; RDI (EDI): Tag exclude
;; -> void
  with_stack_frame
    ; ...
  end with_stack_frame
  ret

_h5aTreeBuilderInsertCharacterBuffer:
;; R12 (s): H5aParser *parser
;; RDI: char32_t *buff
;; RSI: size_t len
;; -> void
  with_stack_frame
  end with_stack_frame
  ret

_h5aTreeBuilderInsertCharacter:
;; R12 (s): H5aParser *parser
;; RDI (EDI): char32_t cp
;; -> void
  with_stack_frame
    sub rsp, 16
    mov qword [rbp - 0], rdi
    lea rdi, [rbp - 0]
    xor rsi,rsi
    mov sil, 1
    call _h5aTreeBuilderInsertCharacterBuffer
  end with_stack_frame
  ret

_h5aTreeBuilderAcceptToken:
  ;; R12 (s): H5aParser *parser
  ;; RDI: union token
  ;; RSI (SIL): e8 type
  ;; -> void
  with_saved_regs rbx, rcx, r13, r14, r15
    ;rcx for alignment
    lea rbx, [_k_h5a_TreeBuilder_handlerTable]
    mov r13, rdi ;token
    mov r14, rsi ;type
    mov r15, qword [r12 + H5aParser.sink.vtable]

.loop:
    xor rax,rax
    xor rcx,rcx
    mov rdi, r13
    mov rsi, r14
    mov cl, byte [r12 + H5aParser.treebuilder.mode]
    call qword [rbx + rcx * 8]

    test al, RESULT_BIT_AGAIN
    jnz .loop
    ; XXX: what about stopping/leaving?

.finish:
  end with_saved_regs
  ret


section '.rodata'

_k_h5a_impliedTagsExt:
  db H5A_TAG_CAPTION
  db H5A_TAG_COLGROUP
  db H5A_TAG_TBODY
  db H5A_TAG_TD
  db H5A_TAG_TFOOT
  db H5A_TAG_TH
  db H5A_TAG_THEAD
  db H5A_TAG_TR
_k_h5a_impliedTagsBasic:
  db H5A_TAG_DD
  db H5A_TAG_DT
  db H5A_TAG_LI
  db H5A_TAG_OPTGROUP
  db H5A_TAG_OPTION
  db H5A_TAG_P
  db H5A_TAG_RB
  db H5A_TAG_RP
  db H5A_TAG_RT
  db H5A_TAG_RTC
.end:
_k_h5a_impliedTagsExt.size:
  db (_k_h5a_impliedTagsBasic.end - _k_h5a_impliedTagsExt)
_k_h5a_impliedTagsBasic.size:
  db (_k_h5a_impliedTagsBasic.end - _k_h5a_impliedTagsBasic)
