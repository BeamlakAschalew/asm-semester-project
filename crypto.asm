; Caesar Cipher - NASM x86_64 Linux (simplified)
; - Shift only A-Z and a-z
; - Shift factor 1..9 (defaults to 1 if invalid)

BITS 64

SECTION .data
cr_prompt_text:   db 'Enter text (Ctrl+D to finish):',10
cr_len_prompt_text equ $-cr_prompt_text
cr_prompt_shift:  db 'Shift (1-9): '
cr_len_prompt_shift equ $-cr_prompt_shift

SECTION .bss
cr_text: resb 65536     ; input/output buffer
cr_len:  resq 1         ; total bytes read
cr_in:   resb 4         ; small input buffer for shift

SECTION .text
global crypto_main

crypto_main:
    push rbp
    mov rbp, rsp
    push rbx                          ; save callee-saved

    ; prompt for text
    mov rax, 1                        ; sys_write
    mov rdi, 1                        ; stdout
    mov rsi, cr_prompt_text
    mov rdx, cr_len_prompt_text
    syscall

    ; read text (until EOF or buffer full)
    xor rbx, rbx                      ; total read = 0
.read_loop:
    mov rax, 0                        ; sys_read
    mov rdi, 0                        ; stdin
    lea rsi, [rel cr_text]
    add rsi, rbx                      ; write at end
    mov rdx, 65536
    sub rdx, rbx                      ; remaining capacity
    cmp rdx, 0
    je .read_done
    syscall
    test rax, rax
    jz .read_done                     ; EOF
    js .read_done                     ; error
    add rbx, rax
    cmp rbx, 65536
    jb .read_loop
.read_done:
    mov [cr_len], rbx                 ; save length

    ; prompt for shift
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_prompt_shift
    mov rdx, cr_len_prompt_shift
    syscall

    ; read shift (up to 4 bytes)
    mov rax, 0
    mov rdi, 0
    mov rsi, cr_in
    mov rdx, 4
    syscall

    ; parse first char as digit '1'..'9' (default 1 if invalid)
    mov al, [cr_in]
    mov r8d, 1                        ; default shift = 1
    cmp al, '1'
    jb .shift_ok
    cmp al, '9'
    ja .shift_ok
    movzx r8d, al
    sub r8d, '0'                      ; r8d = 1..9
.shift_ok:

    ; transform in-place
    xor rbx, rbx                      ; i = 0
    mov rcx, [cr_len]                 ; n
.transform_loop:
    cmp rbx, rcx
    jae .write_out

    mov dl, [cr_text + rbx]

    ; uppercase A..Z
    cmp dl, 'A'
    jb .check_lower
    cmp dl, 'Z'
    ja .check_lower
    mov al, dl
    add al, r8b                       ; shift
    cmp al, 'Z'
    jle .store_char
    sub al, 26
    jmp .store_char

.check_lower:
    ; lowercase a..z
    cmp dl, 'a'
    jb .next_char
    cmp dl, 'z'
    ja .next_char
    mov al, dl
    add al, r8b
    cmp al, 'z'
    jle .store_char
    sub al, 26
    jmp .store_char

.store_char:
    mov [cr_text + rbx], al

.next_char:
    inc rbx
    jmp .transform_loop

.write_out:
    ; write entire transformed buffer once
    mov rax, 1
    mov rdi, 1
    mov rsi, cr_text
    mov rdx, rcx
    syscall

    pop rbx
    pop rbp
    ret
