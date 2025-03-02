
macro likely? opc,target
  db 0x3E
  opc target
end macro

macro unlikely? opc,target
  db 0x2E
  opc target
end macro

