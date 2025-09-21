# Replace Substring (NASM) — Quick Guide

Reads input text, a target substring, and a replacement. Streams the text to stdout, replacing each target occurrence with the replacement, highlighted in green.

## Flow

1. Banner, prompt for input text; read until EOF (Ctrl+D).
2. Prompt for target and replacement lines; strip trailing newlines.
3. If target is empty, warn and return.
4. Output header; scan the text:
   - If remaining text is shorter than target, flush the rest.
   - Compare at each position for exact match.
   - On match: write highlight-on, the replacement, reset; advance by target length.
   - On miss: write the current byte and advance by 1.

## Helper

- `rp_eq_len(ptr1, ptr2, len) -> 1/0`: exact byte-wise comparison for `len` bytes.

## Notes

- Overlaps are naturally skipped due to advancing by target length after a match.
- Replacement is not recursive; newly emitted bytes are not re-scanned.
