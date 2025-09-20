; Word Count - NASM x86_64 Linux (module)
; Exposes: word_count_main

BITS 64

SECTION .data
wc_reset: db 0x1B,'[0m'
wc_len_reset equ $-wc_reset
wc_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
wc_len_banner_top equ $-wc_banner_top
wc_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃                 Word Count (ASM)            ┃',10
wc_len_banner_mid equ $-wc_banner_mid
wc_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
wc_len_banner_bot equ $-wc_banner_bot
wc_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
wc_len_prompt_text equ $-wc_prompt_text
wc_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Total words  [2] Specific word count',10
wc_len_prompt_mode equ $-wc_prompt_mode
wc_prompt_word: db 0x1B,'[1m','Word to count: ',0x1B,'[0m'
wc_len_prompt_word equ $-wc_prompt_word
wc_out_total: db 10,0x1B,'[1m','Total words: ',0x1B,'[0m'
wc_len_out_total equ $-wc_out_total
wc_out_spec:  db 10,0x1B,'[1m','Occurrences: ',0x1B,'[0m'
wc_len_out_spec equ $-wc_out_spec
wc_nl: db 10
wc_len_nl equ $-wc_nl

SECTION .bss
wc_text:   resb 65536
wc_len:    resq 1
wc_num:    resb 32
wc_inbuf:  resb 8
wc_word:   resb 256
wc_wlen:   resq 1

SECTION .text
global word_count_main

word_count_main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; banner
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_banner_top
    mov rdx, wc_len_banner_top
    syscall
    mov rsi, wc_banner_mid
    mov rdx, wc_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, wc_banner_bot
    mov rdx, wc_len_banner_bot
    mov rax, 1
    syscall

    ; read text
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_prompt_text
    mov rdx, wc_len_prompt_text
    syscall
    xor rbx, rbx
.rloop:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel wc_text]
    add rsi, rbx
    mov rdx, 65536
    sub rdx, rbx
    cmp rdx, 0
    je .rdone
    syscall
    test rax, rax
    jz .rdone
    js .rdone
    add rbx, rax
    cmp rbx, 65536
    jb .rloop
.rdone:
    mov [wc_len], rbx

    ; mode
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_prompt_mode
    mov rdx, wc_len_prompt_mode
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, wc_inbuf
    mov rdx, 2
    syscall
    mov al, [wc_inbuf]
    cmp al, '1'
    je .total

    ; specific word
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_prompt_word
    mov rdx, wc_len_prompt_word
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel wc_word]
    mov rdx, 255
    syscall
    ; compute length (strip newline)
    mov rcx, rax
    test rcx, rcx
    jz .setwlen
    dec rcx
    jl .setwlen
    mov al, [wc_word + rcx]
    cmp al, 10
    jne .setwlen2
    mov rax, rcx
    jmp .setwlen
.setwlen2:
    mov rax, rcx
    inc rax
.setwlen:
    mov [wc_wlen], rax

    xor r12, r12        ; i
    xor r13, r13        ; count
    mov r14, [wc_len]
    mov r15, [wc_wlen]
    cmp r15, 0
    je .spec_done
.spec_loop:
    cmp r12, r14
    jae .spec_done
    mov rax, r14
    sub rax, r12
    cmp rax, r15
    jb .spec_done
    mov rdi, wc_text
    add rdi, r12
    mov rsi, wc_word
    mov rcx, r15
    call wc_eq_ci_len
    cmp rax, 1
    jne .spec_nomatch
    inc r13
    add r12, r15
    jmp .spec_loop
.spec_nomatch:
    inc r12
    jmp .spec_loop
.spec_done:
    ; print occurrences
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_out_spec
    mov rdx, wc_len_out_spec
    syscall
    mov rdi, r13
    lea rsi, [rel wc_num]
    call wc_u64_to_dec
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel wc_num]
    mov rdx, rax
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_nl
    mov rdx, wc_len_nl
    syscall
    jmp .done

.total:
    ; count words as sequences of non-whitespace characters
    xor r12, r12            ; i
    mov r13, [wc_len]
    xor r14, r14            ; in_word flag (0/1)
    xor r15, r15            ; count
.tw_loop:
    cmp r12, r13
    jae .tw_done
    mov al, [wc_text + r12]
    ; classify whitespace: space, tab, nl, cr, vt, ff
    mov bl, 0               ; is_ws = 0
    cmp al, ' '
    je .mark_ws
    cmp al, 9
    je .mark_ws             ; tab
    cmp al, 10
    je .mark_ws             ; nl
    cmp al, 13
    je .mark_ws             ; cr
    cmp al, 11
    je .mark_ws             ; vt
    cmp al, 12
    je .mark_ws             ; ff
    jmp .after_ws
.mark_ws:
    mov bl, 1
.after_ws:
    cmp bl, 1
    je .sep_char
    ; non-whitespace
    cmp r14, 1
    je .adv
    ; starting a new word
    mov r14, 1
    inc r15
    jmp .adv
.sep_char:
    mov r14, 0
.adv:
    inc r12
    jmp .tw_loop
.tw_done:
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_out_total
    mov rdx, wc_len_out_total
    syscall
    mov rdi, r15
    lea rsi, [rel wc_num]
    call wc_u64_to_dec
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel wc_num]
    mov rdx, rax
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, wc_nl
    mov rdx, wc_len_nl
    syscall
    jmp .done

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; helpers
wc_eq_ci_len:
    push rbp
    mov rbp, rsp
    test rcx, rcx
    jz .yes
.loop:
    mov dl, [rdi]
    mov bl, [rsi]
    cmp dl, 'A'
    jb .d1
    cmp dl, 'Z'
    ja .d1
    add dl, 32
.d1:
    cmp bl, 'A'
    jb .d2
    cmp bl, 'Z'
    ja .d2
    add bl, 32
.d2:
    cmp dl, bl
    jne .no
    inc rdi
    inc rsi
    dec rcx
    jnz .loop
.yes:
    mov rax, 1
    jmp .ret
.no:
    xor rax, rax
.ret:
    pop rbp
    ret

wc_u64_to_dec:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push r10
    mov rax, rdi
    lea rbx, [rsi+31]
    mov byte [rbx], 0
    mov rcx, 0
    cmp rax, 0
    jne .conv
    mov byte [rsi], '0'
    mov rax, 1
    jmp .done
.conv:
.loop:
    xor rdx, rdx
    mov r10, 10
    div r10
    add dl, '0'
    dec rbx
    mov [rbx], dl
    inc rcx
    test rax, rax
    jnz .loop
    mov rax, rcx
    mov r8, rax
    xor r9, r9
.copy:
    mov dl, [rbx + r9]
    mov [rsi + r9], dl
    inc r9
    cmp r9, r8
    jne .copy
.done:
    pop r10
    pop rdx
    pop rbx
    pop rbp
    ret
