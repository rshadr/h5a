;;;;
;;;; Copyright 2025 rshadr
;;;; See LICENSE for details
;;;;

format ELF64

include 'macro/struct.inc'
include "util.inc"
include "local.inc"

public _h5aTreeBuilderAcceptToken

section '.text' executable

_h5aTreeBuilderAcceptToken:
  ;; R12 (s) : H5aParser *
  ;; RDI (a) : u64 ?
  ;; -> void
  ret

