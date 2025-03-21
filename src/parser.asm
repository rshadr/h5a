format ELF64

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

extrn _h5aTokenizerMain

public h5aCreateParser
public h5aDestroyParser
public h5aResumeParser
public k_h5a_parserSize


section '.text' executable

h5aCreateParser:
;; RDI: H5aParserCreateInfo *create_info
;; RSI: H5aParser *parser
  push rdi
  push rsi

  mov rdi, rsi
  xor al,al
  mov rcx, sizeof.H5aParser
  rep stosb

  pop rsi
  pop rdi

  mov rax, qword [rdi + H5aParserCreateInfo.get_char]
  mov qword [rsi + H5aParser.input_stream.get_char_cb], rax
  mov rax, qword [rdi + H5aParserCreateInfo.user_data]
  mov qword [rsi + H5aParser.input_stream.user_data], rax

  ;mov qword [rsi + H5aParser.tokenizer.state], DATA_STATE
  ;mov qword [rsi + H5aParser.treebuilder.mode], 0

  mov eax, H5A_SUCCESS
  ret

h5aDestroyParser:
;; RDI: H5aParser *parser
  mov eax, H5A_SUCCESS
  ret

h5aResumeParser:
;; RDI: H5aParser *parser
;; -> [see _h5a_Tokenizer_main]
  push r12
  mov  r12, rdi
  lea rax, [_h5aTokenizerMain]
  jmp rax

section '.rodata'

k_h5a_parserSize:
  dq sizeof.H5aParser
