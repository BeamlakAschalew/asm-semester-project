# Text Search Highlighter (NASM) — Quick Guide

This module reads free-form text from stdin, asks for a keyword, and writes the text back to stdout with each case-insensitive keyword occurrence highlighted (black on yellow). It also prints a summary of total matches.

## Flow

1. Banner and prompts using ANSI escape codes.
2. Read text into `ts_text_buf` (up to 64 KiB) until EOF (Ctrl+D).
3. Read keyword line into `ts_kw_buf` (max 255 bytes) and strip trailing `\n`.
4. If keyword is empty, warn and return.
5. Stream the text to stdout while scanning:
   - If remaining text is shorter than keyword, flush the rest.
   - At each position, compare `kwlen` bytes, case-insensitive.
   - On match: emit highlight-on sequence, the keyword itself, and reset; skip ahead by keyword length and increment match counter.
   - On miss: write one byte and advance by 1.
6. Print a summary line: "Matches found: N".

## Key Routines

- `text_search_main`: Orchestrates I/O, scanning, and rendering.
- `ts_eq_ci_len(rdi, rsi, rcx) -> rax`:
  - Compares two byte spans of length `rcx` case-insensitively.
  - Returns `1` if equal, `0` otherwise.
- `ts_u64_to_dec(rdi=value, rsi=buf) -> rax=len`:
  - Converts an unsigned 64-bit integer to ASCII decimal at `buf` and returns the number of digits.

## Buffers

- `ts_text_buf` (64 KiB): input text
- `ts_kw_buf` (256 B): keyword
- `ts_num_buf` (32 B): temporary for decimal conversion

## System calls

- `read (rax=0)`: stdin
- `write (rax=1)`: stdout

## Notes and Edge Cases

- Case-insensitive matching only affects ASCII A–Z; other bytes are matched verbatim.
- Overlapping matches naturally step by `kwlen` after a hit, so overlaps are not double-counted (e.g., searching `aaa` in `aaaa` finds 1 at pos 0).
- If keyword is longer than the entire input, the module simply echoes the text.
- Binary data passes through unchanged; highlight sequences only emit on ASCII text matches.
