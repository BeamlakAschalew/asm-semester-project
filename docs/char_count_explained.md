# Character Count (NASM) — Quick Guide

Counts characters in the input text. Two modes:

- 1: Count occurrences of a specific character you enter
- 2: Count all characters (frequency table), then print counts for printable ASCII (32..126)

## Flow

1. Banner, prompt for text; read up to 64 KiB until EOF (Ctrl+D).
2. Prompt for mode ('1' or anything else for mode 2).
3. Mode 1: Ask for the character, scan the text, and print "Count: N".
4. Mode 2: Zero a 256-entry frequency table, scan the text incrementing counts, and print each printable char with its count.

## Data

- `cc_counts[256]`: dword frequency table indexed by byte value
- `cc_num[32]`: buffer to render decimal integers

## Helper

- `cc_u64_to_dec(value, buf) -> len`: converts an unsigned value to ASCII decimal into `buf`, returns digit count.

## Syscalls

- `read` from stdin, `write` to stdout

## Notes

- Only printable ASCII rows (32..126) are displayed in mode 2; others are counted but not printed.
- Newlines and binary bytes are included in counting but not printed in the summary table.
