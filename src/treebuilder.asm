
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

public _h5aTreeBuilderInsertCharacterBuffer
public _h5aTreeBuilderInsertCharacter
public _h5aTreeBuilderAcceptToken


section '.text' executable

func _h5aTreeBuilderAppendComment, public
;; R12 (s): H5aParser *parser
;; R15 (s): H5aSinkVTable *sink_vtable
;; RDI (arg): H5aString *comment
;; -> void
  with_stack_frame
    ; XXX: need stack of open elements first before continuing
  end with_stack_frame
  ret

end func

func _h5aTreeBuilderAppendCommentToDocument, public
;; R12 (s): H5aParser *parser
;; R15 (s): H5aSinkVTable *sink_vtable
;; RDI (arg): H5aString *comment
;; -> void
  with_stack_frame

    mov rcx, rdi
    mov rsi, qword [rcx + H5aString.data]
    xor rdx,rdx
    mov edx, dword [rcx + H5aString.size]
    mov rdi, qword [r12 + H5aParser.sink.user_data]
    call qword [r15 + H5aSinkVTable.create_comment]
    push rax
    push rdx

    mov rdi, qword [r12 + H5aParser.sink.user_data]
    call qword [r15 + H5aSinkVTable.get_document]
    push rax
    push rdx

    ; document handle
    mov rsi, qword [rbp - 3 * 8]
    mov rdx, qword [rbp - 4 * 8]
    ; child (comment) handle
    mov rcx, qword [rbp - 1 * 8]
    mov r8,  qword [rbp - 2 * 8]
    xor r9,r9
    ; sink
    mov rdi, qword [r12 + H5aParser.sink.user_data]
    call qword [r15 + H5aSinkVTable.append]


    ;; destroy handles
    mov rsi, qword [rbp - 3 * 8]
    mov rdx, qword [rbp - 4 * 8]
    mov rdi, qword [r12 + H5aParser.sink.user_data]
    call qword [r15 + H5aSinkVTable.destroy_handle]

    mov rsi, qword [rbp - 1 * 8]
    mov rdx, qword [rbp - 2 * 8]
    mov rdi, qword [r12 + H5aParser.sink.user_data]
    call qword [r15 + H5aSinkVTable.destroy_handle]

  end with_stack_frame
  ret
end func

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


func _h5aTreeBuilderGenericRawTextParse, public
  xor rdi,rdi
  mov dil, RAWTEXT_STATE
  jmp _h5aTreeBuilderGenericCommonParse
end func


func _h5aTreeBuilderGenericRcdataParse, public
  xor rdi,rdi
  mov dil, RCDATA_STATE
  jmp _h5aTreeBuilderGenericCommonParse
end func


func _h5aTreeBuilderCloseTagsCommon, private
;; R12 : H5aParser *parser
;; R15 : H5aSinkVTable *sink_vtable
;; RDI : H5aTag exclude
;; RSI : H5aTag *badguys
;; RDX : size_t badguys_size
;; -> void
  with_stack_frame
    sub rsp, sizeof.H5aHandle
  with_saved_regs rbx, r13, r14
    mov rbx, rsi ;badguys
    mov r13, rdx ;badguys_size
    mov r14, rdi ;exclude

    ; ...
  end with_saved_regs
  end with_stack_frame
  ret
end func


func _h5aTreeBuilderGenerateImpliedEndTags, public
;; R12 (s): H5aParser *parser
;; RDI (EDI): Tag exclude
;; -> void
  lea rsi, [_k_h5a_impliedTagsBasic]
  movzx rdx, byte [_k_h5a_impliedTagsBasic.size]
  jmp _h5aTreeBuilderCloseTagsCommon
end func


func _h5aTreeBuilderGenerateImpliedEndTagsExt, public
;; R12 (s): H5aParser *parser
;; RDI (EDI): Tag exclude
;; -> void
  lea rsi, [_k_h5a_impliedTagsExt]
  movzx rdx, byte [_k_h5a_impliedTagsExt.size]
  jmp _h5aTreeBuilderCloseTagsCommon
end func


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
    mov qword [rbp - 16], rdi
    lea rdi, [rbp - 16]
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
