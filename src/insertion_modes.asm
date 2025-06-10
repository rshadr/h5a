;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "tags.inc"
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


func quirksCheck, private
  ; ...
  xor rax,rax
  ret
end func


func limitedQuirksCheck, private
  ; ...
  xor rax,rax
  ret
end func


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

  [[Start tag HTML]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag HEAD]]
  [[End tag BODY]]
  [[End tag HTML]]
  [[End tag BR]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag HEAD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag HEAD]]
  [[End tag BODY]]
  [[End tag HTML]]
  [[End tag BR]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag BASE]]
  [[Start tag BASEFONT]]
  [[Start tag BGSOUND]]
  [[Start tag LINK]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag META]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag TITLE]]
    jmp _h5aTreeBuilderGenericRcdataParse


namespace noscript_and_clique

  [[Start tag NOSCRIPT]]
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

  [[Start tag NOFRAMES]]
  [[Start tag STYLE]]
noscript_scripting_enabled:
    jmp _h5aTreeBuilderGenericRawTextParse

end namespace


  [[Start tag SCRIPT]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.tokenizer.state], SCRIPT_DATA_STATE
      mov cl, byte [r12 + H5aParser.treebuilder.mode]
      mov byte [r12 + H5aParser.treebuilder.original_mode], cl
      mov byte [r12 + H5aParser.treebuilder.mode], TEXT_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag HEAD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag BODY]]
  [[End tag HTML]]
  [[End tag BR]]
    goto! anything_else

  [[Start tag TEMPLATE]]
    ; ...
    xor al,al
    ret

  [[End tag TEMPLATE]]
    ; ...
    xor al,al
    ret

  [[Start tag HEAD]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[End tag NOSCRIPT]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Whitespace]]
  [[Comment]]
  [[Start tag BASEFONT]]
  [[Start tag BGSOUND]]
  [[Start tag LINK]]
  [[Start tag META]]
  [[Start tag NOFRAMES]]
    process_using_rules! IN_HEAD_MODE

  [[End tag BR]]
    goto! anything_else

  [[Start tag HEAD]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag BODY]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag FRAMESET]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_FRAMESET_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag BASE]]
  [[Start tag BASEFONT]]
  [[Start tag BGSOUND]]
  [[Start tag LINK]]
  [[Start tag META]]
  [[Start tag NOFRAMES]]
  [[Start tag SCRIPT]]
  [[Start tag STYLE]]
  [[Start tag TEMPLATE]]
  [[Start tag TITLE]]
    with_stack_frame
      ; ...
      call_rules! IN_HEAD_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag TEMPLATE]]
    process_using_rules! IN_HEAD_MODE

  [[End tag BODY]]
  [[End tag HTML]]
  [[End tag BR]]
    goto! anything_else

  [[Start tag HEAD]]
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

  [[Start tag HTML]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag BASE]]
  [[Start tag BASEFONT]]
  [[Start tag BGSOUND]]
  [[Start tag LINK]]
  [[Start tag META]]
  [[Start tag NOFRAMES]]
  [[Start tag SCRIPT]]
  [[Start tag STYLE]]
  [[Start tag TEMPLATE]]
  [[Start tag TITLE]]
  [[End tag TEMPLATE]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag BODY]]
    ; ...
    xor al,al
    ret

  [[Start tag FRAMESET]]
    ; ...
    xor al,al
    ret

  [[EOF]]
    ; ...
    mov al, RESULT_STOP
    ret

  [[End tag BODY]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[End tag HTML]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], AFTER_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag ADDRESS]]
  [[Start tag ARTICLE]]
  [[Start tag ASIDE]]
  [[Start tag BLOCKQUOTE]]
  [[Start tag CENTER]]
  [[Start tag DETAILS]]
  [[Start tag DIALOG]]
  [[Start tag DIR]]
  [[Start tag DIV]]
  [[Start tag DL]]
  [[Start tag FIELDSET]]
  [[Start tag FIGCAPTION]]
  [[Start tag FIGURE]]
  [[Start tag FOOTER]]
  [[Start tag HEADER]]
  [[Start tag HGROUP]]
  [[Start tag MAIN]]
  [[Start tag MENU]]
  [[Start tag NAV]]
  [[Start tag OL]]
  [[Start tag P]]
  [[Start tag SEARCH]]
  [[Start tag SECTION]]
  [[Start tag SUMMARY]]
  [[Start tag UL]]
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

  [[End tag SCRIPT]]
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

  [[Start tag CAPTION]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_CAPTION_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag COLGROUP]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag COL]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag TBODY]]
  [[Start tag TFOOT]]
  [[Start tag THEAD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag TD]]
  [[Start tag TH]]
  [[Start tag TR]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag TABLE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag TABLE]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag BODY]]
  [[End tag CAPTION]]
  [[End tag COL]]
  [[End tag COLGROUP]]
  [[End tag HTML]]
  [[End tag TBODY]]
  [[End tag TD]]
  [[End tag TFOOT]]
  [[End tag TH]]
  [[End tag THEAD]]
  [[End tag TR]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Start tag STYLE]]
  [[Start tag SCRIPT]]
  [[Start tag TEMPLATE]]
  [[End tag TEMPLATE]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag INPUT]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag FORM]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag COL]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag COLGROUP]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag COL]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Start tag TEMPLATE]]
  [[End tag TEMPLATE]]
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

  [[Start tag TR]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag TH]]
  [[Start tag TD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag TBODY]]
  [[End tag TFOOT]]
  [[End tag THEAD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag COL]]
  [[Start tag COLGROUP]]
  [[Start tag TBODY]]
  [[Start tag TFOOT]]
  [[Start tag THEAD]]
  [[End tag TABLE]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag BODY]]
  [[End tag CAPTION]]
  [[End tag COLGROUP]]
  [[End tag HTML]]
  [[End tag TD]]
  [[End tag TH]]
  [[End tag TR]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    process_using_rules! IN_TABLE_MODE

end mode


mode inRow,IN_ROW_MODE

  [[Start tag TH]]
  [[Start tag TD]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_CELL_MODE
    xor al,al
    ret

  [[End tag TR]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    xor al,al
    ret

  [[Start tag CAPTION]]
  [[Start tag COL]]
  [[Start tag COLGROUP]]
  [[Start tag TBODY]]
  [[Start tag TFOOT]]
  [[Start tag THEAD]]
  [[Start tag TR]]
  [[End tag TABLE]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    mov al, RESULT_REPROCESS
    ret

  [[End tag TBODY]]
  [[End tag TFOOT]]
  [[End tag THEAD]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    mov al, RESULT_REPROCESS
    ret

  [[Anything else]]
    process_using_rules! IN_TABLE_MODE

end mode


func close_cell, private
  with_stack_frame
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
  end with_stack_frame
  ret
end func

mode inCell,IN_CELL_MODE

  [[End tag TD]]
  [[End tag TH]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], IN_ROW_MODE
    xor al,al
    ret

  [[Start tag CAPTION]]
  [[Start tag COL]]
  [[Start tag COLGROUP]]
  [[Start tag TBODY]]
  [[Start tag TD]]
  [[Start tag TFOOT]]
  [[Start tag TH]]
  [[Start tag THEAD]]
  [[Start tag TR]]
    ; ...
    mov al, RESULT_REPROCESS
    ret

  [[End tag BODY]]
  [[End tag CAPTION]]
  [[End tag COL]]
  [[End tag COLGROUP]]
  [[End tag HTML]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[End tag TABLE]]
  [[End tag TBODY]]
  [[End tag TFOOT]]
  [[End tag THEAD]]
  [[End tag TR]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag OPTION]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag OPTGROUP]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag HR]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[End tag OPTGROUP]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[End tag OPTION]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_IGNORE
    ret

  [[End tag SELECT]]
    with_stack_frame
      ; ...
    end with_stack_frame
    ; ...
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag SELECT]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag INPUT]]
  [[Start tag KEYGEN]]
  [[Start tag TEXTAREA]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag SCRIPT]]
  [[Start tag TEMPLATE]]
  [[End tag TEMPLATE]]
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

  [[Start tag CAPTION]]
  [[Start tag TABLE]]
  [[Start tag TBODY]]
  [[Start tag TFOOT]]
  [[Start tag THEAD]]
  [[Start tag TR]]
  [[Start tag TD]]
  [[Start tag TH]]
    with_stack_frame
      ; ...
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[End tag CAPTION]]
  [[End tag TABLE]]
  [[End tag TBODY]]
  [[End tag TFOOT]]
  [[End tag THEAD]]
  [[End tag TR]]
  [[End tag TD]]
  [[End tag TH]]
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

  [[Start tag BASE]]
  [[Start tag BASEFONT]]
  [[Start tag BGSOUND]]
  [[Start tag LINK]]
  [[Start tag META]]
  [[Start tag NOFRAMES]]
  [[Start tag SCRIPT]]
  [[Start tag STYLE]]
  [[Start tag TEMPLATE]]
  [[Start tag TITLE]]
  [[End tag TEMPLATE]]
    process_using_rules! IN_HEAD_MODE

  [[Start tag CAPTION]]
  [[Start tag COLGROUP]]
  [[Start tag TBODY]]
  [[Start tag TFOOT]]
  [[Start tag THEAD]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag COL]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_COLUMN_GROUP_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag TR]]
    with_stack_frame
      ; ...
      mov byte [r12 + H5aParser.treebuilder.mode], IN_TABLE_BODY_MODE
    end with_stack_frame
    mov al, RESULT_REPROCESS
    ret

  [[Start tag TD]]
  [[Start tag TH]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[End tag HTML]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[Start tag FRAMESET]]
    ; ...
    xor al,al
    ret

  [[End tag FRAMESET]]
    with_stack_frame
      ; ...
      xor al,al ;!!
      ;cmovz byte [r12 + H5aParser.treebuilder.mode], AFTER_FRAMESET_MODE
    end with_stack_frame
    xor al,al
    ret

  [[Start tag FRAME]]
    with_stack_frame
      ; ...
    end with_stack_frame
    xor al,al
    ret

  [[Start tag NOFRAMES]]
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

  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[End tag HTML]]
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
  [[Start tag HTML]]
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
  [[Start tag HTML]]
    process_using_rules! IN_BODY_MODE

  [[EOF]]
    mov al, RESULT_STOP
    ret

  [[Start tag NOFRAMES]]
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

  [[Start tag B]]
  [[Start tag BIG]]
  [[Start tag BLOCKQUOTE]]
  [[Start tag BODY]]
  [[Start tag BR]]
  [[Start tag CENTER]]
  [[Start tag CODE]]
  [[Start tag DD]]
  [[Start tag DIV]]
  [[Start tag DL]]
  [[Start tag DT]]
  [[Start tag EM]]
  [[Start tag EMBED]]
  [[Start tag H1]]
  [[Start tag H2]]
  [[Start tag H3]]
  [[Start tag H4]]
  [[Start tag H5]]
  [[Start tag H6]]
  [[Start tag HEAD]]
  [[Start tag HR]]
  [[Start tag I]]
  [[Start tag IMG]]
  [[Start tag LI]]
  [[Start tag LISTING]]
  [[Start tag MENU]]
  [[Start tag META]]
  [[Start tag NOBR]]
  [[Start tag OL]]
  [[Start tag P]]
  [[Start tag PRE]]
  [[Start tag RUBY]]
  [[Start tag S]]
  [[Start tag SMALL]]
  [[Start tag SPAN]]
  [[Start tag STRONG]]
  [[Start tag STRIKE]]
  [[Start tag SUB]]
  [[Start tag SUP]]
  [[Start tag TABLE]]
  [[Start tag TT]]
  [[Start tag U]]
  [[Start tag UL]]
  [[Start tag VAR]]
  ;[[Start tag "font"]]
  [[End tag BR]]
  [[End tag P]]
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

;; BUG: This is required because fasm otherwise refuses to emit relocations for the whole section??
public myLabel
myLabel:
  dq 0x90
