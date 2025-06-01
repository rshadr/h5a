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

public _CharacterQueueConstruct
public _CharacterQueueDestroy
public _CharacterQueueGrow
public _CharacterQueuePushFront
public _CharacterQueuePushBack
public _CharacterQueuePopFront
public _CharacterQueueSubscript

section '.rodata'
_CharacterQueue_init_capacity:
  dd 16

section '.text' executable

_CharacterQueueConstruct:
;; RDI: CharacterQueue *queue
  with_saved_regs rbx
    mov rbx, rdi
    zero_init rdi, sizeof.CharacterQueue

    xor rdi,rdi
    mov dil, 8
    mov rsi,rsi
    mov esi, dword [_CharacterQueue_init_capacity]
    call calloc
    ; XXX: check

    mov qword [rbx + CharacterQueue.data], rax
    mov ecx, dword [_CharacterQueue_init_capacity]
    mov dword [rbx + CharacterQueue.capacity], ecx
    ; XXX: indices?
    
  end with_saved_regs
  ret

_CharacterQueueDestroy:
  push rbp
  mov rbp, rsp

  with_saved_regs rdi
    mov rdi, [rdi + CharacterQueue.data]
    call free
  end with_saved_regs

  ;zero_init rdi, sizeof.CharacterQueue

  leave
  ret

_CharacterQueueGrow:
  ;; RDI: _NonNull CharacterQueue *queue
  ;; -> void
  with_stack_frame
  with_saved_regs rbx, r10, r13, r14
    ; r10 scratch
    mov r13, rdi ;queue struct
    xor r14,r14 ;new_capacity
    xor rbx,rbx ;new_items
    
    mov r14d, dword [r13 + CharacterQueue.capacity]
    shl r14d, 1

    xor rdi,rdi
    mov dil, 1
    xor rsi,rsi
    mov rsi, r14
    call calloc
    mov rbx, rax

    mov esi, dword [r13 + CharacterQueue.size]
    test esi,esi
    jz .simpleCase
    mov eax, dword [r13 + CharacterQueue.front_idx]
    mov ecx, dword [r13 + CharacterQueue.back_idx]
    cmp eax, ecx
    jl .simpleCase

.complexCase:
    xor r10,r10 ;offset_from_end
    mov r10d, dword [r13 + CharacterQueue.capacity]
    sub r10d, eax

    ; step 1: copy back part to front
    lea rdi, [rbx + 0]
    mov rsi, qword [r13 + CharacterQueue.data]
    lea rsi, [rsi + r10 * 4]
    mov rdx, r10
    call memcpy

    ; step 2: copy front part to back
    lea rdi, [rbx + r10 * 4]
    mov rsi, qword [r13 + CharacterQueue.data]
    xor rdx,rdx
    mov edx, dword [r13 + CharacterQueue.size]
    sub edx, r10d
    call memcpy

    jmp .finish

.simpleCase:
    mov rdi, rbx
    mov rsi, qword [r13 + CharacterQueue.data]
    xor rax,rax
    mov eax, dword [r13 + CharacterQueue.capacity]
    lea rdx, [rax * 4]
    call memcpy
    ;fallthrough
.finish:
  mov dword [r13 + CharacterQueue.capacity], r14d
  mov rdi, qword [r13 + CharacterQueue.data]
  call free
  mov qword [r13 + CharacterQueue.data], rbx

  end with_saved_regs
  end with_stack_frame
  ret


_CharacterQueuePushFront:
;; RDI: _NonNull CharacterQueue *queue
;; ESI: char32_t c
;; -> EAX: char32_t c
  push rbp
  mov rbp, rsp

  mov ecx, dword [rdi + CharacterQueue.size]
  cmp ecx, dword [rdi + CharacterQueue.capacity]
  jl .noGrow

  with_saved_regs rdi, rsi
    call _CharacterQueueGrow
  end with_saved_regs

.noGrow:
  xor rcx,rcx
  mov ecx, dword [rdi + CharacterQueue.front_idx]
  mov rax, qword [rdi + CharacterQueue.data]

  test ecx,ecx
  jnz .inRange ;front_idx > 0

  mov ecx, dword [rdi + CharacterQueue.capacity]
.inRange:
  dec ecx

  mov dword [rax + rcx * 4], esi
  mov dword [rdi + CharacterQueue.front_idx], ecx
  inc dword [rdi + CharacterQueue.size]
  xor rax,rax
  mov eax,esi

  leave
  ret


_CharacterQueuePushBack:
;; RDI: _NonNull CharacterQueue *queue
;; ESI: char32_t c
;; -> EAX: char32_t c
  push rbp
  mov rbp, rsp

  mov ecx, dword [rdi + CharacterQueue.size]
  cmp ecx, dword [rdi + CharacterQueue.capacity]
  jne .noGrow

  with_saved_regs rdi, rsi
    call _CharacterQueueGrow
  end with_saved_regs
.noGrow:

  xor rcx,rcx
  mov ecx, dword [rdi + CharacterQueue.back_idx]
  mov rax, qword [rdi + CharacterQueue.data]
  mov dword [rax + rcx * 4], esi ;q->data[q->back] = c
  inc dword [rdi + CharacterQueue.size] ;++q->size

  xor edx,edx
  mov eax, dword [rdi + CharacterQueue.back_idx]
  inc eax
  div dword [rdi + CharacterQueue.capacity]
  mov dword [rdi + CharacterQueue.back_idx], edx

  xor rax,rax
  mov eax, edi

  leave
  ret


_CharacterQueuePopFront:
  ;; RDI: _NonNull CharacterQueue *queue
  ;; -> RAX (EAX): char32_t c
  ;; -> RDX (DL): bool status
  push rbp
  mov rbp, rsp

  mov ecx, dword [rdi + CharacterQueue.size]
  test ecx,ecx
  jnz .haveData

  xor rax,rax
  xor rdx,rdx

  leave
  ret

.haveData:
  ;; q->front_idx = (q->front_idx + 1) % q->capacity
  xor edx,edx
  xor rax,rax
  mov eax, dword [rdi + CharacterQueue.front_idx]
  mov rcx, qword [rdi + CharacterQueue.data]
  mov r8d, dword [rcx + rax * 4]

  inc eax
  ;; q->front_idx = (q->front_idx + 1) % q->capacity
  div dword [rdi + CharacterQueue.capacity]
  mov dword [rdi + CharacterQueue.front_idx], edx
  
  dec dword [rdi + CharacterQueue.size]

  xor rdx,rdx
  mov rdx, 1
  ; no need to upper-clear
  mov eax, r8d

  leave
  ret


_CharacterQueueSubscript:
  ;;
  ;; C++ like array[] operator, except it doesn't create missing spots
  ;;
  ;;
  ;; RDI (a): CharacterQueue *cqueue
  ;; ESI (a): i32 index
  ;; -> RAX: char32_t *addr
  ;movzx rsi, esi
  cmp esi, dword [rdi + CharacterQueue.size]
  jge .fail

  mov rdx, qword [rdi + CharacterQueue.data]

  mov ecx, dword [rdi + CharacterQueue.capacity]

  ;sub ecx, dword [rdi + CharacterQueue.front_idx]
  mov eax, dword [rdi + CharacterQueue.front_idx]
  sub ecx, eax

  cmp esi, ecx
  jge .lateSlice
  ;; [c c c 0 0 0 c c]
  ;;        ^     ^
  ;;        e     f
  ;;        n     r
  ;;        d     o
  ;;              n
  ;;              t
  ;;
  ;;  a a a a     b b
  ;;
  ;; a: late slice
  ;; b: early slice
.earlySlice:
  add esi, dword [rdi + CharacterQueue.front_idx]
.lateSlice:
  lea rax, [rdx + rsi * 4]
  ret
  
.fail:
  xor rax,rax
  ret
