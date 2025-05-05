;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;


format ELF64

public unicodeIsLeadingSurrogate
public unicodeIsTrailingSurrogate
public unicodeIsSurrogate
public unicodeIsNonCharacter


section 'text' executable

unicodeIsLeadingSurrogate:
  xor rax,rax
  mov edx, edi
  cmp edi, 0xD800
  setge cl
  cmp edx, 0xDBFF
  setle al
  and al, cl
  ret

unicodeIsTrailingSurrogate:
  xor rax,rax
  mov edx, edi
  cmp edi, 0xDC00
  setge cl
  cmp edx, 0xDFFF
  setle al
  and al, cl
  ret

unicodeIsSurrogate:
;; RDI (EDI) (a): char32_t c
  call unicodeIsLeadingSurrogate
  mov esi, eax
  call unicodeIsTrailingSurrogate
  and al, sil
  ret

unicodeIsNonCharacter:
;; RDI (EDI) (a): char32_t c

  xor rax,rax
  cmp edi, 0xFFD0
  jl .fail
  cmp edi, 0xFDEF
  jg .highRange
.fail:
  ret

.highRange:
  mov rax, rdi
  xor rcx,rcx
  mov cl, nonCharacterTable_size
  lea rdi, [nonCharacterTable]
  repnz scasd
  test rcx,rcx
  setnz al
  ret


section '.rodata'

align 4
nonCharacterTable:
  dd 0xFFFE
  dd 0xFFFF
  dd 0x1FFFE
  dd 0x1FFFF
  dd 0x2FFFE
  dd 0x2FFFF
  dd 0x3FFFE
  dd 0x3FFFF
  dd 0x4FFFE
  dd 0x4FFFF
  dd 0x5FFFE
  dd 0x5FFFF
  dd 0x6FFFE
  dd 0x6FFFF
  dd 0x7FFFE
  dd 0x7FFFF
  dd 0x8FFFE
  dd 0x8FFFF
  dd 0x9FFFE
  dd 0x9FFFF
  dd 0xAFFFE
  dd 0xAFFFF
  dd 0xBFFFE
  dd 0xBFFFF
  dd 0xCFFFE
  dd 0xCFFFF
  dd 0xDFFFE
  dd 0xDFFFF
  dd 0xEFFFE
  dd 0xEFFFF
  dd 0xFFFFE
  dd 0xFFFFF
  dd 0x10FFFE
  dd 0x10FFFF
nonCharacterTable_size equ 34
