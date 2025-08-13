;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
;;;; The `H5aCharacterQueue` class is used by the tokenizer for input buffering
;;;;
;;;; It is very similar to the `std::deque` container from C++ with some
;;;; notable adaptations:
;;;;
;;;; - Pushing can be done from the front and the back
;;;; - Can only pop from the front
;;;; - Subscripting (C++: operator[]) does not create missing entries and
;;;;    returns a pointer
;;;; - Its capacity is always a power of 2, hence the recurring "dec/and" idiom
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

format ELF64


section '.rodata'
_h5aCharacterQueue_init_capacity:
  dd 16


section '.text' executable

func _h5aCharacterQueueConstruct, public
;; R12: H5aParser *parser
;; RDI: H5aCharacterQueue *queue
  with_saved_regs rbx
    mov rbx, rdi

    ; mov rdi, rbx
    zero_init rdi, sizeof.H5aCharacterQueue

    xor rdi,rdi
    mov edi, dword [_h5aCharacterQueue_init_capacity]
    xor rsi,rsi
    mov sil, 4
    call qword [r12 + H5aParser.calloc_cb]
    ; XXX: check
    mov qword [rbx + H5aCharacterQueue.data], rax

    mov edx, dword [_h5aCharacterQueue_init_capacity]
    mov dword [rbx + H5aCharacterQueue.capacity], edx
  end with_saved_regs
  ret
end func


func _h5aCharacterQueueDestroy, public
;; RDI: H5aCharacterQueue *queue
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, qword [rbx + H5aCharacterQueue.data]
    call qword [r12 + H5aParser.free_cb]

    zero_init rbx, sizeof.H5aCharacterQueue
  end with_saved_regs
  ret
end func


func _h5aCharacterQueueGrow, public
;; RDI: H5aCharacterQueue *queue
;; -> void
;;
;; DESCRIPTION:
;;   Doubles the capacity of `queue` and rearranges contents into a continuous
;;   block

  with_saved_regs rbx, r10, r13, r14, r15
    mov rbx, rdi ;queue struct
    xor r13,r13
    mov r13d, dword [rbx + H5aCharacterQueue.capacity]
    shl r13d, 1 ;new_capacity

    mov rdi, r13
    xor rsi,rsi
    mov sil, 4
    call qword [r12 + H5aParser.calloc_cb]
    mov r10, rax ;new_data

    ;; step 0: compute offsets
    xor r14,r14
    xor r15,r15
    mov r14d, dword [rbx + H5aCharacterQueue.capacity]
    mov r15d, dword [rbx + H5aCharacterQueue.front_idx]
    mov ecx, dword [rbx + H5aCharacterQueue.back_idx]
    cmp r14d, ecx
    cmovbe r14d, ecx
    sub r14d, r15d ;old_capacity - front_idx

    ;; step 1: store back irrelevant data
    mov dword [rbx + H5aCharacterQueue.capacity], r13d
    mov r13, r10 ;new_data persists now

    ;; step 2: bring primary slice forward
    lea rdi, [r13 + 0]
    mov rsi, qword [rbx + H5aCharacterQueue.data]
    lea rsi, [rsi + r15 * 4]
    mov rdx, r14
    shl rdx, 2
    call qword [r12 + H5aParser.memcpy_cb]

    ;; step 3: bring secondary slice backward
    lea rdi, [r13 + r14 * 4]
    mov rsi, qword [rbx + H5aCharacterQueue.data]
    lea rsi, [rsi + 0]
    xor rdx,rdx
    mov edx, dword [rbx + H5aCharacterQueue.back_idx]
    shl rdx, 2
    call qword [r12 + H5aParser.memcpy_cb]

    ;; step 4: cleanup
    mov rdi, qword [rbx + H5aCharacterQueue.data]
    call qword [r12 + H5aParser.free_cb]
    mov qword [rbx + H5aCharacterQueue.data], r13

    xor eax,eax
    mov dword [rbx + H5aCharacterQueue.front_idx], eax

    mov ecx, dword [rbx + H5aCharacterQueue.size]
    mov dword [rbx + H5aCharacterQueue.back_idx], ecx

  end with_saved_regs
  ret
end func


func _h5aCharacterQueuePushBack, public
;; RDI: H5aCharacterQueue *queue
;; RSI: char32_t c
;; -> RAX: char32_t c
  with_saved_regs rbx, r13, r14
    mov rbx, rdi ;queue
    xor r13,r13  ;capacity
    mov r14, rsi ;c

    mov ecx, dword [rbx + H5aCharacterQueue.size]
    cmp ecx, dword [rbx + H5aCharacterQueue.capacity]
    jb .noGrow

    mov rdi, rbx
    call _h5aCharacterQueueGrow

.noGrow:
    xor rdx,rdx
    mov edx, dword [rbx + H5aCharacterQueue.back_idx]
    mov rdi, qword [rbx + H5aCharacterQueue.data]
    mov dword [rdi + rdx * 4], r14d

    mov r13d, dword [rbx + H5aCharacterQueue.capacity]
    dec r13d ;2-adic mask
    inc edx
    and edx, r13d
    mov dword [rbx + H5aCharacterQueue.back_idx], edx

    inc dword [rbx + H5aCharacterQueue.size]

    mov rax, r14
  end with_saved_regs
  ret
end func


func _h5aCharacterQueuePushFront, public
;; RDI: H5aCharacterQueue *queue
;; RSI: char32_t c
;; -> RAX: char32_t c
  with_saved_regs rbx, r13, r14
    mov rbx, rdi ;queue
    xor r13,r13  ;capacity
    mov r14, rsi ;c

    mov ecx, dword [rbx + H5aCharacterQueue.size]
    cmp ecx, dword [rbx + H5aCharacterQueue.capacity]
    jb .noGrow

    mov rdi, rbx
    call _h5aCharacterQueueGrow

.noGrow:
    xor rdx,rdx
    mov edx, dword [rbx + H5aCharacterQueue.front_idx]
    dec edx
    mov esi, dword [rbx + H5aCharacterQueue.capacity]
    dec esi ;2-adic mask
    and edx, esi

    mov rdi, qword [rbx + H5aCharacterQueue.data]
    mov dword [rdi + rdx * 4], r14d

    inc dword [rbx + H5aCharacterQueue.size]

    mov rax, r14
  end with_saved_regs
  ret
end func


func _h5aCharacterQueuePopFront, public
;; RDI: H5aCharacterQueue *queue
;; -> RAX: char32_t c
;; -> RDX: bool was_popped
  with_saved_regs rbx
    mov rbx, rdi ;queue
    xor rax,rax
    xor rdx,rdx

    mov eax, dword [rbx + H5aCharacterQueue.size]
    test eax,eax
    jz .finish

    mov rdi, qword [rbx + H5aCharacterQueue.data]
    mov ecx, dword [rbx + H5aCharacterQueue.front_idx]
    mov eax, dword [rdi + rcx * 4]

    mov esi, dword [rbx + H5aCharacterQueue.capacity]
    dec esi ;2-adic mask
    inc ecx
    and ecx, esi
    mov dword [rbx + H5aCharacterQueue.front_idx], ecx

    dec dword [rbx + H5aCharacterQueue.size]

    mov dl, 1

.finish:
  end with_saved_regs
  ret
end func


func _h5aCharacterQueueSubscript, public
;; RDI: H5aCharacterQueue *queue
;; RSI: uint32_t index
;; -> RAX: _Nullable char32_t *c
  with_saved_regs rbx
    mov rbx, rdi ;queue
    xor rax,rax

    mov r8, qword [rbx + H5aCharacterQueue.data]

    xor rcx,rcx
    mov ecx, dword [rbx + H5aCharacterQueue.size]
    cmp rsi, rcx
    jae .finish

    mov edx, dword [rbx + H5aCharacterQueue.capacity]
    mov eax, dword [rdi + H5aCharacterQueue.front_idx]
    sub edx, eax

    cmp ecx, edx
    jae .secondarySlice

.primarySlice:
  add esi, dword [rdi + H5aCharacterQueue.front_idx]
.secondarySlice:
  lea rax, [r8 + rsi * 4]

.finish:
  end with_saved_regs
  ret
end func


func _h5aCharacterQueueClear, public
;; RDI: H5aCharacterQueue *queue
;; -> void
  mov rdx, rdi

  xor rcx,rcx
  mov ecx, dword [rdx + H5aCharacterQueue.capacity]
  mov rdi, qword [rdx + H5aCharacterQueue.data]
  zero_init rdi, ecx

  xor eax,eax
  mov dword [rdx + H5aCharacterQueue.size], eax
  mov dword [rdx + H5aCharacterQueue.front_idx], eax
  mov dword [rdx + H5aCharacterQueue.back_idx], eax

  ret
end func

