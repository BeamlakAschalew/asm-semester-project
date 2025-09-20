; Text Search Highlighter - NASM x86_64 Linux (module)
; Exposes: text_search_main (no exit; returns to caller)

BITS 64

SECTION .data
; Colors (module-scoped with ts_ prefix to avoid collisions)
ts_reset:      db 0x1B, '[0m'
ts_len_reset   equ $-ts_reset
ts_bold:       db 0x1B, '[1m'
ts_len_bold    equ $-ts_bold
ts_dim:        db 0x1B, '[90m'
ts_len_dim     equ $-ts_dim
ts_cyan:       db 0x1B, '[36m'
ts_len_cyan    equ $-ts_cyan
ts_magenta:    db 0x1B, '[35m'
ts_len_magenta equ $-ts_magenta
ts_green:      db 0x1B, '[32m'
ts_len_green   equ $-ts_green
ts_red:        db 0x1B, '[31m'
ts_len_red     equ $-ts_red
ts_hl_on:      db 0x1B, '[30;43m'    ; black on yellow background
ts_len_hl_on   equ $-ts_hl_on

; UI strings
ts_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
ts_len_banner_top equ $-ts_banner_top
ts_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃        Text Search Highlighter (ASM)        ┃',10
ts_len_banner_mid equ $-ts_banner_mid
ts_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
ts_len_banner_bot equ $-ts_banner_bot

ts_prompt_text: db 0x1B,'[1m','Paste your text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10
ts_len_prompt_text equ $-ts_prompt_text

ts_prompt_kw:   db 10,0x1B,'[1m','Enter keyword to highlight: ',0x1B,'[0m'
ts_len_prompt_kw equ $-ts_prompt_kw

ts_output_hdr:  db 10,0x1B,'[1m','Output with highlights:',0x1B,'[0m',10
ts_len_output_hdr equ $-ts_output_hdr

ts_summary1:    db 10,0x1B,'[90m','Matches found: ',0x1B,'[0m'
ts_len_summary1 equ $-ts_summary1
ts_nl:          db 10
ts_len_nl       equ $-ts_nl

ts_warn_empty:  db 0x1B,'[31m','Keyword is empty. Nothing to highlight.',0x1B,'[0m',10
ts_len_warn_empty equ $-ts_warn_empty

SECTION .bss
ts_text_buf:  resb 65536
ts_text_len:  resq 1
ts_kw_buf:    resb 256
ts_kw_len:    resq 1
ts_num_buf:   resb 32

SECTION .text
global text_search_main

;-------------------------------------
; Entry
;-------------------------------------
text_search_main:
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
    mov rsi, ts_banner_top
    mov rdx, ts_len_banner_top
    syscall
    mov rsi, ts_banner_mid
    mov rdx, ts_len_banner_mid
    mov rax, 1
    syscall
    mov rsi, ts_banner_bot
    mov rdx, ts_len_banner_bot
    mov rax, 1
    syscall

    ; prompt for text
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_prompt_text
    mov rdx, ts_len_prompt_text
    syscall

    ; read until EOF or buffer full
    xor rbx, rbx               ; total len
.read_loop:
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ts_text_buf]
    add rsi, rbx
    mov rdx, 65536
    sub rdx, rbx               ; remaining
    cmp rdx, 0
    je .read_done
    syscall
    test rax, rax
    jz .read_done              ; EOF
    js .read_done              ; error -> stop
    add rbx, rax
    cmp rbx, 65536
    jb .read_loop
.read_done:
    mov [ts_text_len], rbx

    ; prompt for keyword
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_prompt_kw
    mov rdx, ts_len_prompt_kw
    syscall

    ; read keyword line (up to 255 bytes)
    mov rax, 0
    mov rdi, 0
    lea rsi, [rel ts_kw_buf]
    mov rdx, 255
    syscall
    ; rax = bytes read, strip trailing newline
    xor rcx, rcx
    test rax, rax
    jz .kw_len_set
    mov rcx, rax
    dec rcx
    jl .kw_len_set
    mov al, [ts_kw_buf + rcx]
    cmp al, 10
    jne .kw_len_set2
    ; if last is newline, reduce length
    mov rax, rcx
    jmp .kw_len_set
.kw_len_set2:
    mov rax, rcx
    inc rax
.kw_len_set:
    mov [ts_kw_len], rax

    ; if kw len == 0, warn and return
    cmp qword [ts_kw_len], 0
    jne .do_output_hdr
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_warn_empty
    mov rdx, ts_len_warn_empty
    syscall
    jmp .done

.do_output_hdr:
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_output_hdr
    mov rdx, ts_len_output_hdr
    syscall

    ; highlight search
    xor r12, r12               ; i = 0
    mov r13, [ts_text_len]
    mov r14, [ts_kw_len]
    xor r15, r15               ; match count
    ; if kwlen > textlen, just print text
    cmp r14, r13
    jbe .search_loop
    ; print whole text
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    mov rdx, r13
    syscall
    jmp .summary

.search_loop:
    cmp r12, r13
    jae .summary
    ; if remaining < kwlen, print rest
    mov rax, r13
    sub rax, r12
    cmp rax, r14
    jb .print_rest
    ; compare at position r12
    push r12
    push r13
    push r14
    push r15
    mov rdi, ts_text_buf
    add rdi, r12
    mov rsi, ts_kw_buf
    mov rcx, r14
    call ts_eq_ci_len
    pop r15
    pop r14
    pop r13
    pop r12
    cmp rax, 1
    jne .no_match
    ; match found: print hl_on + keyword + reset
    ; hl on
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_hl_on
    mov rdx, ts_len_hl_on
    syscall
    ; keyword
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_kw_buf]
    mov rdx, r14
    syscall
    ; reset
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_reset
    mov rdx, ts_len_reset
    syscall
    add r12, r14
    inc r15
    jmp .search_loop
.no_match:
    ; print one char
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    add rsi, r12
    mov rdx, 1
    syscall
    inc r12
    jmp .search_loop

.print_rest:
    ; print remaining bytes
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_text_buf]
    add rsi, r12
    mov rdx, r13
    sub rdx, r12
    syscall
    mov r12, r13
    jmp .summary

.summary:
    ; newline then summary count
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_summary1
    mov rdx, ts_len_summary1
    syscall
    ; print r15 as decimal
    mov rdi, r15
    lea rsi, [rel ts_num_buf]
    call ts_u64_to_dec
    ; write number
    mov rax, 1
    mov rdi, 1
    lea rsi, [rel ts_num_buf]
    ; rdx returned in rax by ts_u64_to_dec? We'll have it in rax
    mov rdx, rax
    syscall
    ; newline
    mov rax, 1
    mov rdi, 1
    mov rsi, ts_nl
    mov rdx, ts_len_nl
    syscall

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

;-------------------------------------
; Helpers
;-------------------------------------
; ts_eq_ci_len(rdi=ptr1, rsi=ptr2, rcx=len) -> rax=1 if equal case-insensitive else 0
ts_eq_ci_len:
    push rbp
    mov rbp, rsp
    xor rax, rax
    test rcx, rcx
    jz .yes
.cmp_loop:
    mov dl, [rdi]
    mov bl, [rsi]
    ; tolower dl
    cmp dl, 'A'
    jb .dl_ok
    cmp dl, 'Z'
    ja .dl_ok
    add dl, 32
.dl_ok:
    ; tolower bl
    cmp bl, 'A'
    jb .bl_ok
    cmp bl, 'Z'
    ja .bl_ok
    add bl, 32
.bl_ok:
    cmp dl, bl
    jne .no
    inc rdi
    inc rsi
    dec rcx
    jnz .cmp_loop
.yes:
    mov rax, 1
    jmp .ret
.no:
    xor rax, rax
.ret:
    pop rbp
    ret

; ts_u64_to_dec(rdi=value, rsi=buf) -> rax=len, writes ASCII digits to buf
ts_u64_to_dec:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push r10
    mov rax, rdi        ; value
    lea rbx, [rsi+31]   ; write backwards
    mov byte [rbx], 0
    mov rcx, 0          ; length
    cmp rax, 0
    jne .conv
    mov byte [rsi], '0'
    mov rax, 1
    jmp .done
.conv:
    ; divide by 10 loop
.loop:
    xor rdx, rdx
    mov r10, 10
    div r10            ; rax = rax/10, rdx = remainder
    add dl, '0'
    dec rbx
    mov [rbx], dl
    inc rcx
    test rax, rax
    jnz .loop
    ; move to beginning
    mov rax, rcx
    ; copy rcx bytes from rbx to rsi
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
