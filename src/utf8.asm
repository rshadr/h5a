;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;


include 'align.inc'
include 'macro/struct.inc'
include "util.inc"
include "local.inc"

struct LUTEntry
  lo     dd ?
  hi     dd ?
  mincp  dd ?
  maxcp  dd ?
ends

calminstruction lut_entry lo*,hi*,mincp*,maxcp*
  local var
  emit 4, lo
  emit 4, hi
  emit 4, mincp
  emit 4, maxcp
end calminstruction

INVALID_CODEPOINT constequ 0xFFFD


format ELF64


section '.text' executable

func h5aUTF8Encode, public
  ;; UNTESTED

  ;; RDI (EDI): uint32_t cp
  ;; RSI : char *str
  ;; RDX : size_t len
  ;; -> RAX: size_t enc_len

  cmp edi, 0xD800
  jb .inRange
  cmp edi, 0xDFFF
  ja .inRange
  cmp edi, 0x10FFFF
  jb .inRange

  mov edi, INVALID_CODEPOINT

.inRange:
  lea r11, [lut]
  xor r10,r10

.seqTypeLoop:
  cmp r10b, 4
  jae .afterSeqTypeLoop

  cmp edi, dword [r11 + LUTEntry.maxcp]
  jbe .afterSeqTypeLoop

  inc r10b
  add r11, sizeof.LUTEntry
  jmp .seqTypeLoop

.afterSeqTypeLoop:
  inc r10b
  cmp r10, rdx
  ja .retDry
  test rsi,rsi
  jz .retDry
  test rdx,rdx
  jz .retDry

  jmp .buildSeq

.retDry:
  mov rax, r10
  ret

.buildSeq:
  dec r10b

  mov rax, r10
  mov cl, 6
  mul cl
  mov cl, al
  mov r8d, edi
  shr r8d, cl
  mov eax, dword [r11 + LUTEntry.lo]
  or al, r8b
  mov byte [rsi + 0], al

  xor r9,r9
  mov r9b, 1
  ;; -> drop local regs
.buildSeqLoop:
  cmp r9b, r10b
  jae .finish

  mov r8b, r10b
  dec r8b
  mov al, 6
  mul r8b
  mov cl, al

  mov r10d, edi
  shr r10d, cl
  and r10b, 0x3F

  mov al, 0x80
  or al, r10b

  mov byte [rsi + r9], al

  inc r9b
  jmp .buildSeqLoop

.finish:
  mov eax, r10d
  ret
end func

section '.rodata'
lut:
  lut_entry 0x00, 0x7F, 0, (1 shl 7) - 1
  lut_entry 0xC0, 0xDF, (1 shl 7), (1 shl 11) - 1
  lut_entry 0xE0, 0xEF, (1 shl 11), (1 shl 16) - 1
  lut_entry 0xF0, 0xF7, (1 shl 16), (1 shl 21) - 1

