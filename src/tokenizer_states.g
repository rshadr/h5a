
macro state? name*,index_name*
  local prefix, have_any, enable_getchar, in_seq, beyond_index, flags
  prefix equ _h5aTokenizerHandle.name
  have_any = 0
  enable_getchar = 1
  in_seq = 0
  beyond_index = 0
  flags = 0

  calminstruction forward_prefix name_*, index_name_*
    local var, val

    compute val, index_name_
    arrange var, =anchorForIndex.val
    arrange val, =_h5aTokenizerHandle.name_
    publish var:, val
  end calminstruction

  calminstruction emit_spc_action_head
    local var
    arrange var, =public prefix.=spcActionStart
    assemble var
    arrange var, =label prefix.=spcActionStart
    assemble var
    asm nop
  end calminstruction

  calminstruction seq_maybe_emit_beyond close_seqs*
    local var, val, beyond

    check in_seq eq 1
    jno finish

    arrange beyond, prefix.=seqBeyond.beyond_index
    arrange var, =label beyond
    assemble var
    compute in_seq, 0
    compute beyond_index, beyond_index + 1

    check close_seqs
    jno finish

    asm mov al, RESULT_PARTIAL
    asm ret

    finish:
      exit
  end calminstruction

  macro seq_store name*,seq*
    postpone
      section '.rodata'

      public name ;dbg
      label name

      db seq
      db 0x00

      public sizeof.name
      sizeof.name constequ $ - name - 1
    end postpone
  end macro

  calminstruction seq_match func*, seq*
    local var, val
    local seq_label, beyond

    compute val, +seq
    arrange seq_label, =_k_h5a_Tokenizer_stringPattern.val
    arrange beyond, prefix.=seqBeyond.beyond_index

    check in_seq
    jyes err_nested

    compute in_seq, 1

    local l
      arrange l, prefix.=seqStart.val
      arrange var, =public l
      assemble var
      arrange var, =label l
      assemble var

    arrange var, =lea =rdi, =[seq_label=]
    assemble var
    arrange var, =mov =rsi, =sizeof.seq_label
    assemble var
    arrange var, =call func
    assemble var
    asm test al,al
    arrange var, =jz beyond
    assemble var
    arrange var, =seq_store seq_label, seq
    assemble var
    exit

    err_nested:
      err 'nested string pattern'
      exit

  end calminstruction

  macro char_range pfx*,min*,max*
    repeat 1+max-min, i:min
      public pfx.i
      label pfx.i
    end repeat
  end macro

  calminstruction ? line&
    local var, val
    local code, rest
    local seq
    local group

    match =end? =state?, line
    jyes finish
    match =@no_consume?, line
    jyes disable_getchar
    match =[=[=Exactly seq=]=], line
    jyes seq_yescase
    match =[=[=Case=-=insensitively seq=]=], line
    jyes seq_nocase
    match =[=[=ASCII group=]=], line
    jyes grp
    match =[=[=U=+code rest=]=], line
    jyes codepoint
    match =[=[=EOF=]=], line
    jyes eof
    match =[=[=Anything =else=]=], line
    jyes any
    ;fallthrough
    unknown:
      assemble line
      exit

    disable_getchar:
      compute enable_getchar, 0
      compute flags, (flags or STATE_BIT_NO_GETCHAR)
      exit

    seq_yescase:
      compute flags, (flags or STATE_BIT_SPC_ACTION)
      compute val, 0
      call seq_maybe_emit_beyond, val
      arrange val, =_h5aTokenizerEat
      call seq_match, val, seq
      exit

    seq_nocase:
      compute flags, (flags or STATE_BIT_SPC_ACTION)
      compute val, 0
      call seq_maybe_emit_beyond, val
      arrange val, =_h5aTokenizerEatInsensitive
      call seq_match, val, seq
      exit

    grp:
      match =alphanumeric, group
      jyes grp_alnum
      match =alpha, group
      jyes grp_alpha
      match =upper =alpha, group
      jyes grp_upalpha
      match =lower =alpha, group
      jyes grp_lowalpha
      match =digit, group
      jyes grp_digit
      match =upper =hex =digit, group
      jyes grp_uphex
      match =lower =hex =digit, group
      jyes grp_lowhex
      match =hex =digit, group
      jyes grp_hex
      jump unknown ;fallback

    grp_alpha:
      arrange var, =char_range prefix,'a','z'
      assemble var
      ;fallthrough
    grp_upalpha:
      arrange var, =char_range prefix,'A','Z'
      assemble var
      exit

    grp_lowalpha:
      arrange var, =char_range prefix,'a','z'
      assemble var
      exit

    grp_alnum:
      arrange var, =char_range prefix,'A','Z'
      assemble var
      arrange var, =char_range prefix,'a','z'
      assemble var
    grp_digit:
      arrange var, =char_range prefix,'0','9'
      assemble var
      exit

    grp_hex:
      arrange var, =char_range prefix,'0','9'
      assemble var
    grp_uphex:
      err 'untested'
      arrange var, =char_range prefix,'A','F'
      assemble var
      exit

    grp_lowhex:
      err 'untested'
      arrange var, =char_range prefix,'a', 'f'
      assemble var
      exit

    codepoint:
      arrange val, 1
      call seq_maybe_emit_beyond, val
      arrange var, 0x#code
      compute val, var
      arrange var, =public prefix.val
      assemble var
      arrange var, =label prefix.val
      assemble var
      exit

    eof:
      arrange val, 1
      call seq_maybe_emit_beyond, val
      arrange var, =public prefix.=eof
      assemble var
      arrange var, =label prefix.=eof
      assemble var
      exit

    any:
      compute val, enable_getchar
      call seq_maybe_emit_beyond, val
      arrange var, =public prefix.=any
      assemble var
      arrange var, =label prefix.=any
      assemble var
      compute have_any, 1
      exit

    finish:
      arrange val, 1
      call seq_maybe_emit_beyond, val

      compute val, index_name
      arrange var, =flagsForIndex.val
      compute val, flags
      arrange val,val ;stupid hack: publish doesn't accept integers?
      publish var:, val

      arrange var, =purge ?, =forward_prefix
      assemble var
      arrange var, =purge =emit_spc_action_head, =seq_maybe_emit_beyond
      assemble var
      arrange var, =purge =seq_store, =seq_match
      assemble var
      arrange var, =purge =char_range
      assemble var
      exit

  end calminstruction

  ;; BEGIN IMMEDIATE
  ;section '.text' executable
  forward_prefix name, index_name
  emit_spc_action_head
end macro


macro generate_tables?
  local prefix

  calminstruction get_prefix index*
    local var, val

    arrange var, =anchorForIndex.index
    transform var
    jyes no_compensate
      ; XXX: at some point this must error out
      arrange var, =_h5aTokenizerHandle.=DUMMY
    no_compensate:
      arrange prefix, var
      exit

    missing_state_def:
      err 'Missing state definition'
      exit

  end calminstruction

  calminstruction generate_ascii_matrix
    local var, val, i, j
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno finish
      call get_prefix, i
      compute j, 0

      char_loop:
        check j <= 0x7F
        jno char_loop_after

        arrange var, prefix.j
        check defined var
        jyes explicitly_defined
          arrange var, prefix.=any
        explicitly_defined:
          arrange var, =dq var
          assemble var

        compute j, j + 1
        jump char_loop

      char_loop_after:
        compute i, i + 1
        jump state_loop

    finish:
      exit
  end calminstruction

  calminstruction generate_unicode_table
    local var, i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno finish
      call get_prefix, i

      arrange var, =dq prefix.=any
      assemble var

      compute i, i + 1
      jump state_loop

    finish:
      exit
  end calminstruction

  calminstruction generate_eof_table
    local var, i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno finish
      call get_prefix, i

      arrange var, prefix.=eof
      check defined var
      jyes explicitly_defined
        arrange var, prefix.=any
      explicitly_defined:
        arrange var, =dq var
        assemble var

      compute i, i + 1
      jump state_loop

    finish:
      exit
  end calminstruction

  calminstruction generate_spc_action_table
    local var, val, i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno finish
      call get_prefix, i

      ;arrange var, =dq prefix.=any
      ;assemble var

      arrange var, =flagsForIndex.i
      transform var
      jyes explicitly_defined
      compute var, 0x00
    explicitly_defined:
      compute val, (var and STATE_BIT_SPC_ACTION)
      check val > 0
      jno just_zero

      arrange var, =dq prefix.=spcActionStart
      assemble var

      jump state_loop_tail

    just_zero:
      asm dq 0x00
      ;fallthrough

    state_loop_tail:
      compute i, i + 1
      jump state_loop

    finish:
      exit

  end calminstruction

  calminstruction generate_flags_table
    local var, i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno finish

      arrange var, =flagsForIndex.i
      transform var
      jyes explicitly_defined
        compute var, 0x00
      explicitly_defined:
        arrange var, =db var
        assemble var

      compute i, i + 1
      jump state_loop

    finish:
      exit

  end calminstruction

  _k_h5a_Tokenizer_ascii_matrix:
    generate_ascii_matrix
  _k_h5a_Tokenizer_unicode_table:
    generate_unicode_table
  _k_h5a_Tokenizer_eof_table:
    generate_eof_table

  _k_h5a_Tokenizer_common_dispatch_table:
    dq _k_h5a_Tokenizer_ascii_matrix
    dq _k_h5a_Tokenizer_unicode_table
    dq _k_h5a_Tokenizer_eof_table

  _k_h5a_Tokenizer_spc_action_table:
    generate_spc_action_table

  ;; NOTE: forces non-BSS linking
  _k_h5a_Tokenizer_flags_table:
    generate_flags_table

  purge generate_ascii_matrix
  purge generate_unicode_table
  purge generate_eof_table
  purge generate_spc_action_table
  purge generate_flags_table
end macro

