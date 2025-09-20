; Crypto (Caesar / XOR) - NASM x86_64 Linux (module)
; Exposes: crypto_main

BITS 64

SECTION .data
cr_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
cr_len_banner_top equ $-cr_banner_top
cr_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃                 Crypto Tools (ASM)          ┃',10
cr_len_banner_mid equ $-cr_banner_mid
cr_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
cr_len_banner_bot equ $-cr_banner_bot
cr_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
cr_len_prompt_text equ $-cr_prompt_text
cr_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Caesar  [2] XOR',10
cr_len_prompt_mode equ $-cr_prompt_mode
cr_prompt_shift: db 0x1B,'[1m','Caesar shift (-25..25): ',0x1B,'[0m'
cr_len_prompt_shift equ $-cr_prompt_shift
cr_prompt_key: db 0x1B,'[1m','XOR key (single byte 0-255): ',0x1B,'[0m'
cr_len_prompt_key equ $-cr_prompt_key
cr_output_hdr: db 10,0x1B,'[1m','Result:',0x1B,'[0m',10
cr_len_output_hdr equ $-cr_output_hdr

SECTION .bss
cr_text: resb 65536
cr_len:  resq 1
cr_in:   resb 16

SECTION .text
global crypto_main

crypto_main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    ; banner
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_banner_top
    mov rdx, cr_len_banner_top
    syscall
    mov rsi, cr_banner_mid
    mov rdx, cr_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, cr_banner_bot
    mov rdx, cr_len_banner_bot
    mov rax, 1
    syscall

    ; read text
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_prompt_text
    mov rdx, cr_len_prompt_text
    syscall
    xor rbx, rbx
.rloop:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel cr_text]
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
    mov [cr_len], rbx

    ; mode
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_prompt_mode
    mov rdx, cr_len_prompt_mode
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, cr_in
    mov rdx, 4
    syscall
    mov al, [cr_in]
    cmp al, '2'
    je .xor
    ; Caesar default
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_prompt_shift
    mov rdx, cr_len_prompt_shift
    syscall
    ; read shift line, parse small int [-25..25]
    mov rax, 0
    mov rdi, 0
    mov rsi, cr_in
    mov rdx, 8
    syscall
    ; simplistic parse: first char optional '-' then digits
    xor r12, r12
    mov bl, [cr_in]
    mov dl, 0        ; sign 0=+ 1=-
    cmp bl, '-'
    jne .parse_d
    mov dl, 1
    mov bl, [cr_in+1]
.parse_d:
    xor eax, eax
.ps_loop:
    cmp bl, '0'
    jb .ps_done
    cmp bl, '9'
    ja .ps_done
    imul eax, eax, 10
    mov r12d, ebx
    sub r12d, '0'
    add eax, r12d
    mov bl, [cr_in+1]
    mov byte [cr_in], bl
    mov bl, [cr_in]
    jmp .ps_loop
.ps_done:
    cmp dl, 0
    je .have_shift
    neg eax
.have_shift:
    ; Caesar transform letters only (preserve case)
    mov r12, 0
    mov r13, [cr_len]
    mov r14d, eax
    ; normalize shift to [-25..25]
    ; output header
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_output_hdr
    mov rdx, cr_len_output_hdr
    syscall
.caesar_loop:
    cmp r12, r13
    jae .done
    mov dl, [cr_text + r12]
    ; uppercase
    cmp dl, 'A'
    jb .chk_low
    cmp dl, 'Z'
    ja .chk_low
    mov eax, edx
    sub eax, 'A'
    add eax, r14d
    ; mod 26 with wrap
    mov ecx, 26
    idiv ecx      ; eax=quot, edx=rem
    mov eax, edx
    cmp eax, 0
    jge .uc_ok
    add eax, 26
.uc_ok:
    add eax, 'A'
    mov dl, al
    jmp .emit
.chk_low:
    cmp dl, 'a'
    jb .emit
    cmp dl, 'z'
    ja .emit
    mov eax, edx
    sub eax, 'a'
    add eax, r14d
    mov ecx, 26
    idiv ecx
    mov eax, edx
    cmp eax, 0
    jge .lc_ok
    add eax, 26
.lc_ok:
    add eax, 'a'
    mov dl, al
.emit:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel cr_text]
    mov [cr_text], dl
    mov rsi, cr_text
    mov rdx, 1
    syscall
    inc r12
    jmp .caesar_loop

.xor:
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_prompt_key
    mov rdx, cr_len_prompt_key
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, cr_in
    mov rdx, 8
    syscall
    ; parse first number token (0-255)
    xor eax, eax
    mov bl, [cr_in]
.px_loop:
    cmp bl, '0'
    jb .px_done
    cmp bl, '9'
    ja .px_done
    imul eax, eax, 10
    mov r12d, ebx
    sub r12d, '0'
    add eax, r12d
    mov bl, [cr_in+1]
    mov byte [cr_in], bl
    mov bl, [cr_in]
    jmp .px_loop
.px_done:
    and eax, 0xFF
    mov r12d, eax          ; key
    ; output header
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_output_hdr
    mov rdx, cr_len_output_hdr
    syscall
    ; XOR transform on all bytes
    xor r13, r13
    mov r14, [cr_len]
.xor_loop:
    cmp r13, r14
    jae .done
    mov dl, [cr_text + r13]
    xor dl, r12b
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel cr_text]
    mov [cr_text], dl
    mov rsi, cr_text
    mov rdx, 1
    syscall
    inc r13
    jmp .xor_loop

.done:
    pop r12
    pop rbx
    pop rbp
    ret
