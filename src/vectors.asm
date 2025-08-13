;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;
;;;; Generic vector class with derived types
;;;; - string
;;;; - stack of insertion modes
;;;; - handle vector
;;;; - attribute vector
;;;; - attribute view vector
;;;;

include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn h5aUTF8Encode


section '.text' executable

;;;
;;; H5aVector<T>
;;;

func _h5aVectorCreate, private
;; R12 : H5aParser *parser
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
    call qword [r12 + H5aParser.calloc_cb]

    mov qword [rbx + H5aVector.data], rax
    jmp .finish

.badCapacity:
  unimplemented

.finish:
  end with_saved_regs
  ret
end func


func _h5aVectorDestroy, private
;; R12 : H5aParser *parser
;; RDI (arg): H5aVector<T> *vector
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, qword [rbx + H5aVector.data]
    call qword [r12 + H5aParser.free_cb]

    xor rax,rax
    mov qword [rbx + H5aVector.data], rax
    mov dword [rbx + H5aVector.size], eax
    mov dword [rbx + H5aVector.capacity], eax
  end with_saved_regs
  ret
end func


func _h5aVectorMaybeGrow, private
;; R12 : H5aParser *parser
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
    call qword [r12 + H5aParser.realloc_cb]
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
;; R12 : H5aParser *parser
;; RDI : H5aString *string
;; -> void
  lea rdi, [rdi]
  xor rsi,rsi
  mov si, 16
  jmp _h5aVectorCreate
end func


func _h5aStringDestroy, public
;; R12 : H5aParser *parser
;; RDI : H5aString *string
;; -> void
  lea rdi, [rdi]
  jmp _h5aVectorDestroy
end func


func _h5aStringClear, public
;; R12 : H5aParser *parser
;; RSI : H5aString *string
;; -> void
  mov rdx, rdi
  xor eax,eax
  mov dword [rdx + H5aString.size], eax
  zero_init qword [rdx + H5aString.data], dword [rdx + H5aString.capacity]
  ret
end func


func _h5aStringPushBackAscii, public
;; R12 : H5aParser *parser
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
;; R12 : H5aParser *parser
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
    call qword [r12 + H5aParser.memcpy_cb]

    add dword [rbx + H5aString.size], r15d
  end with_saved_regs
  ret
end func


func _h5aStringPushBackUnicode, public
;; R12 : H5aParser *parser
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
    call h5aUTF8Encode
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
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aInsertionMode> *vector
;; -> void
  lea rdi, [rdi]
  xor rsi,rsi
  mov sil, 16
  jmp _h5aVectorCreate
end func


func _h5aModeVectorDestroy, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aInsertionMode> *vector
;; -> void
  lea rdi, [rdi]
  jmp _h5aVectorDestroy
end func


func _h5aModeVectorPushBack, public
;; R12 : H5aParser *parser
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
;; R12 : H5aParser *parser
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
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aHandle> *vector
;; -> void
  with_stack_frame
    xor rsi,rsi
    mov si, (16 * sizeof.H5aHandle)
    call _h5aVectorCreate
  end with_stack_frame
  ret
end func


func _h5aElementVectorDestroy, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aHandle> *vector
;; -> void
  with_saved_regs rbx, r13, r14
    mov rbx, rdi ;vector
    xor r13,r13
    mov r13d, dword [rbx + H5aVector.size] ;size
    shr r13, (bsr sizeof.H5aVector)
    xor r14,r14 ;counter

.loop:
    cmp r14, r13
    jae .after_loop

    mov rdi, qword [r12 + H5aParser.sink.user_data]
    mov rcx, r14
    shl rcx, (bsr sizeof.H5aHandle)
    mov r8, qword [rbx + H5aVector.data]
    mov rsi, qword [r8 + rcx + H5aHandle.x]
    mov rdx, qword [r8 + rcx + H5aHandle.y]
    mov rax, qword [r12 + H5aParser.sink.vtable]
    call qword [rax + H5aSinkVTable.destroy_handle]

    inc r14
    jmp .loop

.after_loop:
    mov rdi, rbx
    call _h5aVectorDestroy
  end with_saved_regs
  ret
end func


func _h5aElementVectorPeekBack, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aHandle> *vector
;; -> RAX:RDX : H5aHandle handle
  unimplemented

  mov rcx, qword [rdi + H5aVector.data]
  xor rsi,rsi
  mov esi, dword [rdi + H5aVector.size]
  test esi,esi
  jz .emptyStack

  mov rax, qword [rcx + rsi + H5aHandle.x]
  mov rdx, qword [rcx + rsi + H5aHandle.y]
  ret

.emptyStack:
  unimplemented
end func


func _h5aElementVectorPushBack, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aHandle> *vector
;; RSI:RDX : H5aHandle handle
;; -> void
;;; UNTESTED
  unimplemented

  with_saved_regs rbx, r13, r14
    mov rbx, rdi ;vector

    mov rdi, qword [r12 + H5aParser.sink.user_data]
    ;mov rsi, rsi
    ;mov rdx, rdx
    mov rax, qword [r12 + H5aParser.sink.vtable]
    call qword [rax + H5aSinkVTable.clone_handle]
    ; -> RAX:RDX : handle
    mov r13, rax
    mov r14, rdx

    mov rdi, rbx
    xor rsi,rsi
    mov sil, sizeof.H5aHandle
    call _h5aVectorMaybeGrow

    xor rcx,rcx
    mov ecx, dword [rbx + H5aVector.size]
    mov rdx, qword [rbx + H5aVector.data]
    mov qword [rdx + rcx + H5aHandle.x], r13
    mov qword [rdx + rcx + H5aHandle.y], r14

    add ecx, sizeof.H5aHandle
    mov dword [rbx + H5aVector.size], ecx
  end with_saved_regs
  ret

end func


func _h5aElementVectorPopBack, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aHandle> *vector
;; -> RAX:RAX : H5aHandle handle

  unimplemented

  ; ...
  ret
end func


;;;
;;; H5aVector<H5aAttribute>
;;;

func _h5aAttrVectorCreate, public
;; R12 : H5aParser *parser
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

    iterate member, name,value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + Attribute.#member]
      call _h5aStringCreate
    end iterate

    inc r14
    jmp .loop
.after_loop:
  end with_saved_regs
  ret
end func


func _h5aAttrVectorDestroy, public
;; R12 : H5aParser *parser
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

    iterate member, name,value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + Attribute.#member]
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
;; R12 : H5aParser *parser
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

    iterate member, name,value
      mov rcx, r14
      shl rcx, (bsr sizeof.Attribute)
      mov rdx, qword [rbx + H5aVector.data]
      lea rdi, [rdx + rcx + Attribute.#member]
      call _h5aStringClear
    end iterate

    inc r14
    jmp .loop
.after_loop:
  end with_saved_regs
  ret
end func


func _h5aAttrVectorPushSlot, public
;; R12 : H5aParser *parser
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
      ;dec r14 ;why this line??

.loop:
      cmp r14, r13
      jae .after_loop

      iterate member, name,value
        mov rcx, r14
        shl rcx, (bsr sizeof.Attribute)
        mov rdx, qword [rbx + H5aVector.data]
        lea rdi, [rdx + rcx + Attribute.#member]
        call _h5aStringCreate
      end iterate

      inc r14
      jmp .loop

.after_loop:
    end with_saved_regs

.finish:
    xor rcx,rcx
    add dword [rbx + H5aVector.size], sizeof.Attribute
    mov ecx, dword [rbx + H5aVector.size]
    mov rdx, qword [rbx + H5aVector.data]
    lea rax, [rdx + rcx]
  end with_saved_regs
  ret
end func


;;;
;;; H5aVector<H5aAttributeView>
;;;

func _h5aAttrViewVectorCreate, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aAttributeView> *vector
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, rbx
    xor rsi,rsi
    mov si, (16 * sizeof.H5aAttributeView)
    call _h5aVectorCreate
  end with_saved_regs
  ret
end func


func _h5aAttrViewVectorDestroy, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aAttributeView> *vector
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov rdi, rbx
    call _h5aVectorDestroy
  end with_saved_regs
  ret
end func


func _h5aAttrViewVectorClear, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aAttributeView> *vector
;; -> void
  with_saved_regs rbx
    mov rbx, rdi

    mov ecx, dword [rbx + H5aVector.size]
    shl ecx, (bsr sizeof.H5aAttributeView)
    zero_init qword [rbx + H5aVector.data], ecx
  end with_saved_regs
  ret
end func


func _h5aAttrViewVectorGenerate, public
;; R12 : H5aParser *parser
;; RDI : H5aVector<H5aAttributeView> *vector
;; RSI : H5aVector<H5aAttribute> *source
;; -> void
  with_saved_regs rbx, r13, r14
    mov rbx, rdi ;vector
    mov r13, rsi ;source
    xor r14,r14
    mov r14d, dword [r13 + H5aVector.size] ;source_size
    shr r14, (bsr sizeof.Attribute)

    mov rdi, rbx
    xor rsi,rsi
    mov esi, dword [r13 + H5aVector.size] ;source_size
    call _h5aVectorMaybeGrow

    mov rcx, r14
    jrcxz .after_loop
    mov rdx, qword [rbx + H5aVector.data] ;vector_data
    mov r8,  qword [rbx + H5aVector.data] ;source_data
.loop:
    mov rax, r14
    sub rax, rcx ;get index
    mov r9, rax
    shl rax, (bsr sizeof.H5aAttributeView) ;vector_offset
    shl r9,  (bsr sizeof.Attribute) ;source_offset

    iterate member, name,value
      mov r10, qword [r8 + r9 + Attribute.#member + H5aString.data]
      mov qword [rdx + rax + H5aAttributeView.#member + H5aStringView.data], r10
      xor r11,r11
      mov r11d, dword [r8 + r9 + Attribute.#member + H5aString.size]
      mov qword [rdx + rax + H5aAttributeView.#member + H5aStringView.size], r11
    end iterate

    loop .loop
.after_loop:
  end with_saved_regs
  ret
end func

