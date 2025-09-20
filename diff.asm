; Diff Tool - NASM x86_64 Linux (module)
; Exposes: diff_main

BITS 64

SECTION .data
df_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
df_len_banner_top equ $-df_banner_top
df_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃                  Diff Tool (ASM)            ┃',10
df_len_banner_mid equ $-df_banner_mid
df_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
df_len_banner_bot equ $-df_banner_bot
df_prompt_a: db 0x1B,'[1m','Enter first text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
df_len_prompt_a equ $-df_prompt_a
df_prompt_b: db 10,0x1B,'[1m','Enter second text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
df_len_prompt_b equ $-df_prompt_b
df_out_a: db 10,0x1B,'[1m','A: ',0x1B,'[0m'
df_len_out_a equ $-df_out_a
df_out_b: db 10,0x1B,'[1m','B: ',0x1B,'[0m'
df_len_out_b equ $-df_out_b
df_hl_add: db 0x1B,'[30;42m'   ; additions (present in B) green
df_len_hl_add equ $-df_hl_add
df_hl_del: db 0x1B,'[30;41m'   ; deletions (present in A) red
df_len_hl_del equ $-df_hl_del
df_reset: db 0x1B,'[0m'
df_len_reset equ $-df_reset
df_nl: db 10
df_len_nl equ $-df_nl

SECTION .bss
df_a:  resb 65536
df_al: resq 1
df_b:  resb 65536
df_bl: resq 1
df_tmp: resb 1

SECTION .text
global diff_main

diff_main:
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
    mov rsi, df_banner_top
    mov rdx, df_len_banner_top
    syscall
    mov rsi, df_banner_mid
    mov rdx, df_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, df_banner_bot
    mov rdx, df_len_banner_bot
    mov rax, 1
    syscall

    ; read A
    mov rax, 1
    mov rdi, 1
    mov rsi, df_prompt_a
    mov rdx, df_len_prompt_a
    syscall
    xor rbx, rbx
.ra:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel df_a]
    add rsi, rbx
    mov rdx, 65536
    sub rdx, rbx
    cmp rdx, 0
    je .ra_done
    syscall
    test rax, rax
    jz .ra_done
    js .ra_done
    add rbx, rax
    cmp rbx, 65536
    jb .ra
.ra_done:
    mov [df_al], rbx

    ; read B
    mov rax, 1
    mov rdi, 1
    mov rsi, df_prompt_b
    mov rdx, df_len_prompt_b
    syscall
    xor rbx, rbx
.rb:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel df_b]
    add rsi, rbx
    mov rdx, 65536
    sub rdx, rbx
    cmp rdx, 0
    je .rb_done
    syscall
    test rax, rax
    jz .rb_done
    js .rb_done
    add rbx, rax
    cmp rbx, 65536
    jb .rb
.rb_done:
    mov [df_bl], rbx

    ; print A line
    mov rax, 1
    mov rdi, 1
    mov rsi, df_out_a
    mov rdx, df_len_out_a
    syscall
    ; walk both buffers, print A char; if A!=B char at pos, highlight deletion while printing A
    xor r12, r12
    mov r13, [df_al]
    mov r14, [df_bl]
.pa:
    cmp r12, r13
    jae .a_done
    mov dl, [df_a + r12]
    ; compare with B at same pos if exists
    mov bl, 0
    cmp r12, r14
    jae .no_b
    mov bl, [df_b + r12]
.no_b:
    cmp dl, bl
    je .emit_a
    ; mismatch -> deletion from A
    mov rax, 1
    mov rdi, 1
    mov rsi, df_hl_del
    mov rdx, df_len_hl_del
    syscall
.emit_a:
    mov [df_tmp], dl
    mov rax, 1
    mov rdi, 1
    mov rsi, df_tmp
    mov rdx, 1
    syscall
    ; reset if mismatch
    cmp dl, bl
    je .next_a
    mov rax, 1
    mov rdi, 1
    mov rsi, df_reset
    mov rdx, df_len_reset
    syscall
.next_a:
    inc r12
    jmp .pa
.a_done:
    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, df_nl
    mov rdx, df_len_nl
    syscall

    ; print B line
    mov rax, 1
    mov rdi, 1
    mov rsi, df_out_b
    mov rdx, df_len_out_b
    syscall
    xor r12, r12
.pb:
    cmp r12, r14
    jae .done
    mov dl, [df_b + r12]
    mov bl, 0
    cmp r12, r13
    jae .no_a
    mov bl, [df_a + r12]
.no_a:
    cmp dl, bl
    je .emit_b
    ; addition in B
    mov rax, 1
    mov rdi, 1
    mov rsi, df_hl_add
    mov rdx, df_len_hl_add
    syscall
.emit_b:
    mov [df_tmp], dl
    mov rax, 1
    mov rdi, 1
    mov rsi, df_tmp
    mov rdx, 1
    syscall
    cmp dl, bl
    je .next_b
    mov rax, 1
    mov rdi, 1
    mov rsi, df_reset
    mov rdx, df_len_reset
    syscall
.next_b:
    inc r12
    jmp .pb

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
