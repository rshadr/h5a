
macro mode? name*,index_name*
  local prefix
  local type_whitespace_seen
  local type_doctype_seem
  local type_character_seen
  local type_comment_seen
  local type_start_tag_seen
  local type_end_tag_seen
  prefix equ _h5aTreeBuilderHandler.name
  type_whitespace_seen = 0
  type_doctype_seen = 0
  type_character_seen = 0
  type_comment_seen = 0
  type_start_tag_seen = 0
  type_end_tag_seen = 0

  local type_index
  local type_next_label
  local action_index
  local action_pending
  local action_next_label
  local start_tag_qualname_next_label
  local end_tag_qualname_next_label
  type_index = 0
  action_index = 0
  action_pending = 0

  calminstruction setup
    local var
    arrange var, =label prefix
    assemble var
    arrange var, =public prefix
    assemble var

    arrange type_next_label, prefix.=type.0
    arrange action_next_label, prefix.=action.0

    exit
  end calminstruction

  setup
  purge setup

  calminstruction stride_type_head t*
    local var

    arrange var, =public type_next_label
    assemble var
    arrange var, =label type_next_label
    assemble var

    compute type_index, type_index + 1
    arrange type_next_label, prefix.=type.type_index

    arrange var, =cmp =sil, t
    assemble var
    arrange var, =je action_next_label
    assemble var
    arrange var, =jmp type_next_label
    assemble var

    compute action_pending, action_pending + 1
    
  end calminstruction


  calminstruction ? line&
    local var, val
    local qualname
    local redir_mode

    match =end? =mode?, line
    jyes finish

    ;; Patterns
    match =[=[=Whitespace=]=], line
    jyes whitespace
    match =[=[=Character=]=], line
    jyes character
    match =[=[=Comment=]=], line
    jyes comment
    match =[=[=DOCTYPE=]=], line
    jyes doctype
    match =[=[=Start =tag qualname=]=], line
    jyes start_tag
    match =[=[=End =tag qualname=]=], line
    jyes end_tag
    match =[=[=Any =other =start =tag=]=], line
    jyes any_other_start_tag
    match =[=[=Any =other =end =tag=]=], line
    jyes any_other_end_tag
    match =[=[=Anything =else=]=], line
    jyes any


    ;; When not a pattern, assume command.
    ;; The pattern group expects a label for strided branching to work, make it here.
    check action_pending
    jno no_pending

    arrange var, =public action_next_label
    assemble var
    arrange var, =label action_next_label
    assemble var
    compute action_index, action_index + 1
    arrange action_next_label, prefix.=action.action_index

    arrange action_pending, 0

  no_pending:

    ;; Commands
    match =goto=! =anything_else, line
    jyes goto_always
    match =process_using_rules=! redir_mode, line
    jyes process_using_rules

  unknown:
    assemble line
    exit

  whitespace:
    ; ...
    check type_whitespace_seen
    jyes ws_already
    arrange val, =TOKEN_WHITESPACE
    call stride_type_head, val
    arrange type_whitespace_seen, 1
    exit
  ws_already:
    err "duplicate whitespace clause"
    exit

  character:
    ; ...
    exit

  comment:
    ; ...
    exit

  doctype:
    ; ...
    exit

  start_tag:
    ; ...
    check type_start_tag_seen
    jyes stag_fine
    arrange val, =TOKEN_START_TAG
    call stride_type_head, val
    arrange type_start_tag_seen, 1
  stag_fine:
    exit

  end_tag:
    ; ...
    exit

  any_other_start_tag:
    ; ...
    exit

  any_other_end_tag:
    ; ...
    exit

  any:
    ; XXX: error if anything new follows
    ;any_seen = 1
    ; ...
    arrange var, =public type_next_label
    assemble var
    arrange var, =label type_next_label
    assemble var
    exit

  goto_always:
    ; ...
    exit

  process_using_rules:
    ; ...
    exit

  finish:
    arrange var, =purge ?, =setup, =stride_type_head, =stride_type_tail
    assemble var
    exit
    
  end calminstruction

end macro
