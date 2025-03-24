
calminstruction (var) constequ? val

  compute val,val
  arrange val,val
  publish var:, val

end calminstruction

calminstruction likely? opc,rest&
  local var

  ; XXX: check if valid jump opcode

  asm db 0x3E
  arrange var, opc rest
  assemble var

end calminstruction


calminstruction unlikely? opc,rest&
  local var

  ; XXX: check if valid jump opcode

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
