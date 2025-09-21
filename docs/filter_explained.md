# Character Filter (NASM) — Quick Guide

Filters an input text stream based on the chosen mode and prints the result:

- 1: digits only (0–9)
- 2: letters only (A–Z, a–z)
- 3: punctuation only (printable ASCII excluding letters, digits, and space)
- 4: passthrough except remove any characters you list (typed after prompt)

## Flow

1. Show banner and prompt for text; read up to 64 KiB until EOF (Ctrl+D).
2. Show mode menu; read one character ('1'..'4').
3. If mode '4', prompt for a removal set line and strip trailing newline.
4. Emit header and stream through the input, applying the selected predicate per byte.

## Selection Logic

- Mode 1: `byte in ['0'..'9']`
- Mode 2: `byte in ['A'..'Z'] or ['a'..'z']`
- Mode 3: `byte is printable (32..126) and not a letter, digit, or space`
- Mode 4: `byte not in removal_set` (removal set is the literal chars typed)

## Buffers

- `ft_text` (64 KiB): input storage (also reused as 1-byte temp for output)
- `ft_rmset` (256 B): removal set typed by user (mode 4)

## Syscalls

- `read (rax=0)` from stdin
- `write (rax=1)` to stdout

## Notes

- Input beyond 64 KiB is truncated.
- Mode 3 treats only ASCII as printable and excludes space; tabs and newlines are dropped.
- Mode 4 does a linear scan for membership; for small sets (<=255) this is fine.
