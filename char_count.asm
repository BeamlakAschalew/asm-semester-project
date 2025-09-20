; Character Count - NASM x86_64 Linux (module)
; Exposes: char_count_main

BITS 64

SECTION .data
cc_reset: db 0x1B,'[0m'
cc_len_reset equ $-cc_reset
cc_bold:  db 0x1B,'[1m'
cc_len_bold equ $-cc_bold
cc_cyan:  db 0x1B,'[36m'
cc_len_cyan equ $-cc_cyan
cc_dim:   db 0x1B,'[90m'
cc_len_dim equ $-cc_dim
cc_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
cc_len_banner_top equ $-cc_banner_top
cc_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃            Character Count (ASM)            ┃',10
cc_len_banner_mid equ $-cc_banner_mid
cc_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
cc_len_banner_bot equ $-cc_banner_bot
cc_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
cc_len_prompt_text equ $-cc_prompt_text
cc_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Specific char  [2] All chars',10
cc_len_prompt_mode equ $-cc_prompt_mode
cc_prompt_char: db 0x1B,'[1m','Character to count: ',0x1B,'[0m'
cc_len_prompt_char equ $-cc_prompt_char
cc_result1: db 10,0x1B,'[1m','Count: ',0x1B,'[0m'
cc_len_result1 equ $-cc_result1
cc_nl: db 10
cc_len_nl equ $-cc_nl

SECTION .bss
cc_text:   resb 65536
cc_len:    resq 1
cc_counts: resd 256       ; frequency table
cc_num:    resb 32
cc_inbuf:  resb 8
cc_ch:     resb 1
cc_colonsp: resb 2

SECTION .text
global char_count_main

char_count_main:
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
    mov rsi, cc_banner_top
    mov rdx, cc_len_banner_top
    syscall
    mov rsi, cc_banner_mid
    mov rdx, cc_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, cc_banner_bot
    mov rdx, cc_len_banner_bot
    mov rax, 1
    syscall

    ; prompt text
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_prompt_text
    mov rdx, cc_len_prompt_text
    syscall

    ; read text
    xor rbx, rbx
.rloop:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel cc_text]
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
    mov [cc_len], rbx

    ; prompt mode
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_prompt_mode
    mov rdx, cc_len_prompt_mode
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, cc_inbuf
    mov rdx, 2
    syscall
    mov al, [cc_inbuf]
    cmp al, '1'
    je .mode_one
    ; default: mode two
.mode_two:
    ; zero counts
    lea rdi, [rel cc_counts]
    mov rcx, 256
    xor eax, eax
    rep stosd
    ; count all
    xor r12, r12
    mov r13, [cc_len]
.cnt_all:
    cmp r12, r13
    jae .show_all
    mov bl, [cc_text + r12]
    movzx rbx, bl
    mov edi, [cc_counts + rbx*4]
    add edi, 1
    mov [cc_counts + rbx*4], edi
    inc r12
    jmp .cnt_all
.show_all:
    ; dump printable ASCII (32..126)
    mov r12, 32
.dump_loop:
    cmp r12, 126
    ja .done
    mov edi, [cc_counts + r12*4]
    test edi, edi
    jz .next
    ; print char
    mov byte [cc_ch], r12b
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_ch
    mov rdx, 1
    syscall
    ; print ": "
    mov byte [cc_colonsp], ':'
    mov byte [cc_colonsp+1], ' '
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_colonsp
    mov rdx, 2
    syscall
    ; number
    mov edi, [cc_counts + r12*4]
    lea rsi, [rel cc_num]
    call cc_u64_to_dec
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel cc_num]
    mov rdx, rax
    syscall
    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_nl
    mov rdx, cc_len_nl
    syscall
.next:
    inc r12
    jmp .dump_loop

.mode_one:
    ; ask char
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_prompt_char
    mov rdx, cc_len_prompt_char
    syscall
    mov rax, 0
    mov rdi, 0
    mov rsi, cc_inbuf
    mov rdx, 2
    syscall
    mov bl, [cc_inbuf]
    ; count
    xor r12, r12
    xor r13, r13
    mov r14, [cc_len]
.cnt_one:
    cmp r12, r14
    jae .show_one
    cmp bl, [cc_text + r12]
    jne .nx1
    inc r13
.nx1:
    inc r12
    jmp .cnt_one
.show_one:
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_result1
    mov rdx, cc_len_result1
    syscall
    ; print number r13
    mov rdi, r13
    lea rsi, [rel cc_num]
    call cc_u64_to_dec
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel cc_num]
    mov rdx, rax
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, cc_nl
    mov rdx, cc_len_nl
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

; local helper: cc_u64_to_dec(rdi=value, rsi=buf) -> rax=len
cc_u64_to_dec:
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
