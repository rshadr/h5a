;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

format ELF64

extrn calloc
extrn free

public _CharacterQueueConstruct
public _CharacterQueueDestroy
public _CharacterQueuePushFront
public _CharacterQueuePushBack
public _CharacterQueuePopFront
public _CharacterQueueSubscript

section '.rodata'
_CharacterQueue_init_capacity:
  dd 16

calloc_cb:
  dq calloc
free_cb:
  dq free

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
    call qword [calloc_cb]
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
    call qword [free_cb]
  end with_saved_regs

  ;zero_init rdi, sizeof.CharacterQueue

  leave
  ret

_CharacterQueueGrow:
  ;; RDI: _NonNull CharacterQueue *queue
  ;; -> void
  push rbp
  mov rbp, rsp
  ;; XXX ...
  leave
  ret


_CharacterQueuePushFront:
;; RDI: _NonNull CharacterQueue *queue
;; ESI: char32_t c
;; -> EAX: char32_t c
  push rbp
  mov rbp, rsp

  mov ecx, dword [rdi + CharacterQueue.size]
  cmp ecx, [rdi + CharacterQueue.capacity]
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
  cmp ecx, [rdi + CharacterQueue.capacity]
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
