; Caesar Cipher - NASM x86_64 Linux (module)         ; Module providing a simple Caesar shift transform
; Exposes: crypto_main                               ; Entry point callable from a larger program

BITS 64                                                ; Assemble for 64-bit mode

SECTION .data                                          ; Initialized data and UI strings
cr_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10   ; Cyan top banner
cr_len_banner_top equ $-cr_banner_top                  ; Length of top banner
cr_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃               Caesar Cipher (ASM)          ┃',10 ; Bold cyan title
cr_len_banner_mid equ $-cr_banner_mid                  ; Length of mid banner
cr_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; Bottom + reset
cr_len_banner_bot equ $-cr_banner_bot                  ; Length of bottom banner
cr_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; Input prompt
cr_len_prompt_text equ $-cr_prompt_text                ; Length of input prompt
cr_prompt_shift: db 0x1B,'[1m','Caesar shift (-25..25): ',0x1B,'[0m' ; Prompt for Caesar shift
cr_len_prompt_shift equ $-cr_prompt_shift              ; Length of shift prompt
cr_output_hdr: db 10,0x1B,'[1m','Result:',0x1B,'[0m',10 ; Output header
cr_len_output_hdr equ $-cr_output_hdr                  ; Length of output header

SECTION .bss                                           ; Uninitialized buffers and variables
cr_text: resb 65536                                    ; Buffer to hold input text (up to 64 KiB)
cr_len:  resq 1                                        ; Qword length of input
cr_in:   resb 16                                       ; Small input buffer for mode/shift/key

SECTION .text                                          ; Code section
global crypto_main                                     ; Exported entry point
; Overall: Reads text and shift, applies Caesar cipher to letters, prints result

; Block: crypto_main — Banner, read text, parse shift, transform, print
crypto_main:                                           ; Main driver for crypto tools
    push rbp                                           ; Prologue: save base pointer
    mov rbp, rsp                                       ; Establish stack frame
    push rbx                                           ; Save callee-saved regs
    push r12

    ; banner
    mov rax, 1                                         ; sys_write
    mov rdi, 1                                         ; fd=stdout
    mov rsi, cr_banner_top                             ; top banner
    mov rdx, cr_len_banner_top                         ; len
    syscall                                            ; write
    mov rsi, cr_banner_mid                             ; mid banner
    mov rdx, cr_len_banner_mid                         ; len
    mov rax, 1                                         ; sys_write
    syscall                                            ; write
    mov rsi, cr_banner_bot                             ; bottom banner
    mov rdx, cr_len_banner_bot                         ; len
    mov rax, 1                                         ; sys_write
    syscall                                            ; write

    ; read text
    mov rax, 1                                         ; sys_write
    mov rdi, 1                                         ; stdout
    mov rsi, cr_prompt_text                            ; prompt to enter text (Ctrl+D to finish)
    mov rdx, cr_len_prompt_text                        ; len
    syscall
    xor rbx, rbx                                       ; total bytes read = 0
; Block: .rloop — Read stdin into cr_text until EOF or buffer full
.rloop:
    mov rax, 0                                         ; sys_read
    mov rdi, 0                                         ; fd=stdin
    lea rsi, [rel cr_text]                             ; base of buffer
    add rsi, rbx                                       ; advance to current end
    mov rdx, 65536                                     ; max buffer size
    sub rdx, rbx                                       ; remaining capacity
    cmp rdx, 0                                         ; no space left?
    je .rdone                                          ; stop if full
    syscall                                            ; read as much as available
    test rax, rax                                      ; rax <= 0 ?
    jz .rdone                                          ; EOF
    js .rdone                                          ; error
    add rbx, rax                                       ; accumulate length
    cmp rbx, 65536                                     ; still under limit?
    jb .rloop
; Block: .rdone — Finalize reading
.rdone:
    mov [cr_len], rbx                                  ; save total length

    ; Caesar shift (only mode)
    mov rax, 1                                         ; sys_write
    mov rdi, 1                                         ; stdout
    mov rsi, cr_prompt_shift                           ; ask for shift amount
    mov rdx, cr_len_prompt_shift                       ; len
    syscall
    ; read shift line, parse small int [-25..25]
    mov rax, 0                                         ; sys_read
    mov rdi, 0                                         ; stdin
    mov rsi, cr_in                                     ; buffer for input
    mov rdx, 8                                         ; read up to 8 bytes
    syscall
    ; simplistic parse: first char optional '-' then digits
    xor r12, r12                                       ; clear scratch
    mov bl, [cr_in]                                    ; current char
    mov dl, 0        ; sign 0=+ 1=-                     ; sign flag
    cmp bl, '-'                                        ; leading minus?
    jne .parse_d                                       ; if not, parse digits
    mov dl, 1                                          ; remember negative
    mov bl, [cr_in+1]                                  ; advance one char
.parse_d:
    xor eax, eax                                       ; accumulator = 0
; Block: .ps_loop — Parse decimal digits of shift, accumulating in eax
.ps_loop:
    cmp bl, '0'                                        ; below '0'?
    jb .ps_done                                        ; stop parsing
    cmp bl, '9'                                        ; above '9'?
    ja .ps_done                                        ; stop parsing
    imul eax, eax, 10                                  ; acc *= 10
    mov r12d, ebx                                      ; r12d = bl (zero-extended)
    sub r12d, '0'                                      ; digit value
    add eax, r12d                                      ; acc += digit
    mov bl, [cr_in+1]                                  ; shift buffer left by 1 (cheap way)
    mov byte [cr_in], bl
    mov bl, [cr_in]                                    ; load next char to test again
    jmp .ps_loop                                       ; continue
.ps_done:
    cmp dl, 0                                          ; negative sign?
    je .have_shift                                     ; if not, keep as is
    neg eax                                            ; negate
.have_shift:
    ; Caesar transform letters only (preserve case)
    mov r12, 0                                         ; i = 0
    mov r13, [cr_len]                                  ; n = length
    mov r14d, eax                                      ; shift (can be any int)
    ; normalize shift to [-25..25]                     ; handled implicitly by modulo op below
    ; output header
    mov rax, 1                                         ; sys_write
    mov rdi, 1                                         ; stdout
    mov rsi, cr_output_hdr                             ; "Result:" header
    mov rdx, cr_len_output_hdr                         ; len
    syscall
; Block: .caesar_loop — Walk bytes and shift only A..Z/a..z preserving case
.caesar_loop:
    cmp r12, r13                                        ; i >= n ?
    jae .done                                           ; end
    mov dl, [cr_text + r12]                             ; dl = src byte
    ; uppercase
    cmp dl, 'A'                                         ; >= 'A' ?
    jb .chk_low                                         ; no → check lowercase
    cmp dl, 'Z'                                         ; <= 'Z' ?
    ja .chk_low                                         ; no → not a letter
    ; eax := (dl - 'A' + shift)
    movzx eax, dl                                       ; zero-extend char
    sub eax, 'A'                                        ; 0..25
    add eax, r14d                                       ; apply shift (can be negative)
    ; compute signed remainder mod 26 safely: edx:eax / ecx
    mov ecx, 26                                         ; divisor
    cdq                 ; sign-extend eax into edx       ; edx:eax for idiv
    idiv ecx            ; eax=quot, edx=rem in [-25,25]  ; signed division
    mov eax, edx        ; remainder                      ; keep rem
    cmp eax, 0
    jge .uc_ok                                          ; if rem negative, wrap
    add eax, 26         ; force into [0,25]
.uc_ok:
    add eax, 'A'                                        ; back to 'A'..'Z'
    mov dl, al                                          ; dl = shifted char
    jmp .emit                                           ; emit it
.chk_low:
    cmp dl, 'a'                                         ; >= 'a' ?
    jb .emit                                           ; not a letter
    cmp dl, 'z'                                         ; <= 'z' ?
    ja .emit                                           ; not a letter
    ; eax := (dl - 'a' + shift)
    movzx eax, dl                                       ; zero-extend char
    sub eax, 'a'                                        ; 0..25
    add eax, r14d                                       ; apply shift
    mov ecx, 26                                         ; divisor
    cdq                                                 ; sign-extend
    idiv ecx                                            ; signed division
    mov eax, edx                                        ; remainder
    cmp eax, 0
    jge .lc_ok
    add eax, 26                                         ; wrap
.lc_ok:
    add eax, 'a'                                        ; back to 'a'..'z'
    mov dl, al                                          ; dl = shifted char
.emit:
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel cr_text]                              ; (unused) leftover addressing
    mov [cr_text], dl                                   ; place single output byte at buffer start
    mov rsi, cr_text                                    ; buf = cr_text
    mov rdx, 1                                          ; len = 1
    syscall                                             ; write transformed byte
    inc r12                                             ; i++
    jmp .caesar_loop                                    ; continue loop

    ; (XOR mode removed)

; Block: .done — Restore regs and return
.done:
    pop r12                                             ; Restore callee-saved regs
    pop rbx
    pop rbp                                             ; Epilogue
    ret                                                 ; Return to caller
