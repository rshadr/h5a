;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
;;;; State machine macros for the tree builder
;;;;
;;;; IMPLEMENTATION NOTES:
;;;; - 'Any other character' must be the last in any clause block.
;;;;   Not a problem if standard-compliant.
;;;; - According to measurements, the "jmp +00" idiom does not cause any
;;;;   performance issues.
;;;;

macro mode? name*,index_name*
  local prefix
  local type_whitespace_seen
  local type_doctype_seen
  local type_character_seen
  local type_comment_seen
  local type_start_tag_seen
  local type_end_tag_seen
  local type_eof_seen
  local any_seen
  prefix equ _h5aTreeBuilderHandler.name
  type_whitespace_seen = 0
  type_doctype_seen = 0
  type_character_seen = 0
  type_comment_seen = 0
  type_start_tag_seen = 0
  type_end_tag_seen = 0
  type_eof_seen = 0
  any_seen = 0

  local type_index
  local type_next_label
  local action_index
  local action_pending
  local action_next_label
  local stag_next_label
  local etag_next_label
  local stag_index
  local etag_index
  local stag_have_default
  local etag_have_default
  local ch_have_generic
  local ch_have_explicit
  type_index = 0
  action_index = 0
  action_pending = 0
  stag_index = 0
  etag_index = 0
  stag_have_default = 0
  etag_have_default = 0
  ch_have_generic = 0
  ch_have_explicit = 0

  calminstruction setup
    local var, val
    arrange var, =label prefix
    assemble var
    arrange var, =public prefix
    assemble var

    ;; init labels
    arrange type_next_label, prefix.=typeCheck.type_index
    arrange action_next_label, prefix.=action.action_index
    arrange stag_next_label, prefix.=startTagCheck.stag_index
    arrange etag_next_label, prefix.=endTagCheck.etag_index

    ;; forward prefix
    compute val, index_name
    arrange var, =modeHandlerForIndex.val
    arrange val, prefix
    publish var:, val

    exit
  end calminstruction


  setup
  nop ;dbg


  calminstruction stride_type t*
    local var

    arrange var, =public type_next_label
    assemble var
    arrange var, =label type_next_label
    assemble var

    asm nop ;dbg

    compute type_index, type_index + 1
    arrange type_next_label, prefix.=typeCheck.type_index

    arrange var, =cmp =sil, t
    assemble var

    ;; XXX optimization: simpler jump when no other type is allowed
    ;; XXX' : this is not satisfyingly feasible and also useless!
    arrange var, =je action_next_label
    assemble var
    arrange var, =jmp type_next_label
    assemble var

    compute action_pending, 1
    
  end calminstruction


  calminstruction stride_start_tag qname_postfix*
    local var

    arrange var, =public stag_next_label
    assemble var
    arrange var, =label stag_next_label
    assemble var

    asm nop ;dbg

    compute stag_index, stag_index + 1
    arrange stag_next_label, prefix.=startTagCheck.stag_index

    ; XXX: check tag struct
    asm mov eax, dword [rdi + TagToken.tag_index]
    arrange var, =cmp =eax, =H5A_TAG_#qname_postfix
    assemble var
    arrange var, =je action_next_label
    assemble var
    arrange var, =jmp stag_next_label
    assemble var

    compute action_pending, 1

  end calminstruction


  calminstruction stride_end_tag qname_postfix*
    local var

    arrange var, =public etag_next_label
    assemble var
    arrange var, =label etag_next_label
    assemble var

    asm nop ;dbg

    compute etag_index, etag_index + 1
    arrange etag_next_label, prefix.=endTagCheck.etag_index

    ; XXX: check tag struct
    asm mov eax, dword [rdi + TagToken.tag_index]
    arrange var, =cmp =eax, =H5A_TAG_#qname_postfix
    assemble var
    arrange var, =je action_next_label
    assemble var
    arrange var, =jmp etag_next_label
    assemble var

    compute action_pending, 1

  end calminstruction


  calminstruction resolve_tag_stride_tail
    local var

    ; XXX:
    exit

  need_stag_resolve:
    arrange var, =jmp stag_next_label
    assemble var
    exit

  need_etag_resolve:
    arrange var, =jmp etag_next_label
    assemble var
    exit

  end calminstruction


  calminstruction ? line&
    local var, val
    local qualname
    local redir_mode

    match =end? =mode?, line
    jyes finish

    ;; Pre-filter tag patterns for stride resolve
    match =[=[=Start =tag qualname=]=], line
    jno prefilter_not_stag

    ; ...

    jump pattern_match

    prefilter_not_stag:
    match =[=[=End =tag qualname=]=], line
    jno prefilter_not_etag

    ; ...

    jump pattern_match


    prefilter_not_etag:
    ;; Patterns
    pattern_match:
    match =[=[=Whitespace=]=], line
    jyes whitespace
    match =[=[=Character=]=], line
    jyes character_generic
    match =[=[=Character =U+0000=]=], line
    jyes character_explicit_null
    match =[=[=Any =other =character=]=], line
    jyes any_other_character
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
    match =[=[=EOF=]=], line
    jyes eof
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
    match =parse_error=!, line
    jyes cmd_parse_error
    match =goto=! =anything_else, line
    jyes goto_always
    match call_rules! redir_mode, line
    jyes call_rules
    match =process_using_rules=! redir_mode, line
    jyes process_using_rules

  unknown:
    ;; Default assembly
    assemble line
    exit

  whitespace:
    check any_seen
    jyes any_must_be_last

    check type_whitespace_seen
    jyes ws_already
    arrange val, =TOKEN_WHITESPACE
    call stride_type, val
    arrange type_whitespace_seen, 1
    exit
  ws_already:
    err "duplicate whitespace clause"
    exit

  character_generic:
    check any_seen
    jyes any_must_be_last
    check ch_have_explicit
    jyes ch_cannot_mix

    arrange ch_have_generic, 1

    check type_character_seen
    jyes ch_generic_already
    arrange val, =TOKEN_CHARACTER
    call stride_type, val
    arrange type_character_seen, 1
    exit
  ch_generic_already:
    err "duplicate generic character clause"
    exit

  character_explicit_null:
    check any_seen
    jyes any_must_be_last
    check ch_have_generic
    jyes ch_cannot_mix

    ;check type_character_seen
    ;jyes ch_explicit_already
    arrange val, =TOKEN_CHARACTER
    call stride_type, val
    arrange type_character_seen, 1
    arrange ch_have_explicit, 1

    asm test edi,edi
    arrange var, =jnz prefix.=anyOtherCharacter
    assemble var
    exit

  ch_cannot_mix:
    err "cannot mix explicit (U+0000 / default) and generic character clause"
    exit
    

  any_other_character:
    check any_seen
    jyes any_must_be_last
    check ch_have_generic
    jyes ch_cannot_mix
    check ch_have_explicit
    jno anych_missing_cases

    arrange var, =public prefix.=anyOtherCharacter
    assemble var
    arrange var, =label prefix.=anyOtherCharacter
    assemble var
    exit
  anych_missing_cases:
    err "'Any other character' clause requires explicit cases beforehand"
    exit

  comment:
    check any_seen
    jyes any_must_be_last

    check type_comment_seen
    jyes comm_already
    arrange val, =TOKEN_COMMENT
    call stride_type, val
    arrange type_comment_seen, 1
    exit
  comm_already:
    err "duplicate comment clause"
    exit

  doctype:
    check any_seen
    jyes any_must_be_last

    check type_doctype_seen
    jyes dt_already
    arrange val, =TOKEN_DOCTYPE
    call stride_type, val
    arrange type_doctype_seen, 1
    exit
  dt_already:
    err "duplicate DOCTYPE clause"
    exit

  start_tag:
    check any_seen
    jyes any_must_be_last

    check type_start_tag_seen
    jyes stag_seen_typecheck
    arrange val, =TOKEN_START_TAG
    call stride_type, val
    arrange type_start_tag_seen, 1
  stag_seen_typecheck:
    ; XXX: use virtual array to check if case already defined
    call stride_start_tag, qualname
    ; ...
    exit

  end_tag:
    check any_seen
    jyes any_must_be_last

    check type_end_tag_seen
    jyes etag_seen_typecheck
    arrange val, =TOKEN_END_TAG
    call stride_type, val
    arrange type_end_tag_seen, 1
  etag_seen_typecheck:
    ; XXX: use virtual array to check if case already defined
    call stride_end_tag, qualname
    ; ...
    exit

  any_other_start_tag:
    check any_seen
    jyes any_must_be_last
    check stag_have_default
    jyes anystag_already_seen

    arrange stag_have_default, 1
    arrange var, =public stag_next_label
    assemble var
    arrange var, =label stag_next_label
    assemble var
    exit
  anystag_already_seen:
    err "duplicate 'Any other start tag' clause"
    exit

  any_other_end_tag:
    check any_seen
    jyes any_must_be_last
    check etag_have_default
    jyes anyetag_already_seen

    arrange etag_have_default, 1
    arrange var, =public etag_next_label
    assemble var
    arrange var, =label etag_next_label
    assemble var
    exit
  anyetag_already_seen:
    err "duplicate 'Any other end tag' clause"
    exit

  eof:
    check any_seen
    jyes any_must_be_last

    check type_eof_seen
    jyes eof_already_seen

    arrange val, =TOKEN_EOF
    call stride_type, val
    arrange type_eof_seen, 1
    exit
  eof_already_seen:
    err "duplicate 'EOF' clause"
    exit

  any:
    check any_seen
    jyes any_already_seen

    arrange any_seen, 1
    arrange var, =public prefix.=anythingElse
    assemble var
    arrange var, =label prefix.=anythingElse
    assemble var
    arrange var, =public type_next_label
    assemble var
    arrange var, =label type_next_label
    assemble var

    check stag_have_default
    jyes any_no_stag_needed

    arrange var, =public stag_next_label
    assemble var
    arrange var, =label stag_next_label
    assemble var
    take stag_next_label, val ;unused
    asm nop

  any_no_stag_needed:
    check etag_have_default
    jyes any_no_etag_needed

    arrange var, =public etag_next_label
    assemble var
    arrange var, =label etag_next_label
    assemble var
    take etag_next_label, val ;unused
    asm nop

  any_no_etag_needed:
    exit

  any_already_seen:
    err "duplicate 'Anything else' clause"
    exit

  any_must_be_last:
    err "'Anything else' must be the last clause in the insertion mode definition"
    exit


  cmd_parse_error:
    ; ...
    exit


  goto_always:
    arrange var, =jmp prefix.=anythingElse
    assemble var
    exit

  call_rules:
    asm lea rcx, [_k_h5a_TreeBuilder_handlerTable]
    arrange var, =call =qword [=rcx + (redir_mode * 8)]
    assemble var
    exit

  process_using_rules:
    ; XXX: improve
    asm lea rcx, [_k_h5a_TreeBuilder_handlerTable]
    arrange var, =jmp =qword [=rcx + (redir_mode * 8)]
    assemble var
    exit

  pur_fail:
    err "invalid alternate processing mode"
    exit

  finish:
    check any_seen
    jno missing_any

    arrange var, =purge ?, =setup, =stride_type, =stride_type_tail, =resolve_tag_stride_tail
    assemble var
    exit
  missing_any:
    err "'Anything else' clause is mandatory"
    exit
    
  end calminstruction

end macro


macro generate_tables?
  local prefix

  calminstruction get_prefix index*
    local var, val

    arrange var, =modeHandlerForIndex.index
    transform var
    jyes no_compensate

    ; XXX: remove when done
    arrange var, =_h5aTreeBuilderHandler.=DUMMY

  no_compensate:
    arrange prefix, var
    exit

  missing_mode_def:
    err 'missing insertion mode definition'
    exit

  end calminstruction


  calminstruction generate_handler_table
    local var, i
    compute i, 0

  mode_loop:
    check i < NUM_MODES
    jno finish

    call get_prefix, i

    arrange var, =dq prefix
    assemble var

    compute i, i + 1
    jump mode_loop

  finish:
    exit
  end calminstruction


  _k_h5a_TreeBuilder_handlerTable:
    generate_handler_table


  purge get_prefix
  purge generate_handler_table

end macro

