; Text Search Highlighter - NASM x86_64 Linux (simplified)
; Exposes: text_search_main

BITS 64

SECTION .data
ts_prompt_text: db 'Enter text (Ctrl+D to finish):',10
ts_len_prompt_text equ $-ts_prompt_text
ts_prompt_kw:   db 'Keyword: '
ts_len_prompt_kw equ $-ts_prompt_kw
ts_output_hdr:  db 10,'Output:',10
ts_len_output_hdr equ $-ts_output_hdr
ts_summary1:    db 10,'Matches found: '
ts_len_summary1 equ $-ts_summary1
ts_nl:          db 10
ts_len_nl       equ $-ts_nl
ts_hl_on:       db 0x1B,'[30;43m'
ts_len_hl_on    equ $-ts_hl_on
ts_reset:       db 0x1B,'[0m'
ts_len_reset    equ $-ts_reset
ts_warn_empty:  db 'Keyword is empty.',10
ts_len_warn_empty equ $-ts_warn_empty

SECTION .bss
ts_text_buf:  resb 65536
ts_text_len:  resq 1
ts_kw_buf:    resb 256
ts_kw_len:    resq 1
ts_num_buf:   resb 32

SECTION .text
global text_search_main

text_search_main:
    push rbp
    mov rbp, rsp
    push rbx

    ; prompt + read text (single read)
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_prompt_text
    mov rdx, ts_len_prompt_text
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ts_text_buf]
    mov rdx, 65536
    syscall
    mov [ts_text_len], rax

    ; prompt + read keyword
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_prompt_kw
    mov rdx, ts_len_prompt_kw
    syscall
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ts_kw_buf]
    mov rdx, 256
    syscall
    mov rcx, rax
    test rcx, rcx
    jz .kw_set
    dec rcx
    jl .kw_set
    mov al, [ts_kw_buf + rcx]
    cmp al, 10
    jne .kw_inc
    mov rax, rcx
    jmp .kw_set
.kw_inc:
    mov rax, rcx
    inc rax
.kw_set:
    mov [ts_kw_len], rax

    ; if empty keyword -> warn and return
    cmp qword [ts_kw_len], 0
    jne .hdr
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_warn_empty
    mov rdx, ts_len_warn_empty
    syscall
    jmp .done

.hdr:
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_output_hdr
    mov rdx, ts_len_output_hdr
    syscall

    xor rbx, rbx                 ; match count = 0 (use rbx; syscall-safe)
    xor r10, r10                 ; i = 0
    mov r11, [ts_text_len]       ; textlen
    mov r8,  [ts_kw_len]         ; kwlen

    ; if kwlen > textlen: print all and skip search
    cmp r8, r11
    jbe .search
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    mov rdx, r11
    syscall
    jmp .summary

.search:
    cmp r10, r11
    jae .summary
    ; remaining < kwlen?
    mov r9, r11
    sub r9, r10
    cmp r9, r8
    jb .rest

    ; compare at i, case-insensitive
    xor rdx, rdx               ; k = 0
.cmp_loop:
    mov al, [ts_text_buf + r10 + rdx]
    mov r9b, [ts_kw_buf + rdx]
    ; tolower al
    cmp al, 'A'
    jb .al_ok
    cmp al, 'Z'
    ja .al_ok
    add al, 32
.al_ok:
    ; tolower r9b
    cmp r9b, 'A'
    jb .bl_ok
    cmp r9b, 'Z'
    ja .bl_ok
    add r9b, 32
.bl_ok:
    cmp al, r9b
    jne .no_match
    inc rdx
    cmp rdx, r8
    jb .cmp_loop
    ; match -> print highlight + keyword + reset, advance i += kwlen, count++
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_hl_on
    mov rdx, ts_len_hl_on
    syscall
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_kw_buf]
    mov rdx, r8
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_reset
    mov rdx, ts_len_reset
    syscall
    add r10, r8
    inc rbx
    jmp .search

.no_match:
    ; print one char and i++
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    add rsi, r10
    mov rdx, 1
    syscall
    inc r10
    jmp .search

.rest:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    add rsi, r10
    mov rdx, r9
    syscall
    jmp .summary

.summary:
    ; print summary label
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_summary1
    mov rdx, ts_len_summary1
    syscall
    ; convert rcx (count) to decimal in ts_num_buf and write
    mov rax, rbx                 ; value to print
    lea rbx, [rel ts_num_buf]    ; buffer base
    lea rdi, [rbx+32]            ; one past end
    cmp rax, 0
    jne .conv
    ; zero special-case
    mov byte [rbx+31], '0'
    lea rsi, [rbx+31]
    mov rdx, 1
    jmp .write_num
.conv:
    ; write digits backwards into buffer
.conv_loop:
    xor rdx, rdx
    mov r8, 10
    div r8                    ; rax = rax/10, rdx = remainder
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .conv_loop
    ; rdi points to first digit, compute len and ptr
    mov rsi, rdi
    lea rax, [rbx+32]
    sub rax, rdi
    mov rdx, rax
.write_num:
    mov rax, 1
    mov rdi, 1
    syscall
    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_nl
    mov rdx, ts_len_nl
    syscall

.done:
    pop rbx
    pop rbp
    ret
