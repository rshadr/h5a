;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn calloc
extrn reallocarray
extrn free
extrn memcpy
extrn grapheme_encode_utf8

public _h5aStringCreate
public _h5aStringDestroy
public _h5aStringClear
public _h5aStringPushBackAscii
public _h5aStringPutChunk
public _h5aStringPushBackUnicode


section '.text' executable

_h5aStringCreate:
;; RDI (arg): H5aString *string
with_saved_regs rbx
  mov rbx, rdi

  xor eax,eax
  mov dword [rbx + H5aString.size], eax
  mov ecx, dword [_k_h5a_string_init_capacity]
  mov dword [rbx + H5aString.capacity], ecx
  xor rdi,rdi
  mov edi, ecx
  xor rsi,rsi
  inc esi
  call calloc

  mov qword [rbx + H5aString.data], rax
end with_saved_regs
  ret

_h5aStringDestroy:
;; RDI (arg): H5aString *string
with_saved_regs rbx
  mov rbx, rdi

  mov rdi, [rbx + H5aString.data]
  call free
end with_saved_regs
  ret

_h5aStringClear:
;; RDI (arg): H5aString *string
;; -> void
  mov rsi, rdi
  xor al,al
  xor rcx,rcx
  mov ecx, dword [rsi + H5aString.capacity]
  mov rdi, qword [rsi + H5aString.data]
  rep stosb
  ret

_h5aStringMaybeGrow:
;; RDI (arg): H5aString *string
;; RSI (ESI): uint32_t need
;; -> void
with_saved_regs rbx
  mov rbx, rdi

  mov edx, dword [rbx + H5aString.size]
  add edx, esi
  mov ecx, dword [rbx + H5aString.capacity]
  cmp edx, ecx
  jl .finish

  shl ecx, 1
  mov dword [rbx + H5aString.capacity], ecx
  mov rdi, qword [rbx + H5aString.data]
  xor rsi,rsi
  mov esi, ecx
  xor rdx,rdx
  mov dl, 8
  call reallocarray

  mov qword [rbx + H5aString.data], rax

.finish:
end with_saved_regs
  ret

_h5aStringPushBackAscii:
;; RDI (arg): H5aString *string
;; RSI (SIL): char8_t c
;; -> void
  xor rcx,rcx
  not cl
  and rsi,rcx
  with_saved_regs rbx, r13, r14
    ;r14 for align
    mov r13, rsi
    mov rbx, rdi
    xor rsi,rsi
    mov esi, dword [rbx + H5aString.size]
    inc esi
    call _h5aStringMaybeGrow

    mov rdx, qword [rbx + H5aString.data]
    xor rcx,rcx
    mov ecx, dword [rbx + H5aString.size]
    mov byte [rdx + rcx], r13b
    inc dword [rbx + H5aString.size]
  end with_saved_regs
  ret

_h5aStringPutChunk:
;; RDI (arg): H5aString *string
;; RSI (arg): char utf8[utf8_len]
;; RDX (arg): size_t utf8_len
with_saved_regs rbx, r13, r15
  mov rbx, rdi
  mov r13, rsi ;char utf8[utf8_len]
  mov r15, rdx ;size_t utf8_len

  xor rsi,rsi
  mov esi, edx
  add esi, dword [rbx + H5aString.size]
  call _h5aStringMaybeGrow

  xor rcx,rcx
  mov ecx, dword [rbx + H5aString.size]
  mov rdi, qword [rbx + H5aString.data]
  lea rdi, [rdi + rcx*1]
  mov rsi, r13
  mov rdx, r15
  call memcpy

  add dword [rbx + H5aString.size], edx
end with_saved_regs
  ret

_h5aStringPushBackUnicode:
;; RDI (arg): H5aString *string
;; RSI (ESI): char32_t c
;; -> void
;;with_stack_frame
push rbp
mov rbp, rsp
  ;sub rsp, 16 ;char utf8[16];
  ;sub rsp, 8 ;size_t written;
  sub rsp, (16 + 8)
  with_saved_regs rbx
    ;push rbx ;save string
    mov rbx, rdi

    mov rdi, rsi
    lea rsi, [rbp - 0]
    xor rdx,rdx
    mov dl, 16
    call grapheme_encode_utf8
    mov qword [rbp - 16], rax

    mov rdi, rbx
    lea rsi, [rbp - 0]
    mov rdx, qword [rbp - 16]
    call _h5aStringPutChunk
  end with_saved_regs
;;end with_stack_frame
  mov rsp, rbp
  pop rbp
  ret

section '.rodata'

_k_h5a_string_init_capacity:
  dd 8

