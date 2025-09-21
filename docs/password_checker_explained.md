# Password Strength Checker (NASM, Linux) — Concise Explanation

This document provides a compact, step-by-step explanation of `password_checker.asm`, focusing on how it reads input, evaluates strength, and prints results. It’s intentionally brief (well under 500 lines) and organized by sections and subroutines.

## High-Level Flow

1. Print banner and prompt.
2. Disable terminal echo and canonical mode via `stty` (so input is hidden and read byte-by-byte).
3. Read password, masking each character with `*`, handling backspace, stopping at Enter.
4. Restore terminal settings.
5. Analyze password to compute a score and set flags (categories, spaces, blacklist).
6. Print a colored rating and a 10-block strength bar.
7. Show suggestions if needed; otherwise print “Looks good! 🎉”.
8. Print a closing message and return to the caller.

## Key Data and Flags

- ANSI color/style sequences for UI (bold, colors, reset).
- Banner strings, prompt, “Analyzing…” line, rating labels, progress bar glyphs, and suggestion strings.
- Blacklist: `password`, `123456`, `qwerty`, `letmein`, `admin` (case-insensitive exact match).
- `specials`: Set of symbols used to detect special characters.
- BSS:
  - `pw_buf` (256 bytes): input buffer
  - `pw_len` (qword): password length
  - `status` (dword): child process status for `wait4`
  - Flags (bytes): `flag_upper`, `flag_lower`, `flag_digit`, `flag_special`, `flag_space`, `flag_black`

## System Calls Used

- `read` (0) — read from stdin
- `write` (1) — write to stdout
- `fork` (57) — create process for `stty`
- `execve` (59) — run `/bin/stty`
- `wait4` (61) — wait for child
- `exit` (60) — child exits with code if `execve` fails

## Main Routine: `password_checker_main`

- Prologue: Saves callee-saved registers; sets up frame.
- Prints: `banner_top`, `banner_mid`, `banner_bot`, then `prompt_text` via `sys_write`.
- Terminal off: Calls `run_stty(argv_off)` where `argv_off = ["stty","-echo","-icanon","min","1","time","0",NULL]`.
- Reads password: Calls `read_password` to capture hidden input with `*` masking and backspace support.
- Terminal on: Calls `run_stty(argv_on)` where `argv_on = ["stty","echo","icanon",NULL]`.
- Prints “Analyzing password…” (cosmetic separation).
- Analyze: Calls `analyze_password`; stores `score` (0..5) in `r12`.
- Rating label: Prints “Strength: ” then an appropriate label by score:
  - 0 → Very Weak (red)
  - 1 → Weak (yellow)
  - 2 → Medium (blue)
  - 3 → Strong (green)
  - 4..5 → Very Strong (bold green)
- Progress bar:
  - Prints `[`.
  - Chooses color by score: `<=1 red`, `2 yellow`, `3 blue`, `>=4 green`.
  - Filled blocks = `score * 2` using `█` (UTF-8), total blocks = 10.
  - Remaining blocks printed as `░` in gray.
  - Resets color; prints `]\n`.
- Suggestions vs OK:
  - Collects flags and checks `pw_len < 12`.
  - If any issue → Prints “Suggestions:” header + relevant bullets:
    - Length < 12 → Use at least 12 characters.
    - Missing uppercase → Add uppercase letters (A-Z).
    - Missing lowercase → Add lowercase letters (a-z).
    - Missing digit → Add digits (0-9).
    - Missing special → Add special characters (!@#$...).
    - Contains space → Avoid spaces.
    - Blacklisted → Avoid common or leaked passwords.
  - Else → Prints green “Looks good! 🎉”.
- Prints a thank-you message and returns (does not exit the process).

## Subroutine: `run_stty`

Purpose: Change TTY mode using the external `/bin/stty` tool.

- Input: `rdi = argv_ptr` (argv array to pass to `execve`).
- Process:
  1. `fork` to spawn a child.
  2. Parent: `wait4(child, &status, 0, NULL)`, then return.
  3. Child: `execve("/bin/stty", argv, envp_null)`.
     - On failure: `exit(127)`.
- Notes: Using `stty` avoids dealing with `ioctl` directly from assembly.

## Subroutine: `read_password`

Purpose: Read one character at a time, mask with `*`, support backspace, stop on Enter.

- Setup: `rbx = 0` (length). Buffer is `pw_buf`.
- Loop per byte:
  - `read(0, pw_buf+rbx, 1)`.
  - If not exactly 1 → finish (EOF or error).
  - If `\n` or `\r` → done; print newline.
  - If backspace (8) or DEL (127): if `rbx>0`, decrement `rbx` and print `"\b \b"` to erase last `*`.
  - Else (normal char): if `rbx<255`, increment `rbx` and print `*`.
- Finish: NUL-terminate at `pw_buf+rbx`, store `pw_len = rbx`, return `rax = rbx`.

## Subroutine: `analyze_password`

Purpose: Compute strength flags and score, check blacklist.

- Reset flags to 0.
- Iterate over `pw_buf` for `pw_len` characters:
  - If space `' '` → `flag_space = 1`.
  - If in `A..Z` → `flag_upper = 1`.
  - Else if in `a..z` → `flag_lower = 1`.
  - Else if in `0..9` → `flag_digit = 1`.
  - Else if in `specials` array → `flag_special = 1`.
- Score: `score = flag_upper + flag_lower + flag_digit + flag_special` (0..4).
  - If `pw_len >= 12` → `score++` (max 5).
- Blacklist (case-insensitive exact match): call `eq_case_ins` for each blacklisted word.
  - If any match → `flag_black = 1` and `score = 0`.
- Return: `rax = score`.

## Subroutine: `eq_case_ins`

Purpose: Compare two strings for equality ignoring case.

- Inputs: `rdi=pw_ptr`, `rsi=pw_len`, `rdx=str_ptr`, `rcx=str_len`.
- Steps:
  - If lengths differ → return 0.
  - For `i` in `[0, len)`: lower-case both chars (if `A..Z`) and compare; mismatch → 0.
  - All matched → 1.

## Scoring Summary

- Categories: uppercase, lowercase, digit, special → up to 4 points.
- Length bonus: `+1` if length ≥ 12.
- Blacklist override: exact (case-insensitive) match forces score to 0.

## Suggestions Mapping

- `pw_len < 12` → Use at least 12 characters.
- `!flag_upper` → Add uppercase letters (A-Z).
- `!flag_lower` → Add lowercase letters (a-z).
- `!flag_digit` → Add digits (0-9).
- `!flag_special` → Add special characters (!@#$...).
- `flag_space` → Avoid spaces.
- `flag_black` → Avoid common or leaked passwords.

## Notes and Edge Cases

- Empty input → score 0, multiple suggestions.
- Only a space character (0x20) is flagged as space; tabs and other whitespace are treated as non-space (but may be counted as special if present in `specials`).
- Unicode beyond ASCII is treated byte-wise; special detection only scans provided `specials` bytes.
- The progress bar uses UTF-8 block symbols; display requires a UTF-8-capable terminal.
- The routine returns to caller (no `exit`); suitable for integration into a larger program.

## Build and Link

- Assemble:

  ```bash
  nasm -f elf64 password_checker.asm -o password_checker.o
  ```

- Link with your `util.asm` (example):

  ```bash
  nasm -f elf64 util.asm -o util.o
  ld -o pwcheck util.o password_checker.o
  ```
