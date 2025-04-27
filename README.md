# libh5a - HTML parser library

## Introduction
*libh5a* is a HTML parser library written in x64 assembly language.
It uses fasm2/fasmg as its assembler backend, thus also making heavy
use of macroprogramming. It was conceived with a recreational and
educational intent; being written in assembly, it _does not claim to be fast_,
nor incredibly optimized in any way. It is rather a testing ground
for things I have wanted to try for a long time and also my first
(hopefully) complete assembly project.

## Requirements
- fasm2
- libc
- AVX2

## Status
- Tokenizer: partially implemented
- Tree builder: not working
Hence, **not usable yet!!!**

## Caveats
- No debug symbols
