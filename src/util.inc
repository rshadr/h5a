
calminstruction (var) constequ? val

  compute val,val
  arrange val,val
  publish var:, val

end calminstruction


calminstruction unimplemented?
  asm ud2
end calminstruction


calminstruction unreachable?
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


calminstruction pick_me?
  asm push rax
  asm push rcx
  asm push rdx
  asm push rbx
  asm push rbp
  asm push rsi
  asm push rdi

  asm push r8
  asm push r9
  asm push r10
  asm push r11
  asm push r12
  asm push r13
  asm push r14
  asm push r15

  asm sub rsp, 32
  asm vmovdqu [rsp], ymm0
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm1
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm2
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm3
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm4
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm5
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm6
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm7
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm8
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm9
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm10
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm11
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm12
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm13
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm14
  asm sub rsp, 32
  asm vmovdqu [rsp], ymm15


  ; XXX: ...


  asm vmovdqu ymm15, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm14, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm13, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm12, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm11, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm10, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm9, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm8, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm7, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm6, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm5, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm4, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm3, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm2, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm1, [rsp]
  asm add rsp, 32
  asm vmovdqu ymm0, [rsp]
  asm add rsp, 32

  asm pop r15
  asm pop r14
  asm pop r13
  asm pop r12
  asm pop r11
  asm pop r10
  asm pop r9
  asm pop r8

  asm pop rdi
  asm pop rsi
  asm pop rbp
  asm pop rbx
  asm pop rdx
  asm pop rcx
  asm pop rax
end calminstruction


calminstruction zero_init? ptr*,size*
  local var

  match =rdi?, ptr
  jyes already_rsi

  arrange var, =mov =rdi, ptr
  assemble var

already_rsi:
  asm xor al,al
  asm xor rcx,rcx
  arrange var, =mov =ecx, size
  assemble var
  asm rep stosb
end calminstruction


macro func? name*, vis*

  calminstruction maybe_vis n*, v*
    local var
    ;; Always do public until we figure out debug symbols...
    ;match =public?, v
    ;jyes vis_public
    ;exit

  vis_public:
    arrange var, =public n
    assemble var
    exit
  end calminstruction

  maybe_vis name, vis
  label name
  purge maybe_vis

  calminstruction ? line&
    match =end? =func?, line
    jyes finish

    assemble line
    exit

  finish:
    asm purge ?
    exit
  end calminstruction
end macro

