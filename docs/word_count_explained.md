# Word Count (ASM) — How it works

This module reads up to 64 KiB of text from stdin, then supports two modes:

- [1] Total words: counts sequences of non-whitespace characters.
- [2] Specific word count: counts case-insensitive occurrences of a given word.

## Flow overview

1. Banner and prompt for input text (Ctrl+D to finish).
2. Read text in a loop until EOF or buffer full, storing length in `wc_len`.
3. Prompt for mode and read one character.
4. If mode is '1':
   - Iterate through the buffer, tracking an `in_word` flag.
   - A word starts when a non-whitespace char appears after whitespace.
   - Whitespace includes: space, tab (9), newline (10), carriage return (13), vertical tab (11), form feed (12).
   - Increment the total when entering a word; print "Total words: N".
5. Otherwise (mode '2'):
   - Prompt for the target word; read up to 255 bytes and strip a trailing newline.
   - For each position `i` in the text where the remaining length fits the word length, compare `wc_text[i..]` to `wc_word` case-insensitively via `wc_eq_ci_len`.
   - On match, increment count and advance `i` by the word length (non-overlapping matches). Print "Occurrences: N".

## Helpers

- `wc_eq_ci_len(rdi=ptrA, rsi=ptrB, rcx=len) -> rax=1/0`:
  - Compares two byte sequences case-insensitively (ASCII A..Z normalized to a..z) for exactly `len` bytes; returns 1 if equal, else 0.
- `wc_u64_to_dec(rdi=value, rsi=buf) -> rax=len`:
  - Writes the decimal ASCII representation of an unsigned 64-bit integer into `buf`, returns the number of digits.

## Edge cases and notes

- Empty input yields 0 words and 0 occurrences.
- The specific word mode treats an empty word as zero-length; the code guards by short-circuiting if `wc_wlen == 0`.
- Counting of words is strictly ASCII whitespace-based; it doesn't handle Unicode categories.
- Case-insensitivity is ASCII-only (A..Z mapped to a..z).
- The search is non-overlapping: after a match, the index advances by the word length.

## Usage

- From the menu, choose `Word Count`.
- For total words, enter `1` at the mode prompt.
- For specific word count, enter `2`, then type the word and press Enter.
