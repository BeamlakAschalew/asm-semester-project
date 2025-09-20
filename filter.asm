; Filter characters - NASM x86_64 Linux (module)
; Exposes: filter_main

BITS 64

SECTION .data
ft_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
ft_len_banner_top equ $-ft_banner_top
ft_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃              Character Filter (ASM)         ┃',10
ft_len_banner_mid equ $-ft_banner_mid
ft_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
ft_len_banner_bot equ $-ft_banner_bot
ft_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
ft_len_prompt_text equ $-ft_prompt_text
ft_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Digits  [2] Letters  [3] Punctuation  [4] Remove chosen chars',10
ft_len_prompt_mode equ $-ft_prompt_mode
ft_prompt_remove: db 0x1B,'[1m','Characters to remove: ',0x1B,'[0m'
ft_len_prompt_remove equ $-ft_prompt_remove
ft_output_hdr: db 10,0x1B,'[1m','Filtered output:',0x1B,'[0m',10
ft_len_output_hdr equ $-ft_output_hdr

SECTION .bss
ft_text: resb 65536
ft_len:  resq 1
ft_in:   resb 4
ft_rmset: resb 256
ft_rmlen: resq 1

SECTION .text
global filter_main

filter_main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    ; banner
    mov rax, 1
    mov rdi, 1
    mov rsi, ft_banner_top
    mov rdx, ft_len_banner_top
    syscall
    mov rsi, ft_banner_mid
    mov rdx, ft_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, ft_banner_bot
    mov rdx, ft_len_banner_bot
    mov rax, 1
    syscall

    ; read text
    mov rax, 1
    mov rdi, 1
    mov rsi, ft_prompt_text
    mov rdx, ft_len_prompt_text
    syscall
    xor rbx, rbx
.rloop:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ft_text]
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
    mov [ft_len], rbx

    ; mode
    mov rax, 1
    mov rdi, 1
    mov rsi, ft_prompt_mode
    mov rdx, ft_len_prompt_mode
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, ft_in
    mov rdx, 2
    syscall
    mov al, [ft_in]
    mov bl, 1           ; default digits
    cmp al, '2'
    jne .chk3
    mov bl, 2           ; letters
    jmp .have_mode
.chk3:
    cmp al, '3'
    jne .have_mode
    mov bl, 3           ; punctuation
.have_mode:

    ; if remove-chosen mode, read removal set
    cmp al, '4'
    jne .after_remove_input
    mov bl, 4           ; mark mode 4
    mov rax, 1
    mov rdi, 1
    mov rsi, ft_prompt_remove
    mov rdx, ft_len_prompt_remove
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ft_rmset]
    mov rdx, 255
    syscall
    ; strip trailing newline
    mov rcx, rax
    test rcx, rcx
    jz .setrmlen
    dec rcx
    jl .setrmlen
    mov dl, [ft_rmset + rcx]
    cmp dl, 10
    jne .setrmlen2
    mov rax, rcx
    jmp .setrmlen
.setrmlen2:
    mov rax, rcx
    inc rax
.setrmlen:
    mov [ft_rmlen], rax
.after_remove_input:

    ; output header
    mov rax, 1
    mov rdi, 1
    mov rsi, ft_output_hdr
    mov rdx, ft_len_output_hdr
    syscall

    ; filter
    xor r12, r12
    mov r13, [ft_len]
.floop:
    cmp r12, r13
    jae .done
    mov dl, [ft_text + r12]
    ; digits
    cmp bl, 1
    jne .chk_letters
    cmp dl, '0'
    jb .next
    cmp dl, '9'
    ja .next
    jmp .emit
.chk_letters:
    cmp bl, 2
    jne .chk_punct
    ; A-Z a-z only
    cmp dl, 'A'
    jb .chk_a2
    cmp dl, 'Z'
    jbe .emit
.chk_a2:
    cmp dl, 'a'
    jb .next
    cmp dl, 'z'
    jbe .emit
    jmp .next
.chk_punct:
    ; punctuation (printables excluding letters, digits, space)
    cmp bl, 4
    je .chk_remove
    cmp dl, 32
    jb .next
    cmp dl, 126
    ja .next
    ; exclude letters
    cmp dl, 'A'
    jb .chk_la2
    cmp dl, 'Z'
    jbe .next
.chk_la2:
    cmp dl, 'a'
    jb .chk_ld
    cmp dl, 'z'
    jbe .next
.chk_ld:
    cmp dl, '0'
    jb .chk_space
    cmp dl, '9'
    jbe .next
.chk_space:
    cmp dl, ' '
    je .next
    jmp .emit

.chk_remove:
    ; mode 4: remove any character present in removal set
    mov rcx, [ft_rmlen]
    cmp rcx, 0
    je .emit            ; nothing to remove => pass-through
    lea rsi, [rel ft_rmset]
.rm_loop:
    cmp rcx, 0
    je .emit
    mov al, [rsi]
    cmp al, dl
    je .next            ; skip emitting this char
    inc rsi
    dec rcx
    jmp .rm_loop

.emit:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ft_text]
    mov [ft_text], dl   ; reuse buffer to hold single byte
    mov rsi, ft_text
    mov rdx, 1
    syscall
.next:
    inc r12
    jmp .floop

.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
