; Character Count - NASM x86_64 Linux (module) ; Module to count characters in input
; Exposes: char_count_main                       ; Entry for util menu

BITS 64                                           ; 64-bit mode

SECTION .data                                     ; UI strings
cc_reset: db 0x1B,'[0m'                            ; ANSI reset
cc_len_reset equ $-cc_reset                        ; len
cc_bold:  db 0x1B,'[1m'                            ; ANSI bold
cc_len_bold equ $-cc_bold                          ; len
cc_cyan:  db 0x1B,'[36m'                           ; ANSI cyan
cc_len_cyan equ $-cc_cyan                          ; len
cc_dim:   db 0x1B,'[90m'                           ; ANSI dim
cc_len_dim equ $-cc_dim                            ; len
cc_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10 ; banner top
cc_len_banner_top equ $-cc_banner_top              ; len
cc_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃            Character Count (ASM)            ┃',10 ; title
cc_len_banner_mid equ $-cc_banner_mid              ; len
cc_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; bottom + reset
cc_len_banner_bot equ $-cc_banner_bot              ; len
cc_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; prompt
cc_len_prompt_text equ $-cc_prompt_text            ; len
cc_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Specific char  [2] All chars',10 ; mode prompt
cc_len_prompt_mode equ $-cc_prompt_mode            ; len
cc_prompt_char: db 0x1B,'[1m','Character to count: ',0x1B,'[0m' ; char prompt
cc_len_prompt_char equ $-cc_prompt_char            ; len
cc_result1: db 10,0x1B,'[1m','Count: ',0x1B,'[0m'              ; result label
cc_len_result1 equ $-cc_result1                    ; len
cc_nl: db 10                                       ; newline
cc_len_nl equ $-cc_nl                              ; len

SECTION .bss                                       ; Buffers and counters
cc_text:   resb 65536                               ; Input text (64 KiB)
cc_len:    resq 1                                   ; Length of input
cc_counts: resd 256       ; frequency table         ; 256 dwords for byte frequencies
cc_num:    resb 32                                   ; Buffer for decimal output
cc_inbuf:  resb 8                                    ; Small input buffer
cc_ch:     resb 1                                    ; Single char buffer
cc_colonsp: resb 2                                   ; ": " literal

SECTION .text                                      ; Code
global char_count_main                               ; Export entry

char_count_main:
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
    mov rsi, cc_banner_top                           ; top
    mov rdx, cc_len_banner_top                       ; len
    syscall
    mov rsi, cc_banner_mid                           ; mid
    mov rdx, cc_len_banner_mid                       ; len
    mov rax, 1                                       ; sys_write
    syscall
    mov rsi, cc_banner_bot                           ; bottom
    mov rdx, cc_len_banner_bot                       ; len
    mov rax, 1                                       ; sys_write
    syscall

    ; prompt text
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_prompt_text                          ; enter text prompt
    mov rdx, cc_len_prompt_text                      ; len
    syscall

    ; read text
    xor rbx, rbx                                     ; total read
.rloop:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel cc_text]                           ; buffer base
    add rsi, rbx                                     ; append at end
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx                                     ; remaining
    cmp rdx, 0                                       ; full?
    je .rdone
    syscall
    test rax, rax                                    ; <= 0?
    jz .rdone                                        ; EOF
    js .rdone                                        ; error
    add rbx, rax                                     ; accum
    cmp rbx, 65536
    jb .rloop
.rdone:
    mov [cc_len], rbx                                ; store length

    ; prompt mode
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_prompt_mode                          ; mode menu
    mov rdx, cc_len_prompt_mode                      ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    mov rsi, cc_inbuf                                ; input buffer
    mov rdx, 2                                       ; read 1 char (+\n)
    syscall
    mov al, [cc_inbuf]                               ; selection
    cmp al, '1'
    je .mode_one                                     ; branch to specific char
    ; default: mode two
.mode_two:
    ; zero counts
    lea rdi, [rel cc_counts]                         ; dest pointer
    mov rcx, 256                                     ; dwords to zero
    xor eax, eax                                     ; value=0
    rep stosd                                        ; memset counts to 0
    ; count all
    xor r12, r12                                     ; i = 0
    mov r13, [cc_len]                                ; n = len
.cnt_all:
    cmp r12, r13                                     ; i >= n ?
    jae .show_all
    mov bl, [cc_text + r12]                          ; read byte
    movzx rbx, bl                                    ; zero-extend to index
    mov edi, [cc_counts + rbx*4]                     ; load count
    add edi, 1                                       ; ++
    mov [cc_counts + rbx*4], edi                     ; store back
    inc r12                                          ; i++
    jmp .cnt_all
.show_all:
    ; dump printable ASCII (32..126)
    mov r12, 32                                      ; start from space
.dump_loop:
    cmp r12, 126                                     ; beyond '~'?
    ja .done
    mov edi, [cc_counts + r12*4]                     ; count for char
    test edi, edi                                    ; zero?
    jz .next
    ; print char
    mov byte [cc_ch], r12b                           ; store char
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_ch                                   ; ptr
    mov rdx, 1                                       ; 1 byte
    syscall
    ; print ": "
    mov byte [cc_colonsp], ':'                       ; ':'
    mov byte [cc_colonsp+1], ' '                     ; space
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_colonsp                              ; ": "
    mov rdx, 2                                       ; len
    syscall
    ; number
    mov edi, [cc_counts + r12*4]                     ; value
    lea rsi, [rel cc_num]                            ; buffer
    call cc_u64_to_dec                                ; rax=len
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel cc_num]                            ; digits
    mov rdx, rax                                     ; len
    syscall
    ; newline
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_nl                                   ; newline
    mov rdx, cc_len_nl                               ; len
    syscall
.next:
    inc r12                                          ; next char
    jmp .dump_loop

.mode_one:
    ; ask char
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_prompt_char                          ; prompt
    mov rdx, cc_len_prompt_char                      ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    mov rsi, cc_inbuf                                ; read 1 char (+\n)
    mov rdx, 2
    syscall
    mov bl, [cc_inbuf]                               ; target char
    ; count
    xor r12, r12                                     ; i = 0
    xor r13, r13                                     ; count = 0
    mov r14, [cc_len]                                ; n = len
.cnt_one:
    cmp r12, r14                                     ; i >= n ?
    jae .show_one
    cmp bl, [cc_text + r12]                          ; match?
    jne .nx1
    inc r13                                          ; count++
.nx1:
    inc r12                                          ; i++
    jmp .cnt_one
.show_one:
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_result1                              ; "Count: "
    mov rdx, cc_len_result1                          ; len
    syscall
    ; print number r13
    mov rdi, r13                                     ; value
    lea rsi, [rel cc_num]                            ; buffer
    call cc_u64_to_dec                                ; rax=len
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel cc_num]                            ; digits
    mov rdx, rax                                     ; len
    syscall
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, cc_nl                                   ; newline
    mov rdx, cc_len_nl                               ; len
    syscall
    jmp .done

.done:
    pop r15                                          ; Restore regs
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp                                          ; Epilogue
    ret                                              ; Return

; local helper: cc_u64_to_dec(rdi=value, rsi=buf) -> rax=len
cc_u64_to_dec:
    push rbp                                         ; Prologue
    mov rbp, rsp
    push rbx
    push rdx
    push r10
    mov rax, rdi                                     ; value
    lea rbx, [rsi+31]                                ; end of buffer
    mov byte [rbx], 0                                ; NUL (safety)
    mov rcx, 0                                       ; length
    cmp rax, 0
    jne .conv
    mov byte [rsi], '0'                              ; zero case
    mov rax, 1
    jmp .done
.conv:
.loop:
    xor rdx, rdx                                     ; clear high for div
    mov r10, 10
    div r10                                          ; rax/=10, rdx=rem
    add dl, '0'                                      ; rem -> ASCII
    dec rbx                                          ; step back
    mov [rbx], dl                                    ; store digit
    inc rcx                                          ; count++
    test rax, rax                                    ; more?
    jnz .loop
    mov rax, rcx                                     ; return length
    mov r8, rax                                      ; r8=len
    xor r9, r9                                       ; i=0
.copy:
    mov dl, [rbx + r9]                               ; digit
    mov [rsi + r9], dl                               ; copy forward
    inc r9
    cmp r9, r8
    jne .copy
.done:
    pop r10
    pop rdx
    pop rbx
    pop rbp
    ret
