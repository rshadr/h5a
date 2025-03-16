
macro likely? opc,target
  db 0x3E
  opc target
end macro

macro unlikely? opc,target
  db 0x2E
  opc target
end macro

macro enum
  local counter
  counter = 0

  calminstruction ? line&
    local var, val, name

    match =end? =enum?, line
    jyes done
    match name == val, line
    jyes explicit_val
    match name , line
    jyes implicit_val

    err 'Invalid enum body form'

    explicit_val:
      err 'not implemented yet'
      exit

    implicit_val:
      compute val, counter
      ;arrange var, name == counter
      ;assemble var
      arrange var, name
      publish var:, counter
      compute counter, counter + 1
      exit

    done:
      arrange var, =purge ?
      assemble var
      exit
  end calminstruction
end macro

assert defined DATA_STATE
