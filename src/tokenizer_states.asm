
include "macro/struct.inc"
include "util.inc"
include "local.inc"


macro define_state? anchor*,index*
  local prefix
  prefix equ _h5a_Tokenizer_handle_#anchor

  section '.text' executable

  macro state_range min*,max*
    repeat 1+max-min, i:min
      prefix.#i:
    end repeat
  end macro

  calminstruction ? line&
    local CODE,NAME,var,val

    ;; What should we do now?
    match =end? =define_state?,line
    jyes done
    match =[=EOF=],line
    jyes eof
    match =[=Anything =else=],line
    jyes any

    local group
    match =[=ASCII? group=],line
    jyes grp

    match =[=U=+CODE NAME=],line
    jyes unicode

  unk:
    ; pass unknowns to assembly process
    assemble line
    exit


  eof:
    arrange var,prefix.=eof:
    assemble var
    exit

  any:
    arrange var,prefix.=any:
    assemble var
    exit

  grp:
    match =alphanumeric,group
    jyes alnum
    match =alpha,group
    jyes alpha
    match =upper =alpha,group
    jyes upper

    jump unk

  alnum:
    asm state_range '0', '9'
  alpha:
    asm state_range 'a', 'z'
  upper:
    asm state_range 'A', 'Z'
    exit

  lower:
    asm state_range 'a', 'z'
    exit

  digit:
    asm state_range '0', '9'
    exit

  hex:
    asm state_range 'a', 'f'
  hup:
    asm state_range 'A', 'F'
    asm state_range '0', '9'
    exit

  hlow:
    asm state_range 'a', 'f'
    asm state_range '0', '9'
    exit

  unicode:
    arrange var, 0x#CODE ;process CODE as hex
    compute val,var
    arrange var,prefix.val:
    assemble var
    exit


  done:
    ; ...

  end calminstruction

end macro


format ELF64

section '.text' executable

public _h5a_Tokenizer_handle_data.any

define_state data,DATA_STATE_INDEX
  [U+0026 AMPERSAND (&)]
    mov qword [r12 + H5aParser.tokenizer.return_state], DATA_STATE_INDEX
    mov qword [r12 + H5aParser.tokenizer.state], CHAR_REF_STATE_INDEX
    xor eax,eax
    ret

  [U+003C LESS-THAN SIGN (<)]
    mov qword [r12 + H5aParser.tokenizer.state], TAG_OPEN_STATE_INDEX
    xor eax,eax
    ret

  [U+0000 NULL]
    ; call _h5a_Tokenizer_error
    ; call _h5a_Tokenizer_emitCharacter
    xor eax,eax
    ret

  [EOF]
    ; jmp _h5a_Tokenizer_emitEof
    xor eax,eax
    ret

  [Anything else]
    xor eax,eax
    ret
end define_state

define_state tag_open,TAG_OPEN_STATE_INDEX
  [ASCII alpha]
    xor eax,eax
    ret
end define_state


define_state character_reference,CHARACTER_REFERENCE_STATE_INDEX
  [::before]
    ret

  [ASCII alphanumeric]
    ; XXX...
    xor eax,eax
    ret

  [U+0023 NUMBER SIGN (#)]
    ; XXX...
    xor eax,eax
    ret

  [Anything else]
    ; XXX...
    xor eax,eax
    ret
end define_state

