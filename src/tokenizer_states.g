
macro define_state? name*,index_name*
  local prefix, have_any, enable_getchar, flags
  prefix equ _h5aTokenizerHandle.name
  have_any = 0
  enable_getchar = 1
  flags = 0

  calminstruction forward_prefix name_*, index_name_*
    local var, val

    compute val, index_name_
    arrange var, =anchorForIndex.val
    arrange val, =_h5aTokenizerHandle.name_
    publish var:, val
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

    match =end? =define_state?, line
    jyes finish
    match =no_consume?, line
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
      exit

    seq_nocase:
      compute flags, (flags or STATE_BIT_SPC_ACTION)
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
      arrange var, 0x#code
      compute val, var
      arrange var, =public prefix.val
      assemble var
      arrange var, =label prefix.val
      assemble var
      exit

    eof:
      arrange var, =public prefix.=eof
      assemble var
      arrange var, =label prefix.=eof
      assemble var
      exit

    any:
      arrange var, =public prefix.=any
      assemble var
      arrange var, =label prefix.=any
      assemble var
      compute have_any, 1
      exit

    finish:
      compute val, index_name
      arrange var, =flagsForIndex.val
      compute val, flags
      publish var:, val

      arrange var, =purge ?, =forward_prefix, =char_range
      assemble var
      exit

  end calminstruction

  ;section '.text' executable
  forward_prefix name, index_name
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
    local var, val
    local i, j
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
    local var
    local i
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
    local var
    local i
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

  calminstruction generate_flags_table
    local i
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

    fail:
      err 'unbelievable'
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
    repeat NUM_STATES
      dq 0x00
    end repeat

  ;; NOTE: forces non-BSS linking
  _k_h5a_Tokenizer_flags_table:
    generate_flags_table

  purge generate_ascii_matrix
  purge generate_unicode_table
  purge generate_eof_table
  purge generate_flags_table
end macro

