;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"
include "insertion_modes.g"


format ELF64

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


mode initial,INITIAL_MODE

  [[Whitespace]]
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    ; ...
    xor al,al
    ret

  [[DOCTYPE]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
    mov al, RESULT_REPROCESS
    ret

end mode


mode beforeHtml,BEFORE_HTML_MODE

  [[DOCTYPE]]
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    ; ...
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
    ; ...
    mov al, RESULT_IGNORE
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HEAD_MODE
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

  [[Character]]
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


; ...
section '.rodata'
  generate_tables
