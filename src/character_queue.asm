;;;;
;;;;
;;;;
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

format ELF64

extrn calloc
extrn free

public _CharacterQueueConstruct
public _CharacterQueueDestroy
public _CharacterQueuePushBack
public _CharacterQueuePopFront

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
  with_saved_regs rdi
    mov rdi, [rdi + CharacterQueue.data]
    call qword [free_cb]
  end with_saved_regs

  ;zero_init rdi, sizeof.CharacterQueue
  ret

_CharacterQueueGrow:
  ;; RDI: _NonNull CharacterQueue *queue
  ;; -> void
  ;; XXX ...
  ret

_CharacterQueuePushBack:
;; RDI: _NonNull CharacterQueue *queue
;; ESI: char32_t c
;; -> EAX: char32_t
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
  ret


_CharacterQueuePopFront:
  ;; RDI: _NonNull CharacterQueue *queue
  ;; -> EAX: char32_t c
  ;; -> RDX: bool status
  mov ecx, dword [rdi + CharacterQueue.size]
  test ecx,ecx
  jnz .haveData

  xor rax,rax
  xor rdx,rdx
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
  ret
