; Text Search Highlighter - NASM x86_64 Linux (module) ; Module to highlight keyword occurrences in input text
; Exposes: text_search_main (no exit; returns to caller) ; Entry point returns control to caller

BITS 64                                           ; Assemble for 64-bit mode

SECTION .data                                      ; Initialized data (colors and UI strings)
; Colors (module-scoped with ts_ prefix to avoid collisions)
ts_reset:      db 0x1B, '[0m'                       ; ANSI reset
ts_len_reset   equ $-ts_reset                       ; Length of reset sequence
ts_bold:       db 0x1B, '[1m'                       ; ANSI bold
ts_len_bold    equ $-ts_bold                        ; Length of bold
ts_dim:        db 0x1B, '[90m'                      ; ANSI dim/gray
ts_len_dim     equ $-ts_dim                         ; Length of dim
ts_cyan:       db 0x1B, '[36m'                      ; ANSI cyan
ts_len_cyan    equ $-ts_cyan                        ; Length of cyan
ts_magenta:    db 0x1B, '[35m'                      ; ANSI magenta
ts_len_magenta equ $-ts_magenta                     ; Length of magenta
ts_green:      db 0x1B, '[32m'                      ; ANSI green
ts_len_green   equ $-ts_green                       ; Length of green
ts_red:        db 0x1B, '[31m'                      ; ANSI red
ts_len_red     equ $-ts_red                         ; Length of red
ts_hl_on:      db 0x1B, '[30;43m'    ; black on yellow background ; Highlight on (black text on yellow)
ts_len_hl_on   equ $-ts_hl_on                        ; Length of highlight sequence

; UI strings
ts_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10 ; Top banner
ts_len_banner_top equ $-ts_banner_top               ; Length
ts_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃        Text Search Highlighter (ASM)         ┃',10 ; Title line
ts_len_banner_mid equ $-ts_banner_mid               ; Length
ts_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; Bottom + reset
ts_len_banner_bot equ $-ts_banner_bot               ; Length

ts_prompt_text: db 0x1B,'[1m','Paste your text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; Input prompt
ts_len_prompt_text equ $-ts_prompt_text             ; Length

ts_prompt_kw:   db 10,0x1B,'[1m','Enter keyword to highlight: ',0x1B,'[0m' ; Keyword prompt
ts_len_prompt_kw equ $-ts_prompt_kw                 ; Length

ts_output_hdr:  db 10,0x1B,'[1m','Output with highlights:',0x1B,'[0m',10   ; Output header
ts_len_output_hdr equ $-ts_output_hdr               ; Length

ts_summary1:    db 10,0x1B,'[90m','Matches found: ',0x1B,'[0m'             ; Summary prefix
ts_len_summary1 equ $-ts_summary1                   ; Length
ts_nl:          db 10                               ; Newline
ts_len_nl       equ $-ts_nl                         ; Length of newline

ts_warn_empty:  db 0x1B,'[31m','Keyword is empty. Nothing to highlight.',0x1B,'[0m',10 ; Warning if empty keyword
ts_len_warn_empty equ $-ts_warn_empty               ; Length

SECTION .bss                                        ; Buffers and counters
ts_text_buf:  resb 65536                            ; Input text buffer (64 KiB)
ts_text_len:  resq 1                                ; Length of input text
ts_kw_buf:    resb 256                              ; Keyword buffer (up to 255 + NUL)
ts_kw_len:    resq 1                                ; Length of keyword
ts_num_buf:   resb 32                               ; Decimal buffer for summary number

SECTION .text                                       ; Code section
global text_search_main                              ; Exported entry point
; Overall: Read text and keyword, print text with matches highlighted, then a match count

;-------------------------------------
; Entry
;-------------------------------------
; Block: text_search_main — Banner, read text, read keyword, highlight and summarize
text_search_main:
    push rbp                                        ; Prologue
    mov rbp, rsp                                     ; Establish stack frame
    push rbx                                         ; Save callee-saved regs
    push r12
    push r13
    push r14
    push r15

    ; banner
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ts_banner_top                           ; top banner
    mov rdx, ts_len_banner_top                       ; len
    syscall
    mov rsi, ts_banner_mid                           ; mid banner
    mov rdx, ts_len_banner_mid                       ; len
    mov rax, 1                                       ; sys_write
    syscall
    mov rsi, ts_banner_bot                           ; bottom banner
    mov rdx, ts_len_banner_bot                       ; len
    mov rax, 1                                       ; sys_write
    syscall

    ; prompt for text
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ts_prompt_text                          ; prompt to paste text
    mov rdx, ts_len_prompt_text                      ; len
    syscall

    ; read until EOF or buffer full
    xor rbx, rbx               ; total len             ; rbx = total bytes read
; Block: .read_loop — Read stdin into ts_text_buf until EOF or full
.read_loop:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel ts_text_buf]                       ; base buffer
    add rsi, rbx                                     ; write at current end
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx               ; remaining           ; remaining capacity
    cmp rdx, 0                                       ; full?
    je .read_done                                    ; stop if no space
    syscall
    test rax, rax                                    ; rax <= 0 ?
    jz .read_done              ; EOF                  ; EOF
    js .read_done              ; error -> stop        ; error
    add rbx, rax                                     ; accumulate
    cmp rbx, 65536                                   ; still below limit?
    jb .read_loop                                    ; continue reading
.read_done:
    mov [ts_text_len], rbx                           ; save length

    ; prompt for keyword
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ts_prompt_kw                            ; "Enter keyword" prompt
    mov rdx, ts_len_prompt_kw                        ; len
    syscall

    ; read keyword line (up to 255 bytes)
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel ts_kw_buf]                         ; keyword buffer
    mov rdx, 255                                     ; max bytes
    syscall
    ; rax = bytes read, strip trailing newline
    xor rcx, rcx                                     ; rcx = temp length
    test rax, rax                                    ; rax == 0 ?
    jz .kw_len_set                                   ; empty input
    mov rcx, rax                                     ; rcx = bytes read
    dec rcx                                          ; rcx = last index
    jl .kw_len_set                                   ; if negative, length=0
    mov al, [ts_kw_buf + rcx]                        ; last char
    cmp al, 10                                       ; newline?
    jne .kw_len_set2
    ; if last is newline, reduce length
    mov rax, rcx                                     ; exclude newline
    jmp .kw_len_set
.kw_len_set2:
    mov rax, rcx                                     ; else include last char
    inc rax
.kw_len_set:
    mov [ts_kw_len], rax                             ; store keyword length

    ; if kw len == 0, warn and return
    cmp qword [ts_kw_len], 0                         ; empty keyword?
    jne .do_output_hdr
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ts_warn_empty                           ; warning message
    mov rdx, ts_len_warn_empty                       ; len
    syscall
    jmp .done                                        ; exit

.do_output_hdr:
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ts_output_hdr                           ; header
    mov rdx, ts_len_output_hdr                       ; len
    syscall

    ; highlight search
    xor r12, r12               ; i = 0                  ; current index
    mov r13, [ts_text_len]                              ; text length
    mov r14, [ts_kw_len]                                ; keyword length
    xor r15, r15               ; match count            ; count of matches
    ; if kwlen > textlen, just print text
    cmp r14, r13                                        ; keyword longer than text?
    jbe .search_loop                                    ; if not, search
    ; print whole text
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel ts_text_buf]                          ; text buf
    mov rdx, r13                                        ; full length
    syscall
    jmp .summary                                        ; skip search

; Block: .search_loop — Scan, print either highlight+keyword or single char
.search_loop:
    cmp r12, r13                                        ; i >= textlen?
    jae .summary
    ; if remaining < kwlen, print rest
    mov rax, r13                                        ; rax = textlen
    sub rax, r12                                        ; remaining
    cmp rax, r14                                        ; remaining < kwlen?
    jb .print_rest                                      ; print the rest and end
    ; compare at position r12
    push r12                                            ; save volatile regs used as counters
    push r13
    push r14
    push r15
    mov rdi, ts_text_buf                                ; ptr1 = text + i
    add rdi, r12
    mov rsi, ts_kw_buf                                  ; ptr2 = keyword
    mov rcx, r14                                        ; len = kwlen
    call ts_eq_ci_len                                   ; rax=1 if equal case-insensitive
    pop r15
    pop r14
    pop r13
    pop r12
    cmp rax, 1
    jne .no_match
    ; match found: print hl_on + keyword + reset
    ; hl on
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    mov rsi, ts_hl_on                                   ; highlight on
    mov rdx, ts_len_hl_on                               ; len
    syscall
    ; keyword
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel ts_kw_buf]                            ; keyword buf
    mov rdx, r14                                        ; kw len
    syscall
    ; reset
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    mov rsi, ts_reset                                   ; reset styles
    mov rdx, ts_len_reset                               ; len
    syscall
    add r12, r14                                        ; skip past match
    inc r15                                             ; count++
    jmp .search_loop
.no_match:
    ; print one char
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel ts_text_buf]                          ; address of current char
    add rsi, r12
    mov rdx, 1                                          ; len=1
    syscall
    inc r12                                             ; i++
    jmp .search_loop

; Block: .print_rest — Print the remaining text when fewer than kwlen bytes remain
.print_rest:
    ; print remaining bytes
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel ts_text_buf]                          ; start at i
    add rsi, r12
    mov rdx, r13                                        ; total len
    sub rdx, r12                                        ; len remaining
    syscall
    mov r12, r13                                        ; i = textlen
    jmp .summary

; Block: .summary — Print match count (r15) as decimal
.summary:
    ; newline then summary count
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    mov rsi, ts_summary1                                ; "Matches found: "
    mov rdx, ts_len_summary1                            ; len
    syscall
    ; print r15 as decimal
    mov rdi, r15                                        ; value to print
    lea rsi, [rel ts_num_buf]                           ; buffer for number
    call ts_u64_to_dec                                  ; rax = length of number
    ; write number
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    lea rsi, [rel ts_num_buf]                           ; number buf
    ; rdx returned in rax by ts_u64_to_dec? We'll have it in rax ; use rax as len
    mov rdx, rax
    syscall
    ; newline
    mov rax, 1                                          ; sys_write
    mov rdi, 1                                          ; stdout
    mov rsi, ts_nl                                      ; newline
    mov rdx, ts_len_nl                                  ; len
    syscall

; Block: .done — Restore regs and return
.done:
    pop r15                                             ; Restore callee-saved regs
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp                                             ; Epilogue
    ret                                                 ; Return to caller

;-------------------------------------
; Helpers
;-------------------------------------
; ts_eq_ci_len(rdi=ptr1, rsi=ptr2, rcx=len) -> rax=1 if equal case-insensitive else 0
; Block: ts_eq_ci_len — Case-insensitive fixed-length compare
ts_eq_ci_len:
    push rbp                                          ; Prologue
    mov rbp, rsp
    xor rax, rax                                       ; default 0
    test rcx, rcx                                      ; len == 0 ?
    jz .yes                                            ; empty strings equal
.cmp_loop:
    mov dl, [rdi]                                      ; dl = *ptr1
    mov bl, [rsi]                                      ; bl = *ptr2
    ; tolower dl
    cmp dl, 'A'
    jb .dl_ok
    cmp dl, 'Z'
    ja .dl_ok
    add dl, 32                                         ; make lowercase
.dl_ok:
    ; tolower bl
    cmp bl, 'A'
    jb .bl_ok
    cmp bl, 'Z'
    ja .bl_ok
    add bl, 32
.bl_ok:
    cmp dl, bl                                         ; compare
    jne .no                                            ; mismatch
    inc rdi                                            ; advance ptr1
    inc rsi                                            ; advance ptr2
    dec rcx                                            ; len--
    jnz .cmp_loop                                      ; continue
.yes:
    mov rax, 1                                         ; equal
    jmp .ret
.no:
    xor rax, rax                                       ; not equal
.ret:
    pop rbp                                            ; Epilogue
    ret

; ts_u64_to_dec(rdi=value, rsi=buf) -> rax=len, writes ASCII digits to buf
; Block: ts_u64_to_dec — Convert unsigned 64-bit to decimal string
ts_u64_to_dec:
    push rbp                                          ; Prologue
    mov rbp, rsp
    push rbx
    push rdx
    push r10
    mov rax, rdi        ; value                        ; rax = value to print
    lea rbx, [rsi+31]   ; write backwards              ; rbx = end of buffer
    mov byte [rbx], 0                                  ; NUL terminator (unused by writer)
    mov rcx, 0          ; length                       ; digit count
    cmp rax, 0
    jne .conv
    mov byte [rsi], '0'                                ; handle zero
    mov rax, 1
    jmp .done
.conv:
    ; divide by 10 loop
.loop:
    xor rdx, rdx                                       ; clear high for div
    mov r10, 10                                        ; divisor
    div r10            ; rax = rax/10, rdx = remainder ; unsigned div by 10
    add dl, '0'                                        ; remainder to ASCII
    dec rbx                                            ; step back
    mov [rbx], dl                                      ; store digit
    inc rcx                                            ; count++
    test rax, rax                                      ; quotient zero?
    jnz .loop
    ; move to beginning
    mov rax, rcx                                       ; return length
    ; copy rcx bytes from rbx to rsi
    mov r8, rax                                        ; r8 = len
    xor r9, r9                                         ; i = 0
.copy:
    mov dl, [rbx + r9]                                 ; dl = digit
    mov [rsi + r9], dl                                 ; store digit in order
    inc r9
    cmp r9, r8
    jne .copy
.done:
    pop r10
    pop rdx
    pop rbx
    pop rbp
    ret
