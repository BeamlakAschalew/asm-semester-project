# Diff Tool (NASM) — Quick Guide

Compares two input texts (A and B) byte-by-byte by position and prints two labeled lines:

- A: bytes from the first input, with mismatching positions highlighted in red (deletions from A)
- B: bytes from the second input, with mismatching positions highlighted in green (additions in B)

## Flow

1. Banner, prompt+read A (up to 64 KiB), then prompt+read B.
2. Print `A:` and stream A's bytes; at each index `i` compare to B's `i`:
   - If equal: print plain byte.
   - If different or B has no byte at `i`: turn on red highlight, print A's byte, then reset.
3. Print `B:` and stream B similarly, using green highlight where `B[i]` differs from `A[i]` or `A` ran out.

## Notes

- This is a simple positional diff; it does not compute LCS or move detection.
- Non-printable bytes are emitted verbatim; the terminal may render them oddly.
