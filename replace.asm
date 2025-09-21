; Replace Substring - NASM x86_64 Linux (module) ; Replace target substring with replacement
; Exposes: replace_main                            ; Entry point

BITS 64                                           ; 64-bit mode

SECTION .data                                     ; UI strings and styles
rp_reset: db 0x1B,'[0m'                            ; ANSI reset
rp_len_reset equ $-rp_reset                        ; len
rp_bold:  db 0x1B,'[1m'                            ; ANSI bold
rp_len_bold equ $-rp_bold                          ; len
rp_cyan:  db 0x1B,'[36m'                           ; ANSI cyan
rp_len_cyan equ $-rp_cyan                          ; len
rp_hl:    db 0x1B,'[30;42m'   ; black on green background ; highlight style
rp_len_hl equ $-rp_hl                               ; len
rp_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10 ; top banner
rp_len_banner_top equ $-rp_banner_top               ; len
rp_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃           Replace Substring (ASM)           ┃',10 ; title
rp_len_banner_mid equ $-rp_banner_mid               ; len
rp_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; bottom+reset
rp_len_banner_bot equ $-rp_banner_bot               ; len
rp_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; text prompt
rp_len_prompt_text equ $-rp_prompt_text            ; len
rp_prompt_target: db 10,0x1B,'[1m','Target substring: ',0x1B,'[0m' ; target prompt
rp_len_prompt_target equ $-rp_prompt_target        ; len
rp_prompt_repl:   db 0x1B,'[1m','Replacement: ',0x1B,'[0m'        ; replacement prompt
rp_len_prompt_repl equ $-rp_prompt_repl            ; len
rp_output_hdr: db 10,0x1B,'[1m','Output:',0x1B,'[0m',10           ; output header
rp_len_output_hdr equ $-rp_output_hdr              ; len
rp_warn_empty: db 0x1B,'[31m','Target is empty. Nothing to replace.',0x1B,'[0m',10 ; empty target warning
rp_len_warn_empty equ $-rp_warn_empty              ; len

SECTION .bss                                       ; Buffers and lengths
rp_text:   resb 65536                               ; Input text buffer
rp_textlen: resq 1                                  ; Input text length
rp_target: resb 256                                 ; Target substring buffer
rp_tlen:   resq 1                                   ; Target length
rp_repl:   resb 256                                 ; Replacement buffer
rp_rlen:   resq 1                                   ; Replacement length

SECTION .text                                      ; Code
global replace_main                                 ; Export entry
; Overall: Read text, target, and replacement; print text with non-overlapping replacements highlighted

; Block: replace_main — Banner, read inputs, validate target, output with replacements
replace_main:
    push rbp                                        ; Prologue
    mov rbp, rsp                                     ; Frame
    push rbx                                         ; Save callee-saved
    push r12
    push r13
    push r14
    push r15

    ; Banner
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_banner_top                           ; top
    mov rdx, rp_len_banner_top                       ; len
    syscall
    mov rsi, rp_banner_mid                           ; mid
    mov rdx, rp_len_banner_mid                       ; len
    mov rax, 1                                       ; sys_write
    syscall
    mov rsi, rp_banner_bot                           ; bottom
    mov rdx, rp_len_banner_bot                       ; len
    mov rax, 1                                       ; sys_write
    syscall

    ; Prompt and read text (EOF to finish)
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_prompt_text                          ; text prompt
    mov rdx, rp_len_prompt_text                      ; len
    syscall

    xor rbx, rbx                                     ; total read
; Block: .rread — Read stdin into rp_text until EOF or full
.rread:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel rp_text]                           ; buffer
    add rsi, rbx                                     ; append offset
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx                                     ; remaining
    cmp rdx, 0
    je .rread_done
    syscall
    test rax, rax                                    ; <=0 ?
    jz .rread_done                                   ; EOF
    js .rread_done                                   ; error
    add rbx, rax                                     ; accumulate
    cmp rbx, 65536
    jb .rread
.rread_done:
    mov [rp_textlen], rbx                            ; store length

    ; Target prompt
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_prompt_target                        ; prompt
    mov rdx, rp_len_prompt_target                    ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel rp_target]                         ; buffer
    mov rdx, 255                                     ; up to 255
    syscall
    ; compute tlen minus newline if present
    mov rcx, rax                                     ; bytes read
    test rcx, rcx
    jz .tlen_set
    dec rcx                                          ; last index
    jl .tlen_set
    mov al, [rp_target + rcx]                        ; last byte
    cmp al, 10                                       ; newline?
    jne .tlen_set2
    mov rax, rcx                                     ; exclude newline
    jmp .tlen_set
.tlen_set2:
    mov rax, rcx                                     ; include last
    inc rax
.tlen_set:
    mov [rp_tlen], rax                               ; save target length

    ; Replacement prompt
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_prompt_repl                          ; prompt
    mov rdx, rp_len_prompt_repl                      ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel rp_repl]                           ; buffer
    mov rdx, 255                                     ; up to 255
    syscall
    mov rcx, rax                                     ; bytes read
    test rcx, rcx
    jz .rlen_set
    dec rcx                                          ; last index
    jl .rlen_set
    mov al, [rp_repl + rcx]                          ; last byte
    cmp al, 10                                       ; newline?
    jne .rlen_set2
    mov rax, rcx                                     ; exclude newline
    jmp .rlen_set
.rlen_set2:
    mov rax, rcx                                     ; include last
    inc rax
.rlen_set:
    mov [rp_rlen], rax                               ; save replacement length

    ; If target len == 0 -> warn and return
    cmp qword [rp_tlen], 0                           ; empty target?
    jne .do_output
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_warn_empty                           ; warning
    mov rdx, rp_len_warn_empty                       ; len
    syscall
    jmp .done

; Block: .do_output — Iterate text, matching target; print highlighted replacement or literal char
.do_output:
    ; header
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_output_hdr                           ; header
    mov rdx, rp_len_output_hdr                       ; len
    syscall

    xor r12, r12                 ; i                 ; position in text
    mov r13, [rp_textlen]                              ; text length
    mov r14, [rp_tlen]                                 ; target length
    mov r15, [rp_rlen]                                 ; replacement length

.loop:
    cmp r12, r13                                     ; i >= textlen?
    jae .end_output
    ; remaining < tlen ? print rest
    mov rax, r13                                     ; total
    sub rax, r12                                     ; remaining
    cmp rax, r14                                     ; remaining < tlen?
    jb .print_rest
    ; compare at i
    push r12                                         ; save temps
    push r13
    push r14
    mov rdi, rp_text                                 ; ptr1 = text+i
    add rdi, r12
    mov rsi, rp_target                               ; ptr2 = target
    mov rcx, r14                                     ; len
    call rp_eq_len                                   ; rax=1 if equal
    pop r14
    pop r13
    pop r12
    cmp rax, 1
    jne .no_match
    ; print highlighted replacement
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_hl                                   ; highlight style
    mov rdx, rp_len_hl                               ; len
    syscall
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel rp_repl]                           ; replacement text
    mov rdx, r15                                     ; replacement len
    syscall
    ; reset
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, rp_reset                                ; reset style
    mov rdx, rp_len_reset                            ; len
    syscall
    add r12, r14                                     ; skip past target
    jmp .loop
.no_match:
    ; print one char
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel rp_text]                           ; char addr
    add rsi, r12
    mov rdx, 1                                       ; len=1
    syscall
    inc r12                                          ; i++
    jmp .loop
; Block: .print_rest — Print remaining tail when fewer than tlen bytes remain
.print_rest:
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel rp_text]                           ; remaining segment
    add rsi, r12
    mov rdx, r13                                     ; total len
    sub rdx, r12                                     ; remaining len
    syscall
    mov r12, r13                                     ; i = textlen
    jmp .end_output
.end_output:
    ; done                                           ; fallthrough to epilogue

; Block: .done — Restore regs and return
.done:
    pop r15                                          ; Restore regs
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret                                              ; Return

; rp_eq_len(rdi=ptr1, rsi=ptr2, rcx=len) -> rax=1 if equal else 0
; Block: rp_eq_len — Fixed-length byte-wise equality test
rp_eq_len:
    push rbp                                         ; Prologue
    mov rbp, rsp
    test rcx, rcx                                    ; len == 0 ? equal
    jz .yes
.cmp:
    mov al, [rdi]                                    ; load bytes
    mov bl, [rsi]
    cmp al, bl                                       ; compare
    jne .no
    inc rdi                                          ; advance
    inc rsi
    dec rcx
    jnz .cmp
.yes:
    mov rax, 1                                       ; equal
    jmp .ret
.no:
    xor rax, rax                                     ; not equal
.ret:
    pop rbp                                          ; Epilogue
    ret
