;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "insertion_modes.g"


format ELF64

extrn _h5aTreeBuilderAppendComment
extrn _h5aTreeBuilderAppendCommentToDocument
extrn _h5aTreeBuilderGenericRcdataParse
extrn _h5aTreeBuilderGenericRawTextParse

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
        call qword [r15 + H5aSinkVTable.set_quirks_mode]
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
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "head"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    end with_stack_frame
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


mode inHead,IN_HEAD_MODE

  [[Whitespace]]
    with_stack_frame
      ;call _h5aTreeBuilderInsertCharacter
    end with_stack_frame
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "base"]]
  [[Start tag "basefont"]]
  [[Start tag "bgsound"]]
  [[Start tag "link"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "meta"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "title"]]
    jmp _h5aTreeBuilderGenericRcdataParse


namespace noscript_and_clique

  [[Start tag "noscript"]]
    ; XXX: test
    xor al,al
    test al,al
    jz noscript_scripting_enabled
noscript_scripting_disabled:
    with_stack_frame
      ;XXX: insert element
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_NOSCRIPT_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "noframes"]]
  [[Start tag "style"]]
noscript_scripting_enabled:
    jmp _h5aTreeBuilderGenericRawTextParse

end namespace


  [[Start tag "script"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
      mov cl, byte [r12 + H5aParser.treebuilder.mode]
      mov byte [r12 + H5aParser.treebuilder.original_mode], cl
      mov byte [r12 + H5aParser.treebuilder.mode], TEXT_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag "head"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag "body"]]
  [[End tag "html"]]
  [[End tag "br"]]
    goto! anything_else

  [[Start tag "template"]]
    ; ...
    xor al,al
    ret

  [[End tag "template"]]
    ; ...
    xor al,al
    ret

  [[Start tag "head"]]
  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_HEAD_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode inHeadNoscript,IN_HEAD_NOSCRIPT_MODE

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[End tag "noscript"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Whitespace]]
  [[Comment]]
  [[Start tag "basefont"]]
  [[Start tag "bgsound"]]
  [[Start tag "link"]]
  [[Start tag "meta"]]
  [[Start tag "noframes"]]
    process_using_rules! IN_HEAD_MODE

  [[End tag "br"]]
    goto! anything_else

  [[Start tag "head"]]
  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    with_stack_frame
    ;parse_error!
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode afterHead,AFTER_HEAD_MODE

  [[Whitespace]]
    ; ...
    xor al,al
    ret

  [[Comment]]
    ; ...
    xor al,al
    ret

  [[DOCTYPE]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "body"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "frameset"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_FRAMESET_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "base"]]
  [[Start tag "basefont"]]
  [[Start tag "bgsound"]]
  [[Start tag "link"]]
  [[Start tag "meta"]]
  [[Start tag "noframes"]]
  [[Start tag "script"]]
  [[Start tag "style"]]
  [[Start tag "template"]]
  [[Start tag "title"]]
    with_stack_frame
      ; ...
      call_rules! IN_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

  [[End tag "body"]]
  [[End tag "html"]]
  [[End tag "br"]]
    goto! anything_else

  [[Start tag "head"]]
  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode inBody,IN_BODY_MODE

  [[Character U+0000]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Whitespace]]
    with_stack_frame
      ; XXX: reconstruct
      ; XXX: insert character
    end with_stack_frame
    xor al,al
    ret

  [[Any other character]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "base"]]
  [[Start tag "basefont"]]
  [[Start tag "bgsound"]]
  [[Start tag "link"]]
  [[Start tag "meta"]]
  [[Start tag "noframes"]]
  [[Start tag "script"]]
  [[Start tag "style"]]
  [[Start tag "template"]]
  [[Start tag "title"]]
  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag "body"]]
    ; ...
    xor al,al
    ret

  [[Start tag "frameset"]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    mov al, RESULT_STOP
    ret

  [[End tag "body"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag "html"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "address"]]
  [[Start tag "article"]]
  [[Start tag "aside"]]
  [[Start tag "blockquote"]]
  [[Start tag "center"]]
  [[Start tag "details"]]
  [[Start tag "dialog"]]
  [[Start tag "dir"]]
  [[Start tag "div"]]
  [[Start tag "dl"]]
  [[Start tag "fieldset"]]
  [[Start tag "figcaption"]]
  [[Start tag "figure"]]
  [[Start tag "footer"]]
  [[Start tag "header"]]
  [[Start tag "hgroup"]]
  [[Start tag "main"]]
  [[Start tag "menu"]]
  [[Start tag "nav"]]
  [[Start tag "ol"]]
  [[Start tag "p"]]
  [[Start tag "search"]]
  [[Start tag "section"]]
  [[Start tag "summary"]]
  [[Start tag "ul"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
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


mode text,TEXT_MODE

  [[Character]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag "script"]]
    unimplemented
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


mode inTable,IN_TABLE_MODE

  [[Character]]
    ; ...
    goto! anything_else

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "caption"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_CAPTION_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "colgroup"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "col"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "td"]]
  [[Start tag "th"]]
  [[Start tag "tr"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "table"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag "table"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag "body"]]
  [[End tag "caption"]]
  [[End tag "col"]]
  [[End tag "colgroup"]]
  [[End tag "html"]]
  [[End tag "tbody"]]
  [[End tag "td"]]
  [[End tag "tfoot"]]
  [[End tag "th"]]
  [[End tag "thead"]]
  [[End tag "tr"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "style"]]
  [[Start tag "script"]]
  [[Start tag "template"]]
  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag "input"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "form"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[EOF]]
    process_using_rules! IN_BODY_MODE

  [[Anything else]]
    with_stack_frame
      mov byte [r12 + H5aParser.flags.foster_parenting], 0x1
      call_rules! IN_BODY_MODE
      mov byte [r12 + H5aParser.flags.foster_parenting], 0x0
    end with_stack_frame
    ;xor al,al ;al already set?
    ret
  
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
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
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
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "th"]]
  [[Start tag "td"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag "tbody"]]
  [[End tag "tfoot"]]
  [[End tag "thead"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "col"]]
  [[Start tag "colgroup"]]
  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
  [[End tag "table"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag "body"]]
  [[End tag "caption"]]
  [[End tag "colgroup"]]
  [[End tag "html"]]
  [[End tag "td"]]
  [[End tag "th"]]
  [[End tag "tr"]]
    with_stack_frame
      ; ...
    end with_stack_frame
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


mode inSelect,IN_SELECT_MODE
  [[Character U+0000]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Any other character]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "option"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "optgroup"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "hr"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag "optgroup"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[End tag "option"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[End tag "select"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "select"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "input"]]
  [[Start tag "keygen"]]
  [[Start tag "textarea"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "script"]]
  [[Start tag "template"]]
  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

    
  [[EOF]]
    process_using_rules! IN_BODY_MODE

  [[Anything else]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

end mode


mode inSelectInTable,IN_SELECT_IN_TABLE_MODE

  [[Start tag "caption"]]
  [[Start tag "table"]]
  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
  [[Start tag "tr"]]
  [[Start tag "td"]]
  [[Start tag "th"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag "caption"]]
  [[End tag "table"]]
  [[End tag "tbody"]]
  [[End tag "tfoot"]]
  [[End tag "thead"]]
  [[End tag "tr"]]
  [[End tag "td"]]
  [[End tag "th"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    unimplemented
    mov al, RESULT_REPROCESS
    ret

  [[Anything else]]
    process_using_rules! IN_SELECT_MODE

end mode


mode inTemplate, IN_TEMPLATE_MODE

  [[Character]]
  [[Comment]]
  [[DOCTYPE]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "base"]]
  [[Start tag "basefont"]]
  [[Start tag "bgsound"]]
  [[Start tag "link"]]
  [[Start tag "meta"]]
  [[Start tag "noframes"]]
  [[Start tag "script"]]
  [[Start tag "style"]]
  [[Start tag "template"]]
  [[Start tag "title"]]
  [[End tag "template"]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag "caption"]]
  [[Start tag "colgroup"]]
  [[Start tag "tbody"]]
  [[Start tag "tfoot"]]
  [[Start tag "thead"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "col"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "tr"]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag "td"]]
  [[Start tag "th"]]
    with_stack_frame
      ;...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Any other start tag]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Any other end tag]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[EOF]]
    unimplemented
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Anything else]]
    unimplemented

end mode


mode afterBody,AFTER_BODY_MODE

  [[Whitespace]]
    process_using_rules! IN_BODY_MODE

  [[Comment]]
    ; ...
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[End tag "html"]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], AFTER_AFTER_BODY_MODE
    xor al,al
    ret

  [[EOF]]
    mov al, RESULT_STOP
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode inFrameset,IN_FRAMESET_MODE

  [[Whitespace]]
    ; ...
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[Start tag "frameset"]]
    ; ...
    xor al,al
    ret

  [[End tag "frameset"]]
    with_stack_frame
      ; ...
      xor al,al ;!!
      ;cmovz byte [r12 + H5aParser.treebuilder.mode], AFTER_FRAMESET_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "frame"]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag "noframes"]]
    process_using_rules! IN_HEAD_MODE

  [[EOF]]
    ;...
    mov al, RESULT_STOP
    ret

  [[Anything else]]
    ; ...
    mov al, RESULT_IGNORE
    ret

end mode


mode afterFrameset,AFTER_FRAMESET_MODE

  [[Whitespace]]
    ; ...
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[End tag "html"]]
    mov byte [r12 + H5aParser.treebuilder.mode], AFTER_AFTER_FRAMESET_MODE
    xor al,al
    ret

  [[EOF]]
    mov al, RESULT_STOP
    ret

  [[Anything else]]
    ; ...
    mov al, RESULT_IGNORE
    ret

end mode


mode afterAfterBody,AFTER_AFTER_BODY_MODE

  [[Comment]]
    with_stack_frame
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
  [[Whitespace]]
  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[EOF]]
    mov al, RESULT_STOP
    ret

  [[Anything else]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

end mode


mode afterAfterFrameset,AFTER_AFTER_FRAMESET_MODE

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendCommentToDocument
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
  [[Whitespace]]
  [[Start tag "html"]]
    process_using_rules! IN_BODY_MODE

  [[EOF]]
    mov al, RESULT_STOP
    ret

  [[Start tag "noframes"]]
    process_using_rules! IN_HEAD_MODE

  [[Anything else]]
    ; ...
    mov al, RESULT_IGNORE
    ret

end mode


;; not accessible by the table
mode inForeignContent,IN_FOREIGN_CONTENT_MODE

  [[Character U+0000]]
    ; ...
    xor al,al
    ret

  [[Whitespace]]
    ; ...
    xor al,al
    ret

  [[Any other character]]
    ; ...
    xor al,al
    ret

  [[Comment]]
    with_stack_frame
      call _h5aTreeBuilderAppendComment
    end with_stack_frame
    xor al,al
    ret

  [[DOCTYPE]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag "b"]]
  [[Start tag "big"]]
  [[Start tag "blockquote"]]
  [[Start tag "body"]]
  [[Start tag "br"]]
  [[Start tag "center"]]
  [[Start tag "code"]]
  [[Start tag "dd"]]
  [[Start tag "div"]]
  [[Start tag "dl"]]
  [[Start tag "dt"]]
  [[Start tag "em"]]
  [[Start tag "embed"]]
  [[Start tag "h1"]]
  [[Start tag "h2"]]
  [[Start tag "h3"]]
  [[Start tag "h4"]]
  [[Start tag "h5"]]
  [[Start tag "h5"]]
  [[Start tag "h6"]]
  [[Start tag "head"]]
  [[Start tag "hr"]]
  [[Start tag "i"]]
  [[Start tag "img"]]
  [[Start tag "li"]]
  [[Start tag "listing"]]
  [[Start tag "menu"]]
  [[Start tag "meta"]]
  [[Start tag "nobr"]]
  [[Start tag "ol"]]
  [[Start tag "p"]]
  [[Start tag "pre"]]
  [[Start tag "ruby"]]
  [[Start tag "s"]]
  [[Start tag "small"]]
  [[Start tag "span"]]
  [[Start tag "strong"]]
  [[Start tag "strike"]]
  [[Start tag "sub"]]
  [[Start tag "sup"]]
  [[Start tag "table"]]
  [[Start tag "tt"]]
  [[Start tag "u"]]
  [[Start tag "ul"]]
  [[Start tag "var"]]
  ;[[Start tag "font"]]
  [[End tag "br"]]
  [[End tag "p"]]
    ; ...
    movzx rax, byte [r12 + H5aParser.treebuilder.mode]
    process_using_rules! rax

  [[Any other start tag]]
    ; ...
    xor al,al
    ret

  ;[[End tag "script"]]
  ; ...

  [[Any other end tag]]
    movzx rax, byte [r12 + H5aParser.treebuilder.mode]
    process_using_rules! rax

  [[Anything else]]
    unimplemented

end mode


section '.rodata'
  generate_tables

public myLabel
myLabel:
  dq 0x90
