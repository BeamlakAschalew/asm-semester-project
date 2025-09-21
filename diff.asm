; Diff Tool - NASM x86_64 Linux (module) ; Side-by-side byte-wise diff of two inputs
; Exposes: diff_main                       ; Entry for menu dispatcher

BITS 64                                           ; 64-bit mode

SECTION .data                                     ; UI strings and styles
df_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10 ; top banner
df_len_banner_top equ $-df_banner_top               ; len
df_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃                  Diff Tool (ASM)            ┃',10 ; title
df_len_banner_mid equ $-df_banner_mid               ; len
df_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; bottom + reset
df_len_banner_bot equ $-df_banner_bot               ; len
df_prompt_a: db 0x1B,'[1m','Enter first text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; prompt A
df_len_prompt_a equ $-df_prompt_a                   ; len
df_prompt_b: db 10,0x1B,'[1m','Enter second text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; prompt B
df_len_prompt_b equ $-df_prompt_b                   ; len
df_out_a: db 10,0x1B,'[1m','A: ',0x1B,'[0m'                      ; header for A
df_len_out_a equ $-df_out_a                         ; len
df_out_b: db 10,0x1B,'[1m','B: ',0x1B,'[0m'                      ; header for B
df_len_out_b equ $-df_out_b                         ; len
df_hl_add: db 0x1B,'[30;42m'   ; additions (present in B) green ; highlight for additions
df_len_hl_add equ $-df_hl_add                       ; len
df_hl_del: db 0x1B,'[30;41m'   ; deletions (present in A) red   ; highlight for deletions
df_len_hl_del equ $-df_hl_del                       ; len
df_reset: db 0x1B,'[0m'                               ; ANSI reset
df_len_reset equ $-df_reset                         ; len
df_nl: db 10                                         ; newline
df_len_nl equ $-df_nl                               ; len

SECTION .bss                                       ; Buffers
df_a:  resb 65536                                   ; First input
df_al: resq 1                                       ; Length A
df_b:  resb 65536                                   ; Second input
df_bl: resq 1                                       ; Length B
df_tmp: resb 1                                      ; Temp for single-byte write

SECTION .text                                      ; Code
global diff_main                                    ; Export entry

diff_main:
    push rbp                                        ; Prologue
    mov rbp, rsp                                     ; Frame
    push rbx                                         ; Save callee-saved
    push r12
    push r13
    push r14
    push r15

    ; banner
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_banner_top                           ; top
    mov rdx, df_len_banner_top                       ; len
    syscall
    mov rsi, df_banner_mid                           ; mid
    mov rdx, df_len_banner_mid                       ; len
    mov rax, 1                                       ; sys_write
    syscall
    mov rsi, df_banner_bot                           ; bottom
    mov rdx, df_len_banner_bot                       ; len
    mov rax, 1                                       ; sys_write
    syscall

    ; read A
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_prompt_a                             ; prompt A
    mov rdx, df_len_prompt_a                         ; len
    syscall
    xor rbx, rbx                                     ; total read
.ra:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel df_a]                              ; buffer A
    add rsi, rbx                                     ; append offset
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx                                     ; remaining
    cmp rdx, 0
    je .ra_done
    syscall
    test rax, rax                                    ; <=0?
    jz .ra_done
    js .ra_done
    add rbx, rax                                     ; accum
    cmp rbx, 65536
    jb .ra
.ra_done:
    mov [df_al], rbx                                 ; store len A

    ; read B
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_prompt_b                             ; prompt B
    mov rdx, df_len_prompt_b                         ; len
    syscall
    xor rbx, rbx                                     ; total read
.rb:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel df_b]                              ; buffer B
    add rsi, rbx                                     ; append
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx                                     ; remaining
    cmp rdx, 0
    je .rb_done
    syscall
    test rax, rax                                    ; <=0?
    jz .rb_done
    js .rb_done
    add rbx, rax                                     ; accum
    cmp rbx, 65536
    jb .rb
.rb_done:
    mov [df_bl], rbx                                 ; store len B

    ; print A line
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_out_a                                ; "A: " header
    mov rdx, df_len_out_a                            ; len
    syscall
    ; walk both buffers, print A char; if A!=B char at pos, highlight deletion while printing A
    xor r12, r12                                     ; i = 0
    mov r13, [df_al]                                 ; len A
    mov r14, [df_bl]                                 ; len B
.pa:
    cmp r12, r13                                     ; i >= lenA ?
    jae .a_done
    mov dl, [df_a + r12]                             ; A[i]
    ; compare with B at same pos if exists
    mov bl, 0
    cmp r12, r14
    jae .no_b
    mov bl, [df_b + r12]                             ; B[i]
.no_b:
    cmp dl, bl                                       ; equal bytes?
    je .emit_a
    ; mismatch -> deletion from A
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_hl_del                               ; red bg for deletions
    mov rdx, df_len_hl_del                           ; len
    syscall
.emit_a:
    mov [df_tmp], dl                                 ; prepare 1-byte write
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_tmp                                  ; &byte
    mov rdx, 1                                       ; len
    syscall
    ; reset if mismatch
    cmp dl, bl
    je .next_a
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_reset                                ; reset
    mov rdx, df_len_reset                            ; len
    syscall
.next_a:
    inc r12                                          ; i++
    jmp .pa
.a_done:
    ; newline
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_nl                                   ; newline
    mov rdx, df_len_nl                               ; len
    syscall

    ; print B line
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_out_b                                ; "B: " header
    mov rdx, df_len_out_b                            ; len
    syscall
    xor r12, r12                                     ; i = 0
.pb:
    cmp r12, r14                                     ; i >= lenB ?
    jae .done
    mov dl, [df_b + r12]                             ; B[i]
    mov bl, 0
    cmp r12, r13                                     ; within A?
    jae .no_a
    mov bl, [df_a + r12]                             ; A[i]
.no_a:
    cmp dl, bl                                       ; equal?
    je .emit_b
    ; addition in B
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_hl_add                               ; green bg for additions
    mov rdx, df_len_hl_add                           ; len
    syscall
.emit_b:
    mov [df_tmp], dl                                 ; write B[i]
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_tmp                                  ; &byte
    mov rdx, 1                                       ; len
    syscall
    cmp dl, bl
    je .next_b
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, df_reset                                ; reset
    mov rdx, df_len_reset                            ; len
    syscall
.next_b:
    inc r12                                          ; i++
    jmp .pb

.done:
    pop r15                                          ; Restore regs
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret                                              ; Return
