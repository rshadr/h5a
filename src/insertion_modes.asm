
format ELF64

insertion_mode initial,INITIAL_MODE

  [[Whitespace]]
    mov al, RESULT_IGNORE
    ret

  [[Comment]]
    ; ... insert comment
    xor al,al
    ret

  [[DOCTYPE]]
    ; ... zzz
    mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
    xor al,al
    ret

  [[Anything else]]
    ; ...
    mov byte [r12 + H5aParser.treebuilder.mode], BEFORE_HTML_MODE
    mov al, RESULT_REPROCESS
    ret

end insertion_mode


insertion_mode inHead,IN_HEAD_MODE
  [[Start tag "title"]]
    jmp generic_rcdata_parse
end insertion_mode


insertion_mode inBody,IN_BODY_MODE
  [[Whitespace]]
    call reconstruct_formatting
    call insert_character
    xor al,al
    ret

  [[Character]]
    cmp edi, 0x0000
    jne CASE_BLOCK.default
    ; error
    mov al, RESULT_IGNORE
    ret
CASE_BLOCK.default:
    xor al,al
    ret

  [[Comment]]
    call insert_comment
    xor al,al
    ret

  [[DOCTYPE]]
    ; error
    mov al, RESULT_IGNORE
    ret

  [[Start tag "html"]]
    ;error
    ;...
    ret

  [[Start tag "base"]]
  ;; label H5aTreeBuilderHandle.inBody.startTag.base
  ;; ;; record at index key like for the Tokenizer
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
    process_as IN_HEAD
  ;; calminstruction process_as? idx_name*
  ;;   local var, val, idx
  ;;   compute idx, idx_name
  ;;
  ;;   arrange var, =mov $DISPATCH_MODE_KEY, idx
  ;;   ;; "hot inject" another mode key for the dispatcher. No need to care
  ;;   ;; about stack or local variables!!
  ;;   arrange var, =jmp H5aTreeBuilderAcceptToken.preDispatch
  ;;   assemble var
  ;; end calminstruction

end insertion_mode

