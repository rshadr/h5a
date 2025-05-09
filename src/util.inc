
calminstruction (var) constequ? val

  compute val,val
  arrange val,val
  publish var:, val

end calminstruction


calminstruction unimplemented?
  asm ud2
end calminstruction


if 0
  calminstruction validate_jxx? opc*
    match =jae?, opc
    jyes good
    ; ...
    match =je?, opc
    jyes good
    match =jg?, opc
    jyes good
    match =jge?, opc
    jyes good
    match =jl?, opc
    jyes good
    match =jle?, opc
    jyes good
    ; ...
    match =jne?, opc
    jyes good
    match =jng?, opc
    jyes good
    ; ...
    match =jnz?, opc
    jyes good
    ; ...
    match =jz?, opc
    jyes good
    ; ...

  bad:
    err "invalid conditional jump name"
    exit
  good:
    exit
  end calminstruction


  calminstruction likely? line&
    local opc, target
    match opc target, line
    jno fail

    call validate_jxx, opc

    asm db 0x3E
    arrange var, opc target
    assemble var

  fail:
    err "'likely' requires a conditional jump instruction as line argument"
    exit
  end calminstruction

end if

calminstruction likely? opc*,rest&
  local var

  asm db 0x3E
  arrange var, opc rest
  assemble var

end calminstruction


calminstruction unlikely? opc*,rest&
  local var

  asm db 0x2E
  arrange var, opc rest
  assemble var

end calminstruction


macro enum?
  local counter
  counter = 0

  calminstruction ? line&
    local var, val
    local name

    match =end? =enum?, line
    jyes finish
    match name == val, line
    jyes explicit_val
    match name, line
    jyes implicit_val

    err 'Invalid enum body statement'

    explicit_val:
      arrange var, name
      compute val, val
      ;assert val eqtype 0
      publish var:, val
      compute counter, val + 1
      exit

    implicit_val:
      arrange var, name
      compute val, counter
      publish var:, counter
      compute counter, counter + 1
      exit

    finish:
      arrange var, =purge ?
      assemble var
      exit
  end calminstruction

end macro

macro with_saved_regs? regs&
  local saved_regs

  calminstruction ? line&
    local var, val

    match =end? =with_saved_regs?, line
    jyes finish

    assemble line
    exit

  finish:
  pop_regs:
    take val, saved_regs
    jno final

    arrange var, =pop val
    assemble var

    jump pop_regs

  final:
    arrange var, =purge ?
    assemble var
    exit
  end calminstruction

  irp reg, regs
    push reg
    saved_regs equ reg
  end irp
end macro


macro with_stack_frame?
  push rbp
  mov rbp, rsp

  calminstruction ? line&
    local var

    match =end? =with_stack_frame?, line
    jyes finish

  unknown:
    assemble line
    exit

  finish:
    asm leave
    arrange var, =purge ?
    assemble var
    exit
  end calminstruction

end macro


calminstruction zero_init? ptr*,size*
  local var

  match =rdi?, ptr
  jyes already_rsi

  arrange var, =mov =rdi, ptr
  assemble var

already_rsi:
  asm xor al,al
  arrange var, =mov =rcx, size
  assemble var
  asm rep stosb
end calminstruction

