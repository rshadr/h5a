;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "insertion_modes.g"


format ELF64

extrn _h5aTreeBuilderAppendCommentToDocument

public _k_h5a_TreeBuilder_handlerTable

section '.text'

_h5aTreeBuilderHandler.DUMMY:
  cmp dil, TOKEN_EOF
  je _h5aTreeBuilderHandler.DUMMY.eof
  xor al,al
  ret
_h5aTreeBuilderHandler.DUMMY.eof:
  mov al, RESULT_EOF_REACHED
  ret

quirksCheck:
  ; ...
  xor rax,rax
  ret

limitedQuirksCheck:
  ; ...
  xor rax,rax
  ret


mode initial,INITIAL_MODE

  [[Whitespace]]
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendCommentToDocument
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
;public the_razor
;label the_razor

    namespace initial_doctype
      with_stack_frame
.check1:
        ; ...
        mov al, byte [r13 + DoctypeToken.have_public_id]
        test al,al
        jnz .action1
        mov al, byte [r13 + DoctypeToken.have_system_id]
        jz .action2
        ; ...
.action1:
        ; XXX: parse error
.action2:
public razor
label razor
        mov rdi, qword [r12 + H5aParser.sink.user_data]

        mov rsi, qword [r13 + DoctypeToken.name + H5aString.data]
        xor rdx,rdx
        mov edx, dword [r13 + DoctypeToken.name + H5aString.size]

        xor rcx,rcx
        xor r8,r8
        mov al, byte [r13 + DoctypeToken.have_public_id]
        test al,al
        cmovnz rcx, qword [r13 + DoctypeToken.public_id + H5aString.data]
        cmovnz r8d, dword [r13 + DoctypeToken.public_id + H5aString.size]

        xor r9,r9
        xor r11,r11
        mov al, byte [r13 + DoctypeToken.have_system_id]
        test al,al
        cmovnz r8, qword [r13 + DoctypeToken.system_id + H5aString.data]
        cmovnz r11d, dword [r13 + DoctypeToken.system_id + H5aString.size]
        xor rax,rax
        push rax
        push r11
  
        call qword [r15 + H5aSinkVTable.append_doctype_to_document]

.check3:
        call quirksCheck
        test al,al
        jz .check4
.action3:
        mov rdi, qword [r12 + H5aParser.sink.user_data]
        xor rsi,rsi
        mov sil, H5A_QUIRKS_MODE_QUIRKS
        call qword [r15 + H5aSinkVTable.set_quirks_mode]
        jmp .finish

.check4:
        call limitedQuirksCheck
        test al,al
        jz .finish
.action4:
        mov rdi, qword [r12 + H5aParser.sink.user_data]
        xor rsi,rsi
        mov sil, H5A_QUIRKS_MODE_LIMITED_QUIRKS
        call qword [r12 + H5aSinkVTable.set_quirks_mode]
.finish:
        mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
      end with_stack_frame
      xor al,al
      ret
    end namespace

  [[Anything else]]
    namespace initial.anythingElse
      with_stack_frame
        ; ...
        mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
      end with_stack_frame
      mov al, RESULT_REPROCESS
      ret
    end namespace

end mode


mode beforeHtml,BEFORE_HTML_MODE

  [[DOCTYPE]]
    with_stack_frame
      parse_error!
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendCommentToDocument
    end with_stack_frame
    xor al,al
    ret

  [[Whitespace]]
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag "head"]]
  [[End tag "body"]]
  [[End tag "html"]]
  [[End tag "br"]]
    goto! anything_else

  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HEAD_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode beforeHead,BEFORE_HEAD_MODE

  [[Whitespace]]
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "head"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    xor al,al
    ret

  [[End tag "head"]]
  [[End tag "body"]]
  [[End tag "html"]]
  [[End tag "br"]]
    goto! anything_else

  [[Any other end tag]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    mov al, RESULT_REPROCESS
    ret

end mode


; ...


mode inBody,IN_BODY_MODE

  [[Character U+0000]]
    with_stack_frame
      ; ...
      mov al, RESULT_IGNORE
    end with_stack_frame
    ret

  [[Whitespace]]
    with_stack_frame
      ; XXX: reconstruct
      ; XXX: insert character
    end with_stack_frame
    ret

  [[Any other character]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ret

  ; ...

  [[Any other start tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Anything else]]
    unimplemented

end mode


; ...


mode inTableText,IN_TABLE_TEXT_MODE

  [[Character U+0000]]
    ; XXX: check null
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Any other character]]
    ; ...
    xor al,al
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov cl, byte [r12 + H5aParser.treebuilder.original_mode]
      mov byte [r12 + H5aParser.treebuilder.mode], cl
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret
end mode


; ...


mode inColumnGroup,IN_COLUMN_GROUP_MODE

  [[Whitespace]]
    ; XXX: insert character
    xor al,al
    ret

  [[Comment]]
    ; XXX: insert comment
    xor al,al
    ret

  [[DOCTYPE]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "col"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag "colgroup"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag "col"]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag "template"]]
  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

  [[EOF]]
    process_using_rules! IN_BODY_MODE

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    mov al, RESULT_RECONSUME
    ret

end mode


mode inTableBody,IN_TABLE_BODY_MODE

  [[Start tag "tr"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    xor al,al
    ret

  [[Start tag "th"]]
  [[Start tag "td"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    mov al, RESULT_REPROCESS
    ret

  [[End tag "tbody"]]
  [[End tag "tfoot"]]
  [[End tag "thead"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    xor al,al
    ret

  [[Start tag "col"]]
  [[Start tag "colgroup"]]
  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
  [[End tag "table"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    mov al, RESULT_REPROCESS
    ret

  [[End tag "body"]]
  [[End tag "caption"]]
  [[End tag "colgroup"]]
  [[End tag "html"]]
  [[End tag "td"]]
  [[End tag "th"]]
  [[End tag "tr"]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    process_using_rules! IN_TABLE_MODE

end mode


mode inRow,IN_ROW_MODE

  [[Start tag "th"]]
  [[Start tag "td"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_CELL_MODE
    xor al,al
    ret

  [[End tag "tr"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    xor al,al
    ret

  [[Start tag "caption"]]
  [[Start tag "col"]]
  [[Start tag "colgroup"]]
  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
  [[Start tag "tr"]]
  [[End tag "table"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    mov al, RESULT_REPROCESS
    ret

  [[End tag "tbody"]]
  [[End tag "tfoot"]]
  [[End tag "thead"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    mov al, RESULT_REPROCESS
    ret

  [[Anything else]]
    process_using_rules! IN_TABLE_MODE

end mode


close_cell:
  with_stack_frame
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
  end with_stack_frame
  ret

mode inCell,IN_CELL_MODE

  [[End tag "td"]]
  [[End tag "th"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    xor al,al
    ret

  [[Start tag "caption"]]
  [[Start tag "col"]]
  [[Start tag "colgroup"]]
  [[Start tag "tbody"]]
  [[Start tag "td"]]
  [[Start tag "tfoot"]]
  [[Start tag "th"]]
  [[Start tag "thead"]]
  [[Start tag "tr"]]
    ; ...
    mov al, RESULT_REPROCESS
    ret

  [[End tag "body"]]
  [[End tag "caption"]]
  [[End tag "col"]]
  [[End tag "colgroup"]]
  [[End tag "html"]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[End tag "table"]]
  [[End tag "tbody"]]
  [[End tag "tfoot"]]
  [[End tag "thead"]]
  [[End tag "tr"]]
    ; ...
    mov al, RESULT_REPROCESS
    ret

  [[Anything else]]
    process_using_rules! IN_BODY_MODE

end mode


; ...
section '.rodata'
  generate_tables

public myLabel
myLabel:
  dq 0x90
