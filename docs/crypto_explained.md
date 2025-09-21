# Crypto Tools (Caesar / XOR) — Concise Explanation

This document explains the `crypto.asm` module that provides two simple text transformations: Caesar shift for alphabetic characters and XOR on raw bytes. The doc is compact and structured similarly to the password checker explainer.

## High-Level Flow

1. Print banner and prompt for input text.
2. Read up to 64 KiB from stdin until EOF (Ctrl+D).
3. Ask for mode: `[1] Caesar` or `[2] XOR`.
4. If Caesar:
   - Prompt for shift (signed integer, intended range -25..25).
   - Transform only letters (preserving case) using modular arithmetic over 26.
5. If XOR:
   - Prompt for key (0..255).
   - XOR every byte of the input with the key.
6. Print transformed output immediately, one byte at a time.
7. Return to caller.

## Data and Buffers

- UI: banner lines, prompts for text, mode, Caesar shift, XOR key, and output header.
- `cr_text` (64 KiB): input text buffer, reused to output one byte at a time.
- `cr_len` (qword): total number of bytes read into `cr_text`.
- `cr_in` (16 bytes): small scratch buffer to read mode, shift, or key.

## Syscalls Used

- `read(0, buf, len)` — read input text, shift/key, and mode.
- `write(1, buf, len)` — print banner, prompts, header, and output bytes.

## Main Routine: `crypto_main`

- Prologue: preserves `rbp`, `rbx`, and `r12`.
- Banner: prints three banner lines.
- Read text:
  - Prompts the user, then loops reading into `cr_text` until EOF or buffer full.
  - Stores byte count in `cr_len`.
- Mode prompt and read:
  - If the first char is `'2'` → XOR mode; otherwise default to Caesar.

### Caesar Mode

- Prompt for shift and parse a small signed integer:
  - Optional leading `'-'` sets a sign flag, then decimal digits are accumulated.
  - The value in `eax` becomes the shift; negative values are supported.
- Output header "Result:".
- Loop over each byte in `cr_text`:
  - If `A..Z`: compute `(c - 'A' + shift) mod 26`, then `+'A'`.
  - Else if `a..z`: compute `(c - 'a' + shift) mod 26`, then `+'a'`.
  - Else (non-letter): output unchanged.
  - Each output byte is written immediately to stdout by putting it at `cr_text[0]` and writing length 1.
- Note: The modulo is implemented with `idiv 26`, using the remainder in `edx`; if negative, `+26` fixes it into `[0..25]`.

### XOR Mode

- Prompt for key and parse an unsigned decimal number:
  - Accumulates digits into `eax`, then masks with `0xFF` to keep a byte.
  - Uses `r12b` as the key byte.
- Output header "Result:".
- Loop over each byte in `cr_text`:
  - `dl = cr_text[i] ^ key`.
  - Write the single output byte by placing it at `cr_text[0]` and writing 1 byte.

## Parsing Notes

- Mode read: reads up to 4 bytes (e.g., `"1\n"`); only the first char is used.
- Shift read: reads up to 8 bytes; parses optional `'-'` then digits until a non-digit.
- Key read: reads up to 8 bytes; parses digits until a non-digit; final key is `value & 0xFF`.

## Output Strategy

- For both modes, output is streamed: each transformed byte is written immediately to stdout.
- Implementation detail: it writes via a 1-byte buffer at `cr_text[0]` to avoid allocating another buffer.

## Edge Cases and Behavior

- Reading stops at EOF (Ctrl+D) or when `cr_text` is full.
- Caesar shift beyond `[-25..25]` still works due to modulo arithmetic.
- XOR mode transforms all bytes, including non-ASCII.
- Caesar mode only transforms letters; punctuation, digits, and whitespace pass through unchanged.

## Build

```bash
nasm -f elf64 crypto.asm -o crypto.o
```

Link it with your driver (e.g., `util.asm`) as needed.
