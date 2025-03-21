;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;


;;
;; Internal code bits (insertion modes / tokenizer states)
;; The least significant bit is for style only.
;;
;RESULT_BIT_AGAIN    equ 1 shl 1
RESULT_BIT_AGAIN    constequ 1 shl 1
RESULT_BIT_LEAVE    equ 1 shl 2
RESULT_BIT_CLEANUP  equ 1 shl 3

RESULT_OK           equ 0x0
RESULT_IGNORE       equ 0x0 + 0x1

RESULT_RECONSUME    equ RESULT_BIT_AGAIN + 0x0
RESULT_REPROCESS    equ RESULT_BIT_AGAIN + 0x1

RESULT_EOF_REACHED  equ (RESULT_BIT_CLEANUP or RESULT_BIT_LEAVE) + 0x0
RESULT_STOP         equ (RESULT_BIT_CLEANUP or RESULT_BIT_LEAVE) + 0x1


;;
;; Tokenizer state flags
;;
STATE_BIT_SPC_ACTION equ 1 shl 0
STATE_BIT_NO_GETCHAR equ 1 shl 1

enum
  TOKEN_CHARACTER
  TOKEN_WHITESPACE
  TOKEN_DOCTYPE
  TOKEN_START_TAG
  TOKEN_END_TAG
  TOKEN_COMMENT
  TOKEN_EOF
end enum

enum
  DATA_STATE = 0
  TAG_OPEN_STATE
  MARKUP_DECLARATION_OPEN_STATE
  NUM_STATES
end enum

;; XXX: move to public incfile?
struct H5aParserCreateInfo
  get_char dq ?
  user_data dq ?
ends

enum
  H5A_SUCCESS = 0
  H5A_FAILURE = 1
  H5A_PAUSED  = 2
end enum


struct H5aParser
  input_stream.get_char_cb dq ?
  input_stream.user_data dq ?

  ;; Qwords for speed
  tokenizer.state dq ?
  tokenizer.return_state dq ?
  treebuilder.mode dq ?
  treebuilder.original_mode dq ?

  tokenizer.char_ref dq ?

ends
