; Password Strength Checker - NASM x86_64 Linux (module)
; Exposes: password_checker_main (no exit; returns to caller)
; Build (with util.asm):
;   nasm -f elf64 password_checker.asm -o password_checker.o
;   nasm -f elf64 util.asm -o util.o
;   ld -o pwcheck util.o password_checker.o

BITS 64                                   ; Assemble for 64-bit mode

SECTION .data                             ; Read-only and initialized data
; ANSI colors and styles
esc:        db 0x1B                        ; ASCII ESC character
reset:      db 0x1B, '[0m'                 ; ANSI reset sequence
len_reset   equ $-reset                    ; Length of reset sequence
bold:       db 0x1B, '[1m'                 ; ANSI bold sequence
len_bold    equ $-bold                     ; Length of bold sequence

fg_red:     db 0x1B, '[31m'                ; ANSI set foreground red
len_fg_red  equ $-fg_red                   ; Length of red sequence
fg_yellow:  db 0x1B, '[33m'                ; ANSI yellow
len_fg_yellow equ $-fg_yellow              ; Length of yellow sequence
fg_green:   db 0x1B, '[32m'                ; ANSI green
len_fg_green equ $-fg_green                ; Length of green sequence
fg_blue:    db 0x1B, '[34m'                ; ANSI blue
len_fg_blue equ $-fg_blue                  ; Length of blue sequence
fg_cyan:    db 0x1B, '[36m'                ; ANSI cyan
len_fg_cyan equ $-fg_cyan                  ; Length of cyan sequence
fg_magenta: db 0x1B, '[35m'                ; ANSI magenta
len_fg_magenta equ $-fg_magenta            ; Length of magenta sequence
fg_gray:    db 0x1B, '[90m'                ; ANSI bright gray
len_fg_gray equ $-fg_gray                  ; Length of gray sequence

nl:         db 10                          ; Newline '\n'
len_nl      equ $-nl                       ; Length of newline
space:      db ' '                         ; Single space
len_space   equ $-space                    ; Length of space
star:       db '*'                         ; Asterisk used for password masking
len_star    equ $-star                     ; Length of star
back_erase: db 8,' ',8   ; "\b \b"      ; Backspace-erase sequence
len_back_erase equ $-back_erase            ; Length of back_erase

; Banner
banner_top:    db 0x1B,'[36m', '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓', 10 ; Cyan top border
len_banner_top equ $-banner_top                                                             ; Length of top banner
banner_mid:    db 0x1B,'[1m', 0x1B,'[36m', '┃   Password Strength Checker (NASM, Linux)    ┃', 10 ; Title line
len_banner_mid equ $-banner_mid                                                             ; Length of middle banner
banner_bot:    db 0x1B,'[36m', '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛', 10, 0x1B,'[0m' ; Bottom + reset
len_banner_bot equ $-banner_bot                                                             ; Length of bottom banner

prompt_text:   db 0x1B,'[1m', 0x1B,'[35m', 'Enter password', 0x1B,'[0m', 0x1B,'[90m', ' (hidden, type and press Enter): ', 0x1B,'[0m' ; Prompt line
len_prompt_text equ $-prompt_text                                                                                                             ; Length of prompt

analyzing:     db 0x1B,'[90m', 'Analyzing password...', 10, 0x1B,'[0m' ; Gray info message
len_analyzing  equ $-analyzing                                        ; Length of analyzing text

strength_lbl:  db 0x1B,'[1m', 'Strength: ', 0x1B,'[0m' ; Bold label "Strength: "
len_strength_lbl equ $-strength_lbl                   ; Length of label

rating_veryweak: db 0x1B,'[31m','Very Weak',0x1B,'[0m',10   ; Red "Very Weak"
len_rating_veryweak equ $-rating_veryweak                 ; Length
rating_weak:     db 0x1B,'[33m','Weak',0x1B,'[0m',10        ; Yellow "Weak"
len_rating_weak   equ $-rating_weak                        ; Length
rating_medium:   db 0x1B,'[34m','Medium',0x1B,'[0m',10      ; Blue "Medium"
len_rating_medium equ $-rating_medium                       ; Length
rating_strong:   db 0x1B,'[32m','Strong',0x1B,'[0m',10      ; Green "Strong"
len_rating_strong equ $-rating_strong                       ; Length
rating_vstrong:  db 0x1B,'[32m',0x1B,'[1m','Very Strong',0x1B,'[0m',10 ; Bold green "Very Strong"
len_rating_vstrong equ $-rating_vstrong                               ; Length

bar_open:     db '['                           ; Opening bracket of progress bar
len_bar_open  equ $-bar_open                   ; Length
bar_close:    db ']',10                        ; Closing bracket + newline
len_bar_close equ $-bar_close                  ; Length
fill_block:   db 0xE2,0x96,0x88                ; UTF-8 for '█'
len_fill_block equ $-fill_block                ; Length of filled block
empty_block:  db 0xE2,0x96,0x91                ; UTF-8 for '░'
len_empty_block equ $-empty_block              ; Length of empty block

suggest_hdr:  db 10, 0x1B,'[1m', 'Suggestions:', 0x1B,'[0m',10 ; Header before suggestions
len_suggest_hdr equ $-suggest_hdr                              ; Length
s_bullet:     db 0x1B,'[90m',' - ',0x1B,'[0m'                  ; Gray bullet prefix
len_s_bullet  equ $-s_bullet                                   ; Length
s_len12:      db 'Use at least 12 characters.',10              ; Suggestion: length
len_s_len12   equ $-s_len12                                    ; Length
s_upper:      db 'Add uppercase letters (A-Z).',10             ; Suggestion: uppercase
len_s_upper   equ $-s_upper                                    ; Length
s_lower:      db 'Add lowercase letters (a-z).',10             ; Suggestion: lowercase
len_s_lower   equ $-s_lower                                    ; Length
s_digit:      db 'Add digits (0-9).',10                        ; Suggestion: digits
len_s_digit   equ $-s_digit                                    ; Length
s_special:    db 'Add special characters (!@#$... ).',10       ; Suggestion: specials
len_s_special equ $-s_special                                   ; Length
s_spaces:     db 'Avoid spaces.',10                            ; Suggestion: avoid spaces
len_s_spaces  equ $-s_spaces                                   ; Length
s_common:     db 'Avoid common or leaked passwords.',10        ; Suggestion: blacklist
len_s_common  equ $-s_common                                   ; Length

ok_msg:       db 10, 0x1B,'[32m','Looks good! 🎉',0x1B,'[0m',10 ; Message when no suggestions
len_ok_msg    equ $-ok_msg                                     ; Length

; Blacklist (exact match, case-insensitive)
bl_pw1: db 'password'                     ; Common weak password
bl_pw1_len equ $-bl_pw1                   ; Length of bl_pw1
bl_pw2: db '123456'                       ; Common sequence
bl_pw2_len equ $-bl_pw2                   ; Length of bl_pw2
bl_pw3: db 'qwerty'                       ; Keyboard pattern
bl_pw3_len equ $-bl_pw3                   ; Length of bl_pw3
bl_pw4: db 'letmein'                      ; Common phrase
bl_pw4_len equ $-bl_pw4                   ; Length of bl_pw4
bl_pw5: db 'admin'                        ; Default credential
bl_pw5_len equ $-bl_pw5                   ; Length of bl_pw5

; stty exec data
path_stty: db '/bin/stty',0               ; Absolute path to stty binary
arg0:   db 'stty',0                       ; argv[0]
; off args
arg_off1: db '-echo',0                    ; Disable echo
arg_off2: db '-icanon',0                  ; Disable canonical mode (read 1 byte at a time)
arg_off3: db 'min',0                      ; read minimum bytes keyword
arg_off4: db '1',0                        ; value for min
arg_off5: db 'time',0                     ; read timeout keyword
arg_off6: db '0',0                        ; value for time (no timeout)
; on args
arg_on1: db 'echo',0                      ; Re-enable echo
arg_on2: db 'icanon',0                    ; Re-enable canonical mode

align 8                                   ; Align to 8 bytes for pointers
argv_off: dq arg0, arg_off1, arg_off2, arg_off3, arg_off4, arg_off5, arg_off6, 0 ; argv for disabling settings
argv_on:  dq arg0, arg_on1, arg_on2, 0    ; argv for re-enabling settings
envp_null: dq 0                           ; Null envp for execve

; Specials set for membership test
specials: db '!@#$%^&*()-_=+[]{};:,.<>/?`~|' ; Set of special characters
          db 92, 34   ; backslash (92), double quote (34)
len_specials equ $-specials                   ; Count of specials

; Small static texts
thanks: db 10, 0x1B,'[36m','Thank you for using the checker.',0x1B,'[0m',10 ; Farewell message
len_thanks equ $-thanks                                                            ; Length

SECTION .bss                             ; Zero-initialized data
pw_buf:     resb 256                     ; Buffer to hold the password (max 255 + terminator)
pw_len:     resq 1                       ; Stores the length of the password (64-bit)

status:     resd 1    ; wait status      ; Child process wait status (32-bit)

; flags
flag_upper:  resb 1                      ; 1 if has uppercase
flag_lower:  resb 1                      ; 1 if has lowercase
flag_digit:  resb 1                      ; 1 if has digit
flag_special:resb 1                      ; 1 if has special char
flag_space:  resb 1                      ; 1 if contains space
flag_black:  resb 1                      ; 1 if matches blacklist

SECTION .text                           ; Code section
global password_checker_main            ; Exported entry point for this module
; Overall: Securely read a hidden password, analyze strength, print rating, bar, and suggestions

; Block: password_checker_main — Banner, stty off, masked input, stty on, analyze and render
password_checker_main:                  ; Main routine (returns to caller)
    ; preserve callee-saved registers
    push rbp                            ; Save base pointer
    mov rbp, rsp                        ; Establish stack frame
    push rbx                            ; Save callee-saved regs
    push r12
    push r13
    push r14
    push r15

    ; Print banner
    mov rdi, 1                          ; fd=1 (stdout)
    mov rsi, banner_top                 ; buf=top banner
    mov rdx, len_banner_top             ; len
    mov rax, 1                          ; sys_write
    syscall                             ; write(stdout, banner_top, len)

    mov rsi, banner_mid                 ; buf=mid banner
    mov rdx, len_banner_mid             ; len
    mov rax, 1                          ; sys_write
    syscall                             ; write mid line

    mov rsi, banner_bot                 ; buf=bottom banner
    mov rdx, len_banner_bot             ; len
    mov rax, 1                          ; sys_write
    syscall                             ; write bottom line

    ; Prompt
    mov rsi, prompt_text                ; buf=prompt
    mov rdx, len_prompt_text            ; len
    mov rax, 1                          ; sys_write
    syscall                             ; write prompt

    ; Disable echo + canonical via stty
    lea rdi, [rel argv_off]             ; rdi = argv array for "stty -echo -icanon min 1 time 0"
    call run_stty                       ; run child process to change TTY mode

    ; Read password masked
    call read_password                  ; Reads bytes, echoes '*' for each, handles backspace; returns len in rax
    ; rax = length

    ; Restore terminal
    lea rdi, [rel argv_on]              ; rdi = argv array for "stty echo icanon"
    call run_stty                       ; Restore TTY settings

    ; Newline already printed by reader, but ensure separation
    mov rsi, analyzing                   ; buf="Analyzing password...\n"
    mov rdx, len_analyzing              ; len
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    syscall                             ; write analyzing message

    ; Analyze
    call analyze_password               ; Computes score and sets flags
    ; score in rax (0..5)
    mov r12, rax                        ; Save score in r12

    ; Print Strength label
    mov rdi, 1                          ; stdout
    mov rsi, strength_lbl               ; "Strength: " label
    mov rdx, len_strength_lbl           ; len
    mov rax, 1                          ; sys_write
    syscall

    ; Print rating text per score
    cmp r12, 1                          ; score <= 1?
    jbe .veryweak_or_weak               ; Jump if 0 or 1
    cmp r12, 2                          ; score == 2?
    je .print_medium
    cmp r12, 3                          ; score == 3?
    je .print_strong
    cmp r12, 4                          ; score == 4?
    je .print_vstrong
    cmp r12, 5                          ; score == 5?
    je .print_vstrong

.veryweak_or_weak:                      ; Distinguish 0 vs 1
    cmp r12, 0
    je .print_veryweak                  ; score 0
    jmp .print_weak                     ; score 1

.print_veryweak:                        ; Select "Very Weak"
    mov rsi, rating_veryweak
    mov rdx, len_rating_veryweak
    jmp .emit_rating
.print_weak:
    mov rsi, rating_weak                ; Select "Weak"
    mov rdx, len_rating_weak
    jmp .emit_rating
.print_medium:
    mov rsi, rating_medium              ; Select "Medium"
    mov rdx, len_rating_medium
    jmp .emit_rating
.print_strong:
    mov rsi, rating_strong              ; Select "Strong"
    mov rdx, len_rating_strong
    jmp .emit_rating
.print_vstrong:
    mov rsi, rating_vstrong             ; Select "Very Strong"
    mov rdx, len_rating_vstrong
.emit_rating:
    mov rdi, 1                          ; stdout
    mov rax, 1                          ; sys_write
    syscall                             ; write selected rating

    ; Print colorful progress bar [████░░░░░]
    mov rdi, 1                          ; stdout
    mov rsi, bar_open                   ; '['
    mov rdx, len_bar_open               ; len
    mov rax, 1                          ; sys_write
    syscall

    ; decide color by score
    ; <=1 red, 2 yellow, 3 blue, >=4 green
    cmp r12, 1                          ; score <=1?
    jbe .bar_red
    cmp r12, 2                          ; score ==2?
    je .bar_yellow
    cmp r12, 3                          ; score ==3?
    je .bar_blue
    jmp .bar_green                      ; else >=4
.bar_red:
    mov rsi, fg_red                     ; Set red color
    mov rdx, len_fg_red
    jmp .emit_bar_color
.bar_yellow:
    mov rsi, fg_yellow                  ; Set yellow color
    mov rdx, len_fg_yellow
    jmp .emit_bar_color
.bar_blue:
    mov rsi, fg_blue                    ; Set blue color
    mov rdx, len_fg_blue
    jmp .emit_bar_color
.bar_green:
    mov rsi, fg_green                   ; Set green color
    mov rdx, len_fg_green
.emit_bar_color:
    mov rdi, 1                          ; stdout
    mov rax, 1                          ; sys_write
    syscall                             ; write color sequence

    ; filled blocks = score * 2 (0..10)
    mov rax, r12                        ; rax = score
    shl rax, 1                          ; times 2
    mov r13, rax   ; filled count       ; number of filled blocks to draw
    mov r14, 10    ; total              ; total blocks

.bar_fill_loop:
    cmp r13, 0                          ; Any filled blocks left?
    jle .bar_empty_color                ; If none, switch color to gray and draw empties
    ; emit filled block
    mov rdi, 1                          ; stdout
    mov rsi, fill_block                 ; '█'
    mov rdx, len_fill_block             ; len
    mov rax, 1                          ; sys_write
    syscall
    dec r13                             ; one less filled
    dec r14                             ; one less total to draw
    jmp .bar_fill_loop                  ; continue

.bar_empty_color:
    ; reset to gray for empties
    mov rdi, 1                          ; stdout
    mov rsi, reset                      ; reset any previous color
    mov rdx, len_reset
    mov rax, 1                          ; sys_write
    syscall

    mov rsi, fg_gray                    ; set gray for empty blocks
    mov rdx, len_fg_gray
    mov rax, 1                          ; sys_write
    syscall

.bar_empty_loop:
    cmp r14, 0                          ; Any blocks left to draw?
    jle .bar_close
    mov rdi, 1                          ; stdout
    mov rsi, empty_block                ; '░'
    mov rdx, len_empty_block            ; len
    mov rax, 1                          ; sys_write
    syscall
    dec r14                             ; decrement remaining
    jmp .bar_empty_loop                 ; continue

.bar_close:
    ; reset
    mov rdi, 1                          ; stdout
    mov rsi, reset                      ; reset colors
    mov rdx, len_reset
    mov rax, 1                          ; sys_write
    syscall

    mov rdi, 1                          ; stdout
    mov rsi, bar_close                  ; "]\n"
    mov rdx, len_bar_close
    mov rax, 1                          ; sys_write
    syscall

    ; Suggestions
    ; If any flag indicates missing or blacklist/space/len<12, print header and bullets
    ; Determine if any suggestions needed
    mov bl, [flag_upper]                ; bl = has uppercase
    mov bh, [flag_lower]                ; bh = has lowercase
    mov dl, [flag_digit]                ; dl = has digit
    mov dh, [flag_special]              ; dh = has special
    mov al, [flag_space]                ; al = contains space
    mov cl, [flag_black]                ; cl = is blacklisted

    ; need_len = pw_len < 12
    mov rax, [pw_len]                   ; load length
    cmp rax, 12                         ; length < 12?
    jb .need_len
    mov r15b, 0                         ; no length suggestion
    jmp .after_len
.need_len:
    mov r15b, 1                         ; need length suggestion
.after_len:

    ; compute if any missing
    mov r8b, 0                          ; scratch (unused here)
    cmp bl, 0                           ; missing uppercase?
    je .some
    cmp bh, 0                           ; missing lowercase?
    je .some
    cmp dl, 0                           ; missing digit?
    je .some
    cmp dh, 0                           ; missing special?
    je .some
    cmp al, 1                           ; contains space?
    je .some
    cmp cl, 1                           ; is blacklisted?
    je .some
    cmp r15b, 1                         ; need length?
    je .some
    jmp .no_suggestions                 ; none needed
.some:
    ; header
    mov rdi, 1                          ; stdout
    mov rsi, suggest_hdr                ; "Suggestions:" header
    mov rdx, len_suggest_hdr            ; len
    mov rax, 1                          ; sys_write
    syscall

    ; bullets
    ; len
    cmp r15b, 1                         ; need length suggestion?
    jne .s1
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet prefix
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_len12                    ; message text
    mov rdx, len_s_len12
    mov rax, 1                          ; sys_write
    syscall
.s1:
    ; upper
    cmp bl, 0                           ; missing uppercase?
    jne .s2
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_upper                    ; text
    mov rdx, len_s_upper
    mov rax, 1                          ; sys_write
    syscall
.s2:
    ; lower
    cmp bh, 0                           ; missing lowercase?
    jne .s3
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_lower                    ; text
    mov rdx, len_s_lower
    mov rax, 1                          ; sys_write
    syscall
.s3:
    ; digit
    cmp dl, 0                           ; missing digit?
    jne .s4
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_digit                    ; text
    mov rdx, len_s_digit
    mov rax, 1                          ; sys_write
    syscall
.s4:
    ; special
    cmp dh, 0                           ; missing special?
    jne .s5
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_special                  ; text
    mov rdx, len_s_special
    mov rax, 1                          ; sys_write
    syscall
.s5:
    ; spaces
    cmp al, 1                           ; contains spaces?
    jne .s6
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_spaces                   ; text
    mov rdx, len_s_spaces
    mov rax, 1                          ; sys_write
    syscall
.s6:
    ; common
    cmp cl, 1                           ; is blacklisted?
    jne .after_suggestions
    mov rdi, 1                          ; stdout
    mov rsi, s_bullet                   ; bullet
    mov rdx, len_s_bullet
    mov rax, 1                          ; sys_write
    syscall
    mov rsi, s_common                   ; text
    mov rdx, len_s_common
    mov rax, 1                          ; sys_write
    syscall

    jmp .end

.after_suggestions:
    jmp .end                            ; continue to end

.no_suggestions:
    mov rdi, 1                          ; stdout
    mov rsi, ok_msg                     ; "Looks good!" message
    mov rdx, len_ok_msg
    mov rax, 1                          ; sys_write
    syscall


.end:
    ; Thank you
    mov rdi, 1                          ; stdout
    mov rsi, thanks                     ; closing message
    mov rdx, len_thanks
    mov rax, 1                          ; sys_write
    syscall

    ; restore and return to caller
    pop r15                              ; Restore callee-saved regs
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret                                  ; Return to caller

;-------------------------------------
; Subroutines
;-------------------------------------
; run_stty(rdi=argv_ptr)                 ; Launches stty with provided argv, waits for completion
; Block: run_stty — Fork/exec stty with argv in rdi; parent waits, child execs
run_stty:
    push rbp                            ; prologue
    mov rbp, rsp
    push r12
    push rbx
    ; save argv pointer
    mov r12, rdi                        ; keep argv pointer in r12 across syscalls
    ; fork
    mov rax, 57                         ; sys_fork
    syscall
    test rax, rax                       ; rax==0 in child, >0 in parent
    jz .child                           ; jump to child path
    ; parent: wait4(child, &status, 0, NULL)
    mov rbx, rax                        ; rbx = child pid
    mov rax, 61                         ; sys_wait4
    mov rdi, rbx                        ; rdi = pid
    lea rsi, [rel status]               ; rsi = &status
    xor rdx, rdx                        ; rdx = options = 0
    xor r10, r10                        ; r10 = rusage = NULL
    syscall
    jmp .ret                            ; done
.child:
    ; execve('/bin/stty', argv, envp_null)
    mov rax, 59                         ; sys_execve
    lea rdi, [rel path_stty]            ; filename
    mov rsi, r12                        ; argv
    lea rdx, [rel envp_null]            ; envp
    syscall
    ; if exec fails
    mov rax, 60                         ; sys_exit
    mov rdi, 127                        ; exit code 127 (command not found)
    syscall
.ret:
    pop rbx                             ; epilogue
    pop r12
    pop rbp
    ret

; read_password -> returns length in rax, stores in pw_buf and pw_len
; Block: read_password — Read bytes, mask with '*', handle backspace, stop on newline; return length
read_password:
    push rbp                            ; prologue
    mov rbp, rsp
    xor rbx, rbx          ; len         ; rbx = current length (index)
.read_loop:
    ; read 1 byte
    mov rax, 0                          ; sys_read
    mov rdi, 0                          ; fd=stdin
    lea rsi, [rel pw_buf]               ; base of buffer
    add rsi, rbx                        ; point to next position
    mov rdx, 1                          ; read 1 byte
    syscall
    cmp rax, 1                          ; read returned 1?
    jne .finish                         ; EOF/error -> finish
    mov al, [pw_buf + rbx]              ; al = the byte read
    ; Enter?
    cmp al, 10                          ; '\n'
    je .done
    cmp al, 13                          ; '\r'
    je .done
    ; backspace
    cmp al, 127                         ; DEL
    je .handle_back
    cmp al, 8                           ; BS
    je .handle_back
    ; normal char
    cmp rbx, 255                        ; buffer full?
    jae .read_loop                      ; if full, ignore extra
    inc rbx                             ; accept char, increment length
    ; echo '*'
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    mov rsi, star                       ; '*'
    mov rdx, len_star
    syscall
    jmp .read_loop                      ; continue reading
.handle_back:
    cmp rbx, 0                          ; at start?
    jle .read_loop                      ; nothing to erase
    dec rbx                             ; reduce length by 1
    ; erase last '*'
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    mov rsi, back_erase                 ; "\b \b"
    mov rdx, len_back_erase
    syscall
    jmp .read_loop                      ; continue
.done:
    ; print newline
    mov rax, 1                          ; sys_write
    mov rdi, 1                          ; stdout
    mov rsi, nl                         ; '\n'
    mov rdx, len_nl
    syscall
.finish:
    ; null-terminate (optional)
    mov byte [pw_buf + rbx], 0          ; NUL terminator for convenience
    mov [pw_len], rbx                   ; save length
    mov rax, rbx                        ; return length
    pop rbp                             ; epilogue
    ret

; analyze_password -> returns score in rax, sets flags
; Block: analyze_password — Scan flags, compute score (0..5), blacklist exact matches
analyze_password:
    push rbp                            ; prologue
    mov rbp, rsp

    ; clear flags
    mov byte [flag_upper], 0            ; reset all flags to 0
    mov byte [flag_lower], 0
    mov byte [flag_digit], 0
    mov byte [flag_special], 0
    mov byte [flag_space], 0
    mov byte [flag_black], 0

    mov rcx, [pw_len]                   ; rcx = length
    xor rbx, rbx ; i                    ; rbx = index i
    ; jrcxz .after_scan  ; replaced to allow long jump
    test rcx, rcx                       ; length == 0?
    jz .after_scan                      ; if empty, skip scan
.scan_loop:
    mov al, [pw_buf + rbx]              ; al = current char
    cmp al, 0                           ; stop if NUL (safety)
    je .after_scan
    ; space?
    cmp al, ' '                         ; space character?
    jne .check_upper
    mov byte [flag_space], 1            ; mark contains space
    jmp .next
.check_upper:
    cmp al, 'A'                         ; >= 'A' ?
    jb .check_lower
    cmp al, 'Z'                         ; <= 'Z' ?
    ja .check_lower
    mov byte [flag_upper], 1            ; mark uppercase present
    jmp .next
.check_lower:
    cmp al, 'a'                         ; >= 'a' ?
    jb .check_digit
    cmp al, 'z'                         ; <= 'z' ?
    ja .check_digit
    mov byte [flag_lower], 1            ; mark lowercase present
    jmp .next
.check_digit:
    cmp al, '0'                         ; >= '0' ?
    jb .check_special
    cmp al, '9'                         ; <= '9' ?
    ja .check_special
    mov byte [flag_digit], 1            ; mark digit present
    jmp .next
.check_special:
    ; membership in specials
    mov rdi, specials                   ; pointer to specials set
    mov rsi, len_specials               ; count
.sp_loop:
    cmp rsi, 0                          ; exhausted?
    je .next
    mov dl, [rdi]                       ; dl = current special
    cmp dl, al                          ; match?
    je .mark_special
    inc rdi                             ; advance pointer
    dec rsi                             ; decrement count
    jmp .sp_loop
.mark_special:
    mov byte [flag_special], 1          ; mark special present
.next:
    inc rbx                             ; i++
    cmp rbx, rcx                        ; i < len ?
    jb .scan_loop

.after_scan:
    ; score
    xor rax, rax                        ; rax/al = score accumulator
    mov al, [flag_upper]                ; +1 if uppercase
    add al, [flag_lower]                ; +1 if lowercase
    add al, [flag_digit]                ; +1 if digit
    add al, [flag_special]              ; +1 if special
    ; length bonus
    mov rdx, [pw_len]                   ; length
    cmp rdx, 12                         ; >= 12?
    jb .no_len_bonus
    inc al                              ; add 1 bonus
.no_len_bonus:
    ; blacklist exact match (case-insensitive)
    push rax                            ; save score
    ; compare with each bl
    ; if match, set flag_black and set score=0
    ; helper: cmp_case_insensitive(pw_buf, len, str, slen)
    ; bl1
    mov rdi, pw_buf                     ; pw ptr
    mov rsi, [pw_len]                   ; pw len
    mov rdx, bl_pw1                     ; bl string ptr
    mov rcx, bl_pw1_len                 ; bl length
    call eq_case_ins                    ; rax=1 if equal ignoring case
    cmp rax, 1
    je .black
    ; bl2
    mov rdi, pw_buf
    mov rsi, [pw_len]
    mov rdx, bl_pw2
    mov rcx, bl_pw2_len
    call eq_case_ins
    cmp rax, 1
    je .black
    ; bl3
    mov rdi, pw_buf
    mov rsi, [pw_len]
    mov rdx, bl_pw3
    mov rcx, bl_pw3_len
    call eq_case_ins
    cmp rax, 1
    je .black
    ; bl4
    mov rdi, pw_buf
    mov rsi, [pw_len]
    mov rdx, bl_pw4
    mov rcx, bl_pw4_len
    call eq_case_ins
    cmp rax, 1
    je .black
    ; bl5
    mov rdi, pw_buf
    mov rsi, [pw_len]
    mov rdx, bl_pw5
    mov rcx, bl_pw5_len
    call eq_case_ins
    cmp rax, 1
    je .black
    jmp .no_black
.black:
    mov byte [flag_black], 1            ; mark blacklisted
    pop rax                             ; discard saved score
    xor eax, eax                        ; score = 0
    jmp .clamp
.no_black:
    pop rax                             ; restore score

.clamp:
    ; clamp to 0..5 (already is)
    ; return in rax
    movzx rax, al                       ; zero-extend score to rax
    pop rbp                             ; epilogue
    ret

; eq_case_ins(rdi=pw_ptr, rsi=pw_len, rdx=str_ptr, rcx=str_len) -> rax=1 if equal, else 0
; compares exact length and each char tolower
; Block: eq_case_ins — Case-insensitive equality for two buffers of given lengths
eq_case_ins:
    push rbp                            ; prologue
    mov rbp, rsp
    ; length equal?
    cmp rsi, rcx                        ; if lengths differ
    jne .no                             ; not equal
    xor r8, r8                          ; i = 0
.loop:
    cmp r8, rsi                         ; i >= len ?
    jae .yes                            ; all matched
    mov al, [rdi + r8]                  ; al = pw[i]
    mov bl, [rdx + r8]                  ; bl = str[i]
    ; tolower al
    cmp al, 'A'
    jb .tl_done                         ; if < 'A', skip
    cmp al, 'Z'
    ja .tl_done                         ; if > 'Z', skip
    add al, 32                          ; make lowercase
.tl_done:
    ; tolower bl
    cmp bl, 'A'
    jb .tl2_done
    cmp bl, 'Z'
    ja .tl2_done
    add bl, 32
.tl2_done:
    cmp al, bl                          ; compare
    jne .no                             ; mismatch
    inc r8                              ; i++
    jmp .loop
.yes:
    mov rax, 1                          ; equal
    jmp .ret
.no:
    xor rax, rax                        ; not equal
.ret:
    pop rbp                             ; epilogue
    ret
