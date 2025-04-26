## fasmg
The source code makes extensive use of fasmg's macroprogramming facilities.
For those not familiar with fasmg, here is a quick introduction:

### Custom syntax
A more complex use of macros consists in implementing domain-specific languages (DSLs),
which can save a lot of time.

```asm
state data,DATA_STATE
 
   [[U+0026 AMPERSAND]]
     mov byte [r12 + H5aParser.tokenizer.return_state], DATA_STATE
     mov byte [r12 + H5aParser.tokenizer.state], CHARACTER_REFERENCE_STATE
     xor al,al
     ret
 
   [[U+003C LESS-THAN SIGN]]
     mov byte [r12 + H5aParser.tokenizer.state], TAG_OPEN_STATE
     xor al,al
     ret
     
   [[U+0000 NULL]]
     ; XXX: error
     xor al,al
     ret
 
   [[EOF]]
     xor al,al
     ret
     
   [[Anything else]]
     xor al,al
     ret
     
end state
```

In short, the `state` macro sets up a new line-processing function
that recognizes special statements like the match patterns and does
some special assembly to make it work as we want. The details of
the implementation may vary during development and will not be
described here. To gain a better understanding of the modus operandi
of these syntax-changing macros, I highly recommend you first
check out **Common Lisp Macros**, which are much better documented
than the fasmg macro language. Once you feel comfortable with the
concepts involved, you may read the source (e.g. "src/tokenizer\_states.g").


### Wrappers
On the same train of thought, consider more intuitive uses of macros:
```asm
with_saved_regs rdi, rsi, rdx, rcx
  ; RCX for stack alignment
  mov rdi, rsi
  call _h5aTokenizerPrefetchChars
end with_saved_regs
```

Which might expand to:
```asm
  push rdi
  push rsi
  push rdx
  push rcx
  ; RCX for stack alignment
  mov rdi, rsi
  call _h5aTokenizerPrefetchChars
  pop rcx
  pop rdx
  pop rsi
  pop rdi
```

Or:
```asm
  mov al byte [r12 + H5aParser.tokenizer.saw_eof]
  test al,al
  likely jz .inputLeft
```
..which becomes:
```asm
  mov al byte [r12 + H5aParser.tokenizer.saw_eof]
  test al,al
  db 0x3E ; branch taken prefix
  jz .inputLeft
```

## Named character references
The file "ext/entities.json" is _not_ a copy of
[the official JSON file](https://html.spec.whatwg.org/entities.json). It includes some
manually edited changes to make it work properly with the entity matcher.

Here's what was done:
```json
"&AElig": { "codepoints": [198], "characters": "\u00C6" },
"&AElig;": { "codepoints": [198], "characters": "\u00C6" },
// ...
```

This common pattern, intended for badly types character references, is reordered
to:

```json
"&AElig;": { "codepoints": [198], "characters": "\u00C6" },
"&AElig": { "codepoints": [198], "characters": "\u00C6" },
// ...
```

More verbosely:
```
"&not": { "codepoints": [172], "characters": "\u00AC" },
"&not;": { "codepoints": [172], "characters": "\u00AC" },
"&notin;": { "codepoints": [8713], "characters": "\u2209" },
"&notinE;": { "codepoints": [8953, 824], "characters": "\u22F9\u0338" },
"&notindot;": { "codepoints": [8949, 824], "characters": "\u22F5\u0338" },
"&notinva;": { "codepoints": [8713], "characters": "\u2209" },
"&notinvb;": { "codepoints": [8951], "characters": "\u22F7" },
"&notinvc;": { "codepoints": [8950], "characters": "\u22F6" },
"&notni;": { "codepoints": [8716], "characters": "\u220C" },
"&notniva;": { "codepoints": [8716], "characters": "\u220C" },
"&notnivb;": { "codepoints": [8958], "characters": "\u22FE" },
"&notnivc;": { "codepoints": [8957], "characters": "\u22FD" },
```

Becomes:

```
"&not;": { "codepoints": [172], "characters": "\u00AC" },
"&notin;": { "codepoints": [8713], "characters": "\u2209" },
"&notinE;": { "codepoints": [8953, 824], "characters": "\u22F9\u0338" },
"&notindot;": { "codepoints": [8949, 824], "characters": "\u22F5\u0338" },
"&notinva;": { "codepoints": [8713], "characters": "\u2209" },
"&notinvb;": { "codepoints": [8951], "characters": "\u22F7" },
"&notinvc;": { "codepoints": [8950], "characters": "\u22F6" },
"&notni;": { "codepoints": [8716], "characters": "\u220C" },
"&notniva;": { "codepoints": [8716], "characters": "\u220C" },
"&notnivb;": { "codepoints": [8958], "characters": "\u22FE" },
"&notnivc;": { "codepoints": [8957], "characters": "\u22FD" },
"&not": { "codepoints": [172], "characters": "\u00AC" },
```

Notice how "&not" has dropped to the bottom of this sub-list. This prevents e.g. "&notinva;"
from being consumed as "&not" followed by "inva;" characters.

