include 'macro/struct.inc'
include "util.inc"
include "local.inc"


format ELF64

extrn _k_h5a_TreeBuilder_handlerTable

public _h5aTreeBuilderAcceptToken


section '.text' executable

_h5aTreeBuilderAcceptToken:
  ;; R12 (s): H5aParser *parser
  ;; RDI (SIL): e8 type
  ;; RSI: union token
  ;; -> void
  with_saved_regs rbx, r13, r14
    lea rbx, [_k_h5a_TreeBuilder_handlerTable]
    mov r13, rdi ;type
    mov r14, rsi ;token

.loop:
    xor rax,rax
    xor rcx,rcx
    mov rdi, r13
    mov rsi, r14
    mov cl, byte [r12 + H5aParser.treebuilder.mode]
    call qword [rbx + rcx * 8]

    test al, RESULT_BIT_AGAIN
    jnz .loop
    ; XXX: what about stopping/leaving?

.finish:
  end with_saved_regs
  ret
