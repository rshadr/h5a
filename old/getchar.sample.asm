_h5aTokenizerGetChar:
;; R12 (omni): H5aParser *
;; -> EAX: char32

  ;; test (pending_characters.size == 0 && newline_count == 0 )
  mov eax, dword [r12 + H5aParser.tokenizer.input_buffer + 0]
  test eax,eax
  setnz dil
  mov ecx, dword [r12 + H5aParser.tokenizer.newline_count]
  test ecx,ecx
  setnz sil
  add sil, dil
  test sil,sil
  jz .yesPendingGeneric
.noPendingGeneric:
  push r13
  push r14
  xor r13,r13 ;got_line_end = false
  xor r14,r14 ;saw_cr = false

.noPendingGenericLoop:
  ;; -> EAX: char32
  mov  rdi, qword [r12 + H5aParser.input_stream.user_data]
  call qword [r12 + H5aParser.input_stream.get_char_cb]
  
  ;; got_line_end = (c == '\n' || c == '\r')
  cmp eax, '\n'
  sete dil
  cmp eax, '\r'
  sete sil
  and dil, sil
  mov r13b, dil

  ;; newline_count += (saw_cr && got_line_end)
  ;; [[DIL := saw_cr]]
  and dil, r14b
  movzx edi, dil
  sub dword [r12 + H5aParser.tokenizer.newline_count], edi

  cmp eax, '\r'
  sete r14b

  test r13b,r13b
  jz .noPendingGenericAfter

  jmp .noPendingGenericLoop

.noPendingGenericAfter:
  ; XXX: push back
  pop r14
  pop r13

.yesPendingGeneric:
  mov eax, dword [r12 + H5aParser.tokenizer.newline_count]
  test eax,eax ;unsigned not-zero test
  jz .noPendingNewlines

  dec dword [r12 + H5aParser.tokenizer.newline_count]

.noPendingNewlines:
  ; XXX: pop
  xor rax,rax
  ret
