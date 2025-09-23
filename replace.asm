; Replace Substring - NASM x86_64 Linux (simplified)
; Exposes: replace_main (read text/target/replacement, replace non-overlapping matches, highlight replacements)

BITS 64

SECTION .data
rp_prompt_text:   db 'Enter text (Ctrl+D to finish):',10
rp_len_prompt_text equ $-rp_prompt_text
rp_prompt_target: db 'Target: '
rp_len_prompt_target equ $-rp_prompt_target
rp_prompt_repl:   db 'Replacement: '
rp_len_prompt_repl equ $-rp_prompt_repl
rp_output_hdr:    db 10,'Output:',10
rp_len_output_hdr equ $-rp_output_hdr
rp_hl:            db 0x1B,'[30;42m'
rp_len_hl         equ $-rp_hl
rp_reset:         db 0x1B,'[0m'
rp_len_reset      equ $-rp_reset

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
    push rbx                       ; preserve callee-saved we use

    ; prompt + read text (single read, simple)
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_text
    mov rdx, rp_len_prompt_text
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_text]
    mov rdx, 65536
    syscall
    mov [rp_textlen], rax

    ; prompt + read target
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_target
    mov rdx, rp_len_prompt_target
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_target]
    mov rdx, 256
    syscall
    mov rcx, rax                 ; bytes read
    test rcx, rcx
    jz .tlen_set
    dec rcx
    jl .tlen_set
    mov al, [rp_target + rcx]
    cmp al, 10
    jne .tlen_inc
    mov rax, rcx
    jmp .tlen_set
.tlen_inc:
    mov rax, rcx
    inc rax
.tlen_set:
    mov [rp_tlen], rax

    ; prompt + read replacement
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_prompt_repl
    mov rdx, rp_len_prompt_repl
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel rp_repl]
    mov rdx, 256
    syscall
    mov rcx, rax
    test rcx, rcx
    jz .rlen_set
    dec rcx
    jl .rlen_set
    mov al, [rp_repl + rcx]
    cmp al, 10
    jne .rlen_inc
    mov rax, rcx
    jmp .rlen_set
.rlen_inc:
    mov rax, rcx
    inc rax
.rlen_set:
    mov [rp_rlen], rax

    ; header
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_output_hdr
    mov rdx, rp_len_output_hdr
    syscall

    ; if target empty -> just print text
    cmp qword [rp_tlen], 0
    jne .process
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_text]
    mov rdx, [rp_textlen]
    syscall
    jmp .done

.process:
    xor rbx, rbx                 ; i = 0
    mov r10, [rp_textlen]        ; text len
    mov r8,  [rp_tlen]           ; tlen
    mov r9,  [rp_rlen]           ; rlen

.loop:
    cmp rbx, r10
    jae .done
    ; if remaining < tlen, print rest and finish
    mov r11, r10
    sub r11, rbx
    cmp r11, r8
    jb .rest

    ; compare text[i..i+tlen) with target
    xor rdx, rdx                 ; k = 0
.cmp_loop:
    mov al, [rp_text + rbx + rdx]
    cmp al, [rp_target + rdx]
    jne .no_match
    inc rdx
    cmp rdx, r8
    jb .cmp_loop
    ; match -> print highlight + replacement
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_hl
    mov rdx, rp_len_hl
    syscall
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_repl]
    mov rdx, r9
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, rp_reset
    mov rdx, rp_len_reset
    syscall
    add rbx, r8
    jmp .loop

.no_match:
    ; print one char
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_text]
    add rsi, rbx
    mov rdx, 1
    syscall
    inc rbx
    jmp .loop

.rest:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel rp_text]
    add rsi, rbx
    mov rdx, r11
    syscall
    jmp .done

.done:
    pop rbx
    pop rbp
    ret
