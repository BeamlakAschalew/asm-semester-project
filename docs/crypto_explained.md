# Caesar Cipher — Concise Explanation

This document explains the `crypto.asm` module after simplifying it to a single transformation: a Caesar shift over alphabetic characters (ASCII letters), preserving case.

## High-Level Flow

1. Print banner and prompt for input text.
2. Read up to 64 KiB from stdin until EOF (Ctrl+D).
3. Prompt for shift (signed integer, typical range -25..25).
4. Transform only letters using modular arithmetic over 26, preserving case.
5. Stream transformed bytes to stdout and return to caller.

## Data and Buffers

- UI: banner lines, prompts for text, shift, and an output header.
- `cr_text` (64 KiB): input text buffer, reused to output one byte at a time.
- `cr_len` (qword): total number of bytes read into `cr_text`.
- `cr_in` (16 bytes): small scratch buffer to read the shift.

## Syscalls Used

- `read(0, buf, len)` — read input text and shift.
- `write(1, buf, len)` — print banner, prompts, header, and output bytes.

## Main Routine: `crypto_main`

- Banner and input read loop store the input in `cr_text` and byte count in `cr_len`.
- Shift prompt and parse:
  - Optional leading `'-'` sets a sign flag, then decimal digits are accumulated in `eax`.
  - Negative values are supported; the math uses signed division to produce a proper modulo.
- Output header "Result:" then process each byte:
  - If `A..Z`: `(c - 'A' + shift) mod 26 + 'A'`.
  - Else if `a..z`: `(c - 'a' + shift) mod 26 + 'a'`.
  - Else: byte is emitted unchanged.
- Each output byte is written by storing it at `cr_text[0]` and writing length 1.

## Parsing Notes

- Shift read: up to 8 bytes; parses optional `'-'` then digits until a non-digit.
- The modulo is implemented via `idiv 26`; remainder `edx` is adjusted into `[0..25]` when negative.

## Output Strategy

- Streaming output keeps memory usage low and avoids an extra buffer.

## Edge Cases and Behavior

- Reading stops at EOF (Ctrl+D) or when `cr_text` is full.
- Shifts outside `[-25..25]` still produce correct results due to modulo arithmetic.
- Only ASCII letters are transformed; punctuation, digits, and whitespace pass through unchanged.

## Build

```bash
nasm -f elf64 crypto.asm -o crypto.o
```

Link it with your driver (e.g., `util.asm`) as needed.
