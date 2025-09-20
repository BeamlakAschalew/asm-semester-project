; Password Strength Checker - NASM x86_64 Linux (module)
; Exposes: password_checker_main (no exit; returns to caller)
; Build (with util.asm):
;   nasm -f elf64 password_checker.asm -o password_checker.o
;   nasm -f elf64 util.asm -o util.o
;   ld -o pwcheck util.o password_checker.o

BITS 64

SECTION .data
; ANSI colors and styles
esc:        db 0x1B
reset:      db 0x1B, '[0m'
len_reset   equ $-reset
bold:       db 0x1B, '[1m'
len_bold    equ $-bold

fg_red:     db 0x1B, '[31m'
len_fg_red  equ $-fg_red
fg_yellow:  db 0x1B, '[33m'
len_fg_yellow equ $-fg_yellow
fg_green:   db 0x1B, '[32m'
len_fg_green equ $-fg_green
fg_blue:    db 0x1B, '[34m'
len_fg_blue equ $-fg_blue
fg_cyan:    db 0x1B, '[36m'
len_fg_cyan equ $-fg_cyan
fg_magenta: db 0x1B, '[35m'
len_fg_magenta equ $-fg_magenta
fg_gray:    db 0x1B, '[90m'
len_fg_gray equ $-fg_gray

nl:         db 10
len_nl      equ $-nl
space:      db ' '
len_space   equ $-space
star:       db '*'
len_star    equ $-star
back_erase: db 8,' ',8   ; "\b \b"
len_back_erase equ $-back_erase

; Banner
banner_top:    db 0x1B,'[36m', '┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓', 10
len_banner_top equ $-banner_top
banner_mid:    db 0x1B,'[1m', 0x1B,'[36m', '┃   Password Strength Checker (NASM, Linux)   ┃', 10
len_banner_mid equ $-banner_mid
banner_bot:    db 0x1B,'[36m', '┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛', 10, 0x1B,'[0m'
len_banner_bot equ $-banner_bot

prompt_text:   db 0x1B,'[1m', 0x1B,'[35m', 'Enter password', 0x1B,'[0m', 0x1B,'[90m', ' (hidden, type and press Enter): ', 0x1B,'[0m'
len_prompt_text equ $-prompt_text

analyzing:     db 0x1B,'[90m', 'Analyzing password...', 10, 0x1B,'[0m'
len_analyzing  equ $-analyzing

strength_lbl:  db 0x1B,'[1m', 'Strength: ', 0x1B,'[0m'
len_strength_lbl equ $-strength_lbl

rating_veryweak: db 0x1B,'[31m','Very Weak',0x1B,'[0m',10
len_rating_veryweak equ $-rating_veryweak
rating_weak:     db 0x1B,'[33m','Weak',0x1B,'[0m',10
len_rating_weak   equ $-rating_weak
rating_medium:   db 0x1B,'[34m','Medium',0x1B,'[0m',10
len_rating_medium equ $-rating_medium
rating_strong:   db 0x1B,'[32m','Strong',0x1B,'[0m',10
len_rating_strong equ $-rating_strong
rating_vstrong:  db 0x1B,'[32m',0x1B,'[1m','Very Strong',0x1B,'[0m',10
len_rating_vstrong equ $-rating_vstrong

bar_open:     db '['
len_bar_open  equ $-bar_open
bar_close:    db ']',10
len_bar_close equ $-bar_close
fill_block:   db 0xE2,0x96,0x88 ; '█' U+2588
len_fill_block equ $-fill_block
empty_block:  db 0xE2,0x96,0x91 ; '░' U+2591
len_empty_block equ $-empty_block

suggest_hdr:  db 10, 0x1B,'[1m', 'Suggestions:', 0x1B,'[0m',10
len_suggest_hdr equ $-suggest_hdr
s_bullet:     db 0x1B,'[90m',' - ',0x1B,'[0m'
len_s_bullet  equ $-s_bullet
s_len12:      db 'Use at least 12 characters.',10
len_s_len12   equ $-s_len12
s_upper:      db 'Add uppercase letters (A-Z).',10
len_s_upper   equ $-s_upper
s_lower:      db 'Add lowercase letters (a-z).',10
len_s_lower   equ $-s_lower
s_digit:      db 'Add digits (0-9).',10
len_s_digit   equ $-s_digit
s_special:    db 'Add special characters (!@#$... ).',10
len_s_special equ $-s_special
s_spaces:     db 'Avoid spaces.',10
len_s_spaces  equ $-s_spaces
s_common:     db 'Avoid common or leaked passwords.',10
len_s_common  equ $-s_common

ok_msg:       db 10, 0x1B,'[32m','Looks good! 🎉',0x1B,'[0m',10
len_ok_msg    equ $-ok_msg

; Blacklist (exact match, case-insensitive)
bl_pw1: db 'password'
bl_pw1_len equ $-bl_pw1
bl_pw2: db '123456'
bl_pw2_len equ $-bl_pw2
bl_pw3: db 'qwerty'
bl_pw3_len equ $-bl_pw3
bl_pw4: db 'letmein'
bl_pw4_len equ $-bl_pw4
bl_pw5: db 'admin'
bl_pw5_len equ $-bl_pw5

; stty exec data
path_stty: db '/bin/stty',0
arg0:   db 'stty',0
; off args
arg_off1: db '-echo',0
arg_off2: db '-icanon',0
arg_off3: db 'min',0
arg_off4: db '1',0
arg_off5: db 'time',0
arg_off6: db '0',0
; on args
arg_on1: db 'echo',0
arg_on2: db 'icanon',0

align 8
argv_off: dq arg0, arg_off1, arg_off2, arg_off3, arg_off4, arg_off5, arg_off6, 0
argv_on:  dq arg0, arg_on1, arg_on2, 0
envp_null: dq 0

; Specials set for membership test
specials: db '!@#$%^&*()-_=+[]{};:,.<>/?`~|'
          db 92, 34   ; backslash (92), double quote (34)
len_specials equ $-specials

; Small static texts
thanks: db 10, 0x1B,'[36m','Thank you for using the checker.',0x1B,'[0m',10
len_thanks equ $-thanks

SECTION .bss
pw_buf:     resb 256
pw_len:     resq 1

status:     resd 1    ; wait status

; flags
flag_upper:  resb 1
flag_lower:  resb 1
flag_digit:  resb 1
flag_special:resb 1
flag_space:  resb 1
flag_black:  resb 1

SECTION .text
global password_checker_main

password_checker_main:
    ; preserve callee-saved registers
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Print banner
    mov rdi, 1
    mov rsi, banner_top
    mov rdx, len_banner_top
    mov rax, 1
    syscall

    mov rsi, banner_mid
    mov rdx, len_banner_mid
    mov rax, 1
    syscall

    mov rsi, banner_bot
    mov rdx, len_banner_bot
    mov rax, 1
    syscall

    ; Prompt
    mov rsi, prompt_text
    mov rdx, len_prompt_text
    mov rax, 1
    syscall

    ; Disable echo + canonical via stty
    lea rdi, [rel argv_off]
    call run_stty

    ; Read password masked
    call read_password
    ; rax = length

    ; Restore terminal
    lea rdi, [rel argv_on]
    call run_stty

    ; Newline already printed by reader, but ensure separation
    mov rsi, analyzing
    mov rdx, len_analyzing
    mov rax, 1
    mov rdi, 1
    syscall

    ; Analyze
    call analyze_password
    ; score in rax (0..5)
    mov r12, rax

    ; Print Strength label
    mov rdi, 1
    mov rsi, strength_lbl
    mov rdx, len_strength_lbl
    mov rax, 1
    syscall

    ; Print rating text per score
    cmp r12, 1
    jbe .veryweak_or_weak
    cmp r12, 2
    je .print_medium
    cmp r12, 3
    je .print_strong
    cmp r12, 4
    je .print_vstrong
    cmp r12, 5
    je .print_vstrong

.veryweak_or_weak:
    cmp r12, 0
    je .print_veryweak
    jmp .print_weak

.print_veryweak:
    mov rsi, rating_veryweak
    mov rdx, len_rating_veryweak
    jmp .emit_rating
.print_weak:
    mov rsi, rating_weak
    mov rdx, len_rating_weak
    jmp .emit_rating
.print_medium:
    mov rsi, rating_medium
    mov rdx, len_rating_medium
    jmp .emit_rating
.print_strong:
    mov rsi, rating_strong
    mov rdx, len_rating_strong
    jmp .emit_rating
.print_vstrong:
    mov rsi, rating_vstrong
    mov rdx, len_rating_vstrong
.emit_rating:
    mov rdi, 1
    mov rax, 1
    syscall

    ; Print colorful progress bar [████░░░░░]
    mov rdi, 1
    mov rsi, bar_open
    mov rdx, len_bar_open
    mov rax, 1
    syscall

    ; decide color by score
    ; <=1 red, 2 yellow, 3 blue, >=4 green
    cmp r12, 1
    jbe .bar_red
    cmp r12, 2
    je .bar_yellow
    cmp r12, 3
    je .bar_blue
    jmp .bar_green
.bar_red:
    mov rsi, fg_red
    mov rdx, len_fg_red
    jmp .emit_bar_color
.bar_yellow:
    mov rsi, fg_yellow
    mov rdx, len_fg_yellow
    jmp .emit_bar_color
.bar_blue:
    mov rsi, fg_blue
    mov rdx, len_fg_blue
    jmp .emit_bar_color
.bar_green:
    mov rsi, fg_green
    mov rdx, len_fg_green
.emit_bar_color:
    mov rdi, 1
    mov rax, 1
    syscall

    ; filled blocks = score * 2 (0..10)
    mov rax, r12
    shl rax, 1
    mov r13, rax   ; filled count
    mov r14, 10    ; total

.bar_fill_loop:
    cmp r13, 0
    jle .bar_empty_color
    ; emit filled block
    mov rdi, 1
    mov rsi, fill_block
    mov rdx, len_fill_block
    mov rax, 1
    syscall
    dec r13
    dec r14
    jmp .bar_fill_loop

.bar_empty_color:
    ; reset to gray for empties
    mov rdi, 1
    mov rsi, reset
    mov rdx, len_reset
    mov rax, 1
    syscall

    mov rsi, fg_gray
    mov rdx, len_fg_gray
    mov rax, 1
    syscall

.bar_empty_loop:
    cmp r14, 0
    jle .bar_close
    mov rdi, 1
    mov rsi, empty_block
    mov rdx, len_empty_block
    mov rax, 1
    syscall
    dec r14
    jmp .bar_empty_loop

.bar_close:
    ; reset
    mov rdi, 1
    mov rsi, reset
    mov rdx, len_reset
    mov rax, 1
    syscall

    mov rdi, 1
    mov rsi, bar_close
    mov rdx, len_bar_close
    mov rax, 1
    syscall

    ; Suggestions
    ; If any flag indicates missing or blacklist/space/len<12, print header and bullets
    ; Determine if any suggestions needed
    mov bl, [flag_upper]
    mov bh, [flag_lower]
    mov dl, [flag_digit]
    mov dh, [flag_special]
    mov al, [flag_space]
    mov cl, [flag_black]

    ; need_len = pw_len < 12
    mov rax, [pw_len]
    cmp rax, 12
    jb .need_len
    mov r15b, 0
    jmp .after_len
.need_len:
    mov r15b, 1
.after_len:

    ; compute if any missing
    mov r8b, 0
    cmp bl, 0
    je .some
    cmp bh, 0
    je .some
    cmp dl, 0
    je .some
    cmp dh, 0
    je .some
    cmp al, 1
    je .some
    cmp cl, 1
    je .some
    cmp r15b, 1
    je .some
    jmp .no_suggestions
.some:
    ; header
    mov rdi, 1
    mov rsi, suggest_hdr
    mov rdx, len_suggest_hdr
    mov rax, 1
    syscall

    ; bullets
    ; len
    cmp r15b, 1
    jne .s1
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_len12
    mov rdx, len_s_len12
    mov rax, 1
    syscall
.s1:
    ; upper
    cmp bl, 0
    jne .s2
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_upper
    mov rdx, len_s_upper
    mov rax, 1
    syscall
.s2:
    ; lower
    cmp bh, 0
    jne .s3
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_lower
    mov rdx, len_s_lower
    mov rax, 1
    syscall
.s3:
    ; digit
    cmp dl, 0
    jne .s4
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_digit
    mov rdx, len_s_digit
    mov rax, 1
    syscall
.s4:
    ; special
    cmp dh, 0
    jne .s5
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_special
    mov rdx, len_s_special
    mov rax, 1
    syscall
.s5:
    ; spaces
    cmp al, 1
    jne .s6
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_spaces
    mov rdx, len_s_spaces
    mov rax, 1
    syscall
.s6:
    ; common
    cmp cl, 1
    jne .after_suggestions
    mov rdi, 1
    mov rsi, s_bullet
    mov rdx, len_s_bullet
    mov rax, 1
    syscall
    mov rsi, s_common
    mov rdx, len_s_common
    mov rax, 1
    syscall

    jmp .end

.after_suggestions:
    jmp .end

.no_suggestions:
    mov rdi, 1
    mov rsi, ok_msg
    mov rdx, len_ok_msg
    mov rax, 1
    syscall

.end:
    ; Thank you
    mov rdi, 1
    mov rsi, thanks
    mov rdx, len_thanks
    mov rax, 1
    syscall

    ; restore and return to caller
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

;-------------------------------------
; Subroutines
;-------------------------------------
; run_stty(rdi=argv_ptr)
run_stty:
    push rbp
    mov rbp, rsp
    push r12
    push rbx
    ; save argv pointer
    mov r12, rdi
    ; fork
    mov rax, 57
    syscall
    test rax, rax
    jz .child
    ; parent: wait4(child, &status, 0, NULL)
    mov rbx, rax
    mov rax, 61
    mov rdi, rbx
    lea rsi, [rel status]
    xor rdx, rdx
    xor r10, r10
    syscall
    jmp .ret
.child:
    ; execve('/bin/stty', argv, envp_null)
    mov rax, 59
    lea rdi, [rel path_stty]
    mov rsi, r12
    lea rdx, [rel envp_null]
    syscall
    ; if exec fails
    mov rax, 60
    mov rdi, 127
    syscall
.ret:
    pop rbx
    pop r12
    pop rbp
    ret

; read_password -> returns length in rax, stores in pw_buf and pw_len
read_password:
    push rbp
    mov rbp, rsp
    xor rbx, rbx          ; len
.read_loop:
    ; read 1 byte
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel pw_buf]
    add rsi, rbx
    mov rdx, 1
    syscall
    cmp rax, 1
    jne .finish
    mov al, [pw_buf + rbx]
    ; Enter?
    cmp al, 10
    je .done
    cmp al, 13
    je .done
    ; backspace
    cmp al, 127
    je .handle_back
    cmp al, 8
    je .handle_back
    ; normal char
    cmp rbx, 255
    jae .read_loop
    inc rbx
    ; echo '*'
    mov rax, 1
    mov rdi, 1
    mov rsi, star
    mov rdx, len_star
    syscall
    jmp .read_loop
.handle_back:
    cmp rbx, 0
    jle .read_loop
    dec rbx
    ; erase last '*'
    mov rax, 1
    mov rdi, 1
    mov rsi, back_erase
    mov rdx, len_back_erase
    syscall
    jmp .read_loop
.done:
    ; print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, nl
    mov rdx, len_nl
    syscall
.finish:
    ; null-terminate (optional)
    mov byte [pw_buf + rbx], 0
    mov [pw_len], rbx
    mov rax, rbx
    pop rbp
    ret

; analyze_password -> returns score in rax, sets flags
analyze_password:
    push rbp
    mov rbp, rsp

    ; clear flags
    mov byte [flag_upper], 0
    mov byte [flag_lower], 0
    mov byte [flag_digit], 0
    mov byte [flag_special], 0
    mov byte [flag_space], 0
    mov byte [flag_black], 0

    mov rcx, [pw_len]
    xor rbx, rbx ; i
    ; jrcxz .after_scan  ; replaced to allow long jump
    test rcx, rcx
    jz .after_scan
.scan_loop:
    mov al, [pw_buf + rbx]
    cmp al, 0
    je .after_scan
    ; space?
    cmp al, ' '
    jne .check_upper
    mov byte [flag_space], 1
    jmp .next
.check_upper:
    cmp al, 'A'
    jb .check_lower
    cmp al, 'Z'
    ja .check_lower
    mov byte [flag_upper], 1
    jmp .next
.check_lower:
    cmp al, 'a'
    jb .check_digit
    cmp al, 'z'
    ja .check_digit
    mov byte [flag_lower], 1
    jmp .next
.check_digit:
    cmp al, '0'
    jb .check_special
    cmp al, '9'
    ja .check_special
    mov byte [flag_digit], 1
    jmp .next
.check_special:
    ; membership in specials
    mov rdi, specials
    mov rsi, len_specials
.sp_loop:
    cmp rsi, 0
    je .next
    mov dl, [rdi]
    cmp dl, al
    je .mark_special
    inc rdi
    dec rsi
    jmp .sp_loop
.mark_special:
    mov byte [flag_special], 1
.next:
    inc rbx
    cmp rbx, rcx
    jb .scan_loop

.after_scan:
    ; score
    xor rax, rax
    mov al, [flag_upper]
    add al, [flag_lower]
    add al, [flag_digit]
    add al, [flag_special]
    ; length bonus
    mov rdx, [pw_len]
    cmp rdx, 12
    jb .no_len_bonus
    inc al
.no_len_bonus:
    ; blacklist exact match (case-insensitive)
    push rax
    ; compare with each bl
    ; if match, set flag_black and set score=0
    ; helper: cmp_case_insensitive(pw_buf, len, str, slen)
    ; bl1
    mov rdi, pw_buf
    mov rsi, [pw_len]
    mov rdx, bl_pw1
    mov rcx, bl_pw1_len
    call eq_case_ins
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
    mov byte [flag_black], 1
    pop rax
    xor eax, eax
    jmp .clamp
.no_black:
    pop rax

.clamp:
    ; clamp to 0..5 (already is)
    ; return in rax
    movzx rax, al
    pop rbp
    ret

; eq_case_ins(rdi=pw_ptr, rsi=pw_len, rdx=str_ptr, rcx=str_len) -> rax=1 if equal, else 0
; compares exact length and each char tolower
eq_case_ins:
    push rbp
    mov rbp, rsp
    ; length equal?
    cmp rsi, rcx
    jne .no
    xor r8, r8
.loop:
    cmp r8, rsi
    jae .yes
    mov al, [rdi + r8]
    mov bl, [rdx + r8]
    ; tolower al
    cmp al, 'A'
    jb .tl_done
    cmp al, 'Z'
    ja .tl_done
    add al, 32
.tl_done:
    ; tolower bl
    cmp bl, 'A'
    jb .tl2_done
    cmp bl, 'Z'
    ja .tl2_done
    add bl, 32
.tl2_done:
    cmp al, bl
    jne .no
    inc r8
    jmp .loop
.yes:
    mov rax, 1
    jmp .ret
.no:
    xor rax, rax
.ret:
    pop rbp
    ret
