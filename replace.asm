; Replace Substring - NASM x86_64 Linux (module)
; Exposes: replace_main

BITS 64

SECTION .data
rp_reset: db 0x1B,'[0m'
rp_len_reset equ $-rp_reset
rp_bold:  db 0x1B,'[1m'
rp_len_bold equ $-rp_bold
rp_cyan:  db 0x1B,'[36m'
rp_len_cyan equ $-rp_cyan
rp_hl:    db 0x1B,'[30;42m'   ; black on green background
rp_len_hl equ $-rp_hl
rp_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
rp_len_banner_top equ $-rp_banner_top
rp_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃           Replace Substring (ASM)           ┃',10
rp_len_banner_mid equ $-rp_banner_mid
rp_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
rp_len_banner_bot equ $-rp_banner_bot
rp_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
rp_len_prompt_text equ $-rp_prompt_text
rp_prompt_target: db 10,0x1B,'[1m','Target substring: ',0x1B,'[0m'
rp_len_prompt_target equ $-rp_prompt_target
rp_prompt_repl:   db 0x1B,'[1m','Replacement: ',0x1B,'[0m'
rp_len_prompt_repl equ $-rp_prompt_repl
rp_output_hdr: db 10,0x1B,'[1m','Output:',0x1B,'[0m',10
rp_len_output_hdr equ $-rp_output_hdr
rp_warn_empty: db 0x1B,'[31m','Target is empty. Nothing to replace.',0x1B,'[0m',10
rp_len_warn_empty equ $-rp_warn_empty

SECTION .bss
rp_text:   resb 65536
rp_textlen: resq 1
rp_target: resb 256
rp_tlen:   resq 1
rp_repl:   resb 256
rp_rlen:   resq 1

SECTION .text
global replace_main

replace_main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Banner
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_banner_top
    mov rdx, rp_len_banner_top
    syscall
    mov rsi, rp_banner_mid
    mov rdx, rp_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, rp_banner_bot
    mov rdx, rp_len_banner_bot
    mov rax, 1
    syscall

    ; Prompt and read text (EOF to finish)
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_text
    mov rdx, rp_len_prompt_text
    syscall

    xor rbx, rbx
.rread:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_text]
    add rsi, rbx
    mov rdx, 65536
    sub rdx, rbx
    cmp rdx, 0
    je .rread_done
    syscall
    test rax, rax
    jz .rread_done
    js .rread_done
    add rbx, rax
    cmp rbx, 65536
    jb .rread
.rread_done:
    mov [rp_textlen], rbx

    ; Target prompt
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_target
    mov rdx, rp_len_prompt_target
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_target]
    mov rdx, 255
    syscall
    ; compute tlen minus newline if present
    mov rcx, rax
    test rcx, rcx
    jz .tlen_set
    dec rcx
    jl .tlen_set
    mov al, [rp_target + rcx]
    cmp al, 10
    jne .tlen_set2
    mov rax, rcx
    jmp .tlen_set
.tlen_set2:
    mov rax, rcx
    inc rax
.tlen_set:
    mov [rp_tlen], rax

    ; Replacement prompt
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_repl
    mov rdx, rp_len_prompt_repl
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_repl]
    mov rdx, 255
    syscall
    mov rcx, rax
    test rcx, rcx
    jz .rlen_set
    dec rcx
    jl .rlen_set
    mov al, [rp_repl + rcx]
    cmp al, 10
    jne .rlen_set2
    mov rax, rcx
    jmp .rlen_set
.rlen_set2:
    mov rax, rcx
    inc rax
.rlen_set:
    mov [rp_rlen], rax

    ; If target len == 0 -> warn and return
    cmp qword [rp_tlen], 0
    jne .do_output
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_warn_empty
    mov rdx, rp_len_warn_empty
    syscall
    jmp .done

.do_output:
    ; header
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_output_hdr
    mov rdx, rp_len_output_hdr
    syscall

    xor r12, r12                 ; i
    mov r13, [rp_textlen]
    mov r14, [rp_tlen]
    mov r15, [rp_rlen]

.loop:
    cmp r12, r13
    jae .end_output
    ; remaining < tlen ? print rest
    mov rax, r13
    sub rax, r12
    cmp rax, r14
    jb .print_rest
    ; compare at i
    push r12
    push r13
    push r14
    mov rdi, rp_text
    add rdi, r12
    mov rsi, rp_target
    mov rcx, r14
    call rp_eq_len
    pop r14
    pop r13
    pop r12
    cmp rax, 1
    jne .no_match
    ; print highlighted replacement
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_hl
    mov rdx, rp_len_hl
    syscall
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_repl]
    mov rdx, r15
    syscall
    ; reset
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_reset
    mov rdx, rp_len_reset
    syscall
    add r12, r14
    jmp .loop
.no_match:
    ; print one char
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_text]
    add rsi, r12
    mov rdx, 1
    syscall
    inc r12
    jmp .loop
.print_rest:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_text]
    add rsi, r12
    mov rdx, r13
    sub rdx, r12
    syscall
    mov r12, r13
    jmp .end_output
.end_output:
    ; done

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; rp_eq_len(rdi=ptr1, rsi=ptr2, rcx=len) -> rax=1 if equal else 0
rp_eq_len:
    push rbp
    mov rbp, rsp
    test rcx, rcx
    jz .yes
.cmp:
    mov al, [rdi]
    mov bl, [rsi]
    cmp al, bl
    jne .no
    inc rdi
    inc rsi
    dec rcx
    jnz .cmp
.yes:
    mov rax, 1
    jmp .ret
.no:
    xor rax, rax
.ret:
    pop rbp
    ret
