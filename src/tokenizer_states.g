;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
;;;; This file implements the custom syntax for tokenizer state handlers.
;;;; See https://board.flatassembler.net/topic.php?t=23762 for old discussion.
;;;;
;;;; Some preliminary clarifications:
;;;;  "anchor" refers to the camelCase name of the base name for the state
;;;;  handler, e.g. "data", "tagOpen", etc.
;;;;  "prefix" refers to a symbol of the form: _h5a_Tokenizer_handle.{anchor}
;;;;
;;;; 


macro define_state anchor*,index_name*
;;;
;;; Custom syntax
;;;
  section '.text' executable

  calminstruction persist_prefix anch*, idx_name*
    local var, val

    compute val, idx_name
    arrange var, =anchorForIndex.val
    arrange val, =_h5aTokenizerHandle.anch
    publish var:, val

  end calminstruction

  local prefix, beyond_index, in_seq, have_any
  prefix equ _h5aTokenizerHandle.anchor
  beyond_index = 0
  in_seq = 0
  have_any = 0

  persist_prefix anchor, index_name

  macro char_range pfx*,min*,max*
    repeat 1+max-min, i:min
      public pfx.i
      label pfx.i
    end repeat
  end macro

  macro seq_store name*,seq*
    postpone
      section '.rodata'
      public name
      label name
      db seq
      db 0x00
      ;public sizeof.name
      sizeof.name equ $ - name
    end postpone
  end macro

  calminstruction seq_maybe_beyond close_seqs:0
    local var, val, beyond

    check in_seq eq 1
    jno done

    arrange beyond, prefix.=seqBeyond.beyond_index
    arrange var, =label beyond
    assemble var
    compute in_seq, 0
    compute beyond_index, beyond_index + 1

    check close_seqs
    jno done

    asm mov al, 0
    asm ret

    done:
      exit
  end calminstruction

  calminstruction seq_match func*,seq*
    local var, val, seq_label, beyond
    compute val, +seq
    arrange seq_label, =LSEQ.val
    arrange beyond, prefix.=seqBeyond.beyond_index

    check in_seq
    jyes err_nested

    compute in_seq, 1

    local dbg
    arrange dbg, prefix.=seqStart.val
    arrange var, =public dbg
    assemble var
    arrange var, =label dbg
    assemble var

    ;; RDI is used here because it has no meaning yet.
    ;; It _may_ later hold uint32_t charcode, but that
    ;; will inevitably be after the string cases.
    arrange var, =lea =rdi, =[seq_label=]
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
      err 'nested string rule'
      exit

  end calminstruction

  calminstruction ? line&
    local var, val
    local code, seq, rest, group

    match =end? =define_state?, line
    jyes finish
    match =[=[=Exactly seq=]=], line
    jyes seq_yescase
    match =[=[Case-insensitively seq=]=], line
    jyes seq_nocase
    match =[=[=ASCII group=]=], line
    jyes grp
    match =[=[=U=+code rest=]=], line
    jyes unicode
    match =[=[=EOF=]=], line
    jyes eof
    match =[=[=Anything =else=]=], line
    jyes any

    unknown:
      assemble line
      exit

    seq_yescase:
      arrange val, 0
      call seq_maybe_beyond, val
      arrange val, =_h5aTokenizerEat
      call seq_match, val, seq
      exit

    seq_nocase:
      arrange val, 0
      call seq_maybe_beyond, val
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
      jump unknown

    grp_alpha:
      arrange var, =char_range prefix,'a','z'
      assemble var
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

    grp_uphex:
      arrange var, =char_range prefix,'A','F'
      assemble var
      arrange var, =char_range prefix,'0','9'
      assemble var
      exit

    grp_hex:
      arrange var, =char_ref prefix,'A','F'
      assemble var
    grp_lowhex:
      arrange var, =char_ref prefix,'a','f'
      assemble var
      arrange var, =char_ref prefix,'0','9'
      assemble var
      exit

    unicode:
      arrange val, 1
      call seq_maybe_beyond, val
      arrange var, 0x#code
      compute val, var
      arrange var, =public prefix.val
      assemble var
      arrange var, =label prefix.val
      assemble var
      exit

    eof:
      arrange val, 1
      call seq_maybe_beyond, val
      arrange var, =public prefix.=eof
      assemble var
      arrange var, =label prefix.=eof
      assemble var
      exit

    any:
      arrange val, 1
      call seq_maybe_beyond, val
      arrange var, =public prefix.=any
      assemble var
      arrange var, =label prefix.=any
      assemble var
      compute have_any, 1
      exit

    finish:
      arrange val, 1
      call seq_maybe_beyond, val

      check have_any
      jno no_any

      arrange var, =purge ?, =persist_prefix, =remember_anchor, =char_range, =seq_store, =seq_match, =seq_maybe_beyond
      assemble var
      exit

    no_any:
      err "missing 'Anything else' handler"
      exit
  end calminstruction
end macro


macro generate_tables
;;
;; Postpone or put at back of file. Preferrably '.rodata' section.
;;
  local prefix

  calminstruction get_prefix index*
    local var, val

    arrange var, =anchorForIndex.index
    transform var
    jyes no_compensate
      ;; XXX: at some point this needs to throw errors
      arrange var, =_h5aTokenizerHandle.=DUMMY
    no_compensate:
      arrange prefix, var
      exit

    missing_state_def:
      err 'Missing state definition'
      exit
  end calminstruction


  calminstruction gen_ascii
    local var, val
    local i, j
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno done
      call get_prefix, i

      compute j, 0
      char_loop:
        check j <= 0x7F
        jno char_loop_post

        arrange var, prefix.j
        check defined var
        jyes explicit
          arrange var, prefix.=any
        explicit:
          arrange var, =dq var
          assemble var
          compute j, j + 1
          jump char_loop

    char_loop_post:
      compute i, i + 1
      jump state_loop

    done:
      exit
  end calminstruction

  calminstruction gen_unicode
    local var
    local i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno done
      call get_prefix, i

      arrange var, prefix.=eof
      check defined var
      jyes explicit
        arrange var, prefix.=any
      explicit:
        arrange var, =dq var
        assemble var
        compute i, i + 1
        jump state_loop

    done:
      exit
  end calminstruction

  calminstruction gen_eof
    local var
    local i
    compute i, 0

    state_loop:
      check i < NUM_STATES
      jno done
      call get_prefix, i

      ;; No checking if it exists: it has been done in the definition itself
      arrange var, =dq prefix.=any
      assemble var
      compute i, i + 1
      jump state_loop

    done:
      exit
  end calminstruction

  calminstruction gen_spc
    asm db 0x00
  end calminstruction


  _k_h5a_Tokenizer_ascii_matrix:
    gen_ascii
  _k_h5a_Tokenizer_unicode_table:
    gen_unicode
  _k_h5a_Tokenizer_eof_table:
    gen_eof
  _k_h5a_Tokenizer_spcAction_table:
    gen_spc

  purge get_prefix, gen_ascii, gen_unicode, gen_eof
end macro

