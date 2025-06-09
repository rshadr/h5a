;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
;;;; Generic vector class with derived types
;;;; - string
;;;; - stack of insertion modes
;;;; - handle vector
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn calloc
extrn realloc
extrn free
extrn memcpy

extrn grapheme_encode_utf8


section '.text' executable

;;;
;;; H5aVector<T>
;;;

func _h5aVectorCreate, private
;; RDI : H5aVector<T> *vector
;; RSI : uint32_t initial_bytes
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    xor ecx,ecx
    popcnt ecx, esi
    jz .badCapacity
    cmp ecx, 1
    jne .badCapacity

    xor eax,eax
    mov dword [rbx + H5aVector.size], eax

    mov dword [rbx + H5aVector.capacity], esi

    xor rdi,rdi
    mov edi, esi
    xor rsi,rsi
    inc esi
    call calloc

    mov qword [rbx + H5aVector.data], rax
    jmp .finish

.badCapacity:
  unimplemented

.finish:
  end with_saved_regs
  ret
end func


func _h5aVectorDestroy, private
;; RDI (arg): H5aVector<T> *vector
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, qword [rbx + H5aVector.data]
    call free

    xor rax,rax
    mov qword [rbx + H5aVector.data], rax
    mov dword [rbx + H5aVector.size], eax
    mov dword [rbx + H5aVector.capacity], eax
  end with_saved_regs
  ret
end func


func _h5aVectorMaybeGrow, private
;; RDI : H5aVector *vector
;; RSI : uint32_t need_bytes
;; -> bool was_grown
  with_saved_regs rbx
    mov rbx, rdi

    mov edx, dword [rbx + H5aVector.size]
    add edx, esi
    jo .tooLarge
    mov ecx, dword [rbx + H5aVector.capacity]
    xor rax,rax
    cmp edx, ecx
    jl .finish

.needGrow:
    shl ecx, 1
    jo .tooLarge

    mov dword [rbx + H5aVector.capacity], ecx
    mov rdi, qword [rbx + H5aVector.data]
    xor rsi,rsi
    mov esi, ecx
    call realloc
    mov qword [rbx + H5aVector.data], rax

    xor rax,rax
    mov al, 1
    jmp .finish

.tooLarge:
  unimplemented

.finish:
  end with_saved_regs
  ret
end func


;;;
;;; H5aString
;;;

func _h5aStringCreate, public
;; RDI : H5aString *string
;; -> void
  lea rdi, [rdi]
  xor rsi,rsi
  mov si, 16
  jmp _h5aVectorCreate
end func


func _h5aStringDestroy, public
;; RDI : H5aString *string
;; -> void
  lea rdi, [rdi]
  jmp _h5aVectorDestroy
end func


func _h5aStringClear, public
;; RSI : H5aString *string
;; -> void
  mov rdx, rdi
  xor eax,eax
  mov dword [rdx + H5aString.size], eax
  zero_init qword [rdx + H5aString.data], dword [rdx + H5aString.capacity]
  ret
end func


func _h5aStringPushBackAscii, public
;; RDI : H5aString *string
;; RSI : char8_t c
;; -> void
  xor rcx,rcx
  not cl
  movzx rdx, cl
  not rdx
  test rsi, rdx
  jnz .notAscii

  with_saved_regs rbx, r13, r14
    ; r14 for align
    mov r13, rsi
    mov rbx, rdi
    xor rsi,rsi
    inc esi
    call _h5aVectorMaybeGrow

    mov rdx, qword [rbx + H5aString.data]
    xor rcx,rcx
    mov ecx, dword [rbx + H5aString.size]
    mov byte [rdx + rcx], r13b

    inc dword [rbx + H5aString.size]
  end with_saved_regs

  ret

.notAscii:
  unimplemented
end func


func _h5aStringPutChunk, public
;; RDI : H5aString *string
;; RSI : char utf8[utf8_len]
;; RDX : size_t utf8_len
  with_saved_regs rbx, r13, r15
    mov rbx, rdi ;string
    mov r13, rsi ;utf8
    mov r15, rdx ;utf8_len

    mov rdi, rbx
    mov rsi, rdx
    call _h5aVectorMaybeGrow

    xor rcx,rcx
    mov ecx, dword [rbx + H5aString.size]
    mov rax, qword [rbx + H5aString.data]
    lea rdi, [rax + rcx * 1]
    mov rsi, r13
    mov rdx, r15
    call memcpy

    add dword [rbx + H5aString.size], r15d
  end with_saved_regs
  ret
end func


func _h5aStringPushBackUnicode, public
;; RDI : H5aString *string
;; RSI : char32_t c
;; -> void
  with_stack_frame
    sub rsp, 16 ;char utf8[16]
    push rbx

    mov rbx, rdi

    mov rdi, rsi
    lea rsi, [rbp - 16]
    xor rdx,rdx
    mov dl, 16
    call grapheme_encode_utf8
    mov rdx, rax

    mov rdi, rbx
    lea rsi, [rbp - 16]
    ;mov rdx,rdx
    call _h5aStringPutChunk

    pop rbx
  end with_stack_frame
  ret
end func


;;;
;;; H5aVector<H5aInsertionMode>
;;;

func _h5aModeVectorCreate, public
;; RDI : H5aVector<H5aInsertionMode> *vector
;; -> void
  lea rdi, [rdi]
  xor rsi,rsi
  mov sil, 16
  jmp _h5aVectorCreate
end func


func _h5aModeVectorDestroy, public
;; RDI : H5aVector<H5aInsertionMode> *vector
;; -> void
  lea rdi, [rdi]
  jmp _h5aVectorDestroy
end func


func _h5aModeVectorPushBack, public
;; RDI : H5aVector<H5aInsertionMode> *vector
;; RSI : H5aInsertionMode mode
;; -> void
  with_saved_regs rbx, r13, r14
    ;r14 for align
    mov   rbx, rdi ;vector
    mov   r13, rsi ;mode

    mov   rdi, rbx
    xor   rsi,rsi
    inc   esi
    call  _h5aVectorMaybeGrow

    mov  rdi, qword [rbx + H5aVector.data]
    xor  rcx,rcx
    mov  ecx, dword [rbx + H5aVector.size]
    mov  byte [rdi + rcx * 1], r13b

    inc  dword [rbx + H5aVector.size]
  end with_saved_regs
  ret
end func


func _h5aModeVectorPopBack, public
;; RDI : H5aVector<H5aInsertionMode> *vector
;; -> H5aInsertionMode mode
  mov    rsi, qword [rdi + H5aVector.data]
  mov    ecx, dword [rdi + H5aVector.size]
  dec    ecx
  movzx  rax, byte [rsi + rcx * 1]
  ret
end func


;;;
;;; H5aVector<H5aHandle>
;;;

func _h5aElementVectorCreate, public
  ; ...
  unimplemented
end func


func _h5aElementVectorDestroy, public
  ; ...
  unimplemented
end func


;;;
;;; H5aVector<H5aAttribute>
;;;

func _h5aAttrVectorCreate, public
;; RDI : H5aVector<H5aAttribute> *vector
;; -> void
  with_saved_regs rbx, r13, r14
    mov rbx, rdi

    mov rdi, rbx
    xor rsi,rsi
    mov si, (16 * sizeof.Attribute)
    call _h5aVectorCreate

    xor r13,r13
    mov r13d, dword [rbx + H5aVector.capacity]
    shr r13, (bsr sizeof.Attribute)
    xor r14,r14
.loop:
    cmp r14, r13
    jae .after_loop

    iterate member, Attribute.name,Attribute.value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + member]
      call _h5aStringCreate
    end iterate

    inc r14
    jmp .loop
.after_loop:
  end with_saved_regs
  ret
end func


func _h5aAttrVectorDestroy, public
;; RDI : H5aVector<H5aAttribute> *vector
;; -> void
  with_saved_regs rbx, r13, r14
    mov rbx, rdi

    xor r13,r13
    mov r13d, dword [rbx + H5aVector.capacity]
    shr r13, (bsr sizeof.Attribute)
    xor r14,r14

.loop:
    cmp r14, r13
    jae .after_loop

    iterate member, Attribute.name,Attribute.value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + member]
      call _h5aStringDestroy
    end iterate

    inc r14
    jmp .loop
.after_loop:
    mov rdi, rbx
    call _h5aVectorDestroy
  end with_saved_regs
  ret
end func


func _h5aAttrVectorClear, public
;; RDI : H5aVector<H5aAttribute> *vector
;; -> void
  with_saved_regs rbx, r13, r14
    mov rbx, rdi

    xor r13,r13
    mov r13d, dword [rbx + H5aVector.size]
    shr r13, (bsr sizeof.Attribute)
    xor r14,r14
.loop:
    cmp r14, r13
    jae .after_loop

    iterate member, Attribute.name,Attribute.value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + member]
      call _h5aStringClear
    end iterate

    inc r14
    jmp .loop
.after_loop:
  end with_saved_regs
  ret
end func


func _h5aAttrVectorPushSlot, public
;; RDI : H5aVector<H5aAttribute> *vector
;; -> H5aAttribute *slot
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, rbx
    xor rsi,rsi
    mov sil, sizeof.Attribute
    call _h5aVectorMaybeGrow
    test al,al
    jz .finish

    with_saved_regs r13, r14
      xor r13,r13
      xor r14,r14
      mov r13d, dword [rbx + H5aVector.capacity]
      mov r14d, dword [rbx + H5aVector.size]
      shr r13, (bsr sizeof.Attribute)
      shr r14, (bsr sizeof.Attribute)
      dec r14

.loop:
      cmp r14, r13
      jae .after_loop

      iterate member, Attribute.name,Attribute.value
        mov rcx, r14
        shl rcx, (bsr sizeof.Attribute)
        mov rdx, qword [rbx + H5aVector.data]
        lea rdi, [rdx + rcx + member]
        call _h5aStringCreate
      end iterate

      inc r14
      jmp .loop

.after_loop:
    end with_saved_regs

.finish:
    xor rcx,rcx
    mov ecx, dword [rbx + H5aVector.size]
    dec ecx
    mov rdx, qword [rbx + H5aVector.data]
    shl ecx, (bsr sizeof.Attribute)
    lea rax, [rdx + rcx]
  end with_saved_regs
  ret
end func


