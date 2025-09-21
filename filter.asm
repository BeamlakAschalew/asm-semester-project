; Filter characters - NASM x86_64 Linux (module) ; Module to filter/transform character streams
; Exposes: filter_main                            ; Entry used by util menu

BITS 64                                            ; Assemble for 64-bit mode

SECTION .data                                      ; UI strings (ANSI)
ft_banner_top: db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10 ; Top banner
ft_len_banner_top equ $-ft_banner_top               ; Length
ft_banner_mid: db 0x1B,'[1m',0x1B,'[36m','┃              Character Filter (ASM)         ┃',10 ; Title
ft_len_banner_mid equ $-ft_banner_mid               ; Length
ft_banner_bot: db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m' ; Bottom + reset
ft_len_banner_bot equ $-ft_banner_bot               ; Length
ft_prompt_text: db 0x1B,'[1m','Enter text ',0x1B,'[0m',0x1B,'[90m','(Ctrl+D to finish):',0x1B,'[0m',10 ; Text prompt
ft_len_prompt_text equ $-ft_prompt_text             ; Length
ft_prompt_mode: db 10,0x1B,'[1m','Mode: ',0x1B,'[0m','[1] Digits  [2] Letters  [3] Punctuation  [4] Remove chosen chars',10 ; Mode menu
ft_len_prompt_mode equ $-ft_prompt_mode             ; Length
ft_prompt_remove: db 0x1B,'[1m','Characters to remove: ',0x1B,'[0m' ; Removal set prompt
ft_len_prompt_remove equ $-ft_prompt_remove         ; Length
ft_output_hdr: db 10,0x1B,'[1m','Filtered output:',0x1B,'[0m',10 ; Output header
ft_len_output_hdr equ $-ft_output_hdr               ; Length

SECTION .bss                                        ; Buffers
ft_text: resb 65536                                 ; Input text buffer (64 KiB)
ft_len:  resq 1                                     ; Length of input text
ft_in:   resb 4                                     ; Small input buffer for mode selection
ft_rmset: resb 256                                  ; Set of characters to remove (mode 4)
ft_rmlen: resq 1                                    ; Length of removal set

SECTION .text                                       ; Code
global filter_main                                   ; Export symbol

filter_main:
    push rbp                                        ; Prologue
    mov rbp, rsp                                     ; Establish frame
    push rbx                                         ; Save callee-saved regs
    push r12
    push r13

    ; banner
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ft_banner_top                           ; top
    mov rdx, ft_len_banner_top                       ; len
    syscall
    mov rsi, ft_banner_mid                           ; mid
    mov rdx, ft_len_banner_mid                       ; len
    mov rax, 1                                       ; sys_write
    syscall
    mov rsi, ft_banner_bot                           ; bottom
    mov rdx, ft_len_banner_bot                       ; len
    mov rax, 1                                       ; sys_write
    syscall

    ; read text
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ft_prompt_text                          ; prompt for text
    mov rdx, ft_len_prompt_text                      ; len
    syscall
    xor rbx, rbx                                     ; total read = 0
.rloop:
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel ft_text]                           ; buffer base
    add rsi, rbx                                     ; append position
    mov rdx, 65536                                   ; capacity
    sub rdx, rbx                                     ; remaining
    cmp rdx, 0                                       ; full?
    je .rdone
    syscall
    test rax, rax                                    ; <= 0 ?
    jz .rdone                                        ; EOF
    js .rdone                                        ; error
    add rbx, rax                                     ; accumulate
    cmp rbx, 65536                                   ; limit
    jb .rloop
.rdone:
    mov [ft_len], rbx                                ; store length

    ; mode
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ft_prompt_mode                          ; mode menu
    mov rdx, ft_len_prompt_mode                      ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    mov rsi, ft_in                                   ; buffer for choice
    mov rdx, 2                                       ; read up to 2 (char + \n)
    syscall
    mov al, [ft_in]                                  ; choice char
    mov bl, 1           ; default digits             ; mode = 1 by default
    cmp al, '2'
    jne .chk3
    mov bl, 2           ; letters                    ; mode = 2
    jmp .have_mode
.chk3:
    cmp al, '3'
    jne .have_mode
    mov bl, 3           ; punctuation                ; mode = 3
.have_mode:

    ; if remove-chosen mode, read removal set
    cmp al, '4'                                      ; chosen mode '4'?
    jne .after_remove_input
    mov bl, 4           ; mark mode 4                 ; set mode var
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ft_prompt_remove                        ; ask for chars to remove
    mov rdx, ft_len_prompt_remove                    ; len
    syscall
    mov rax, 0                                       ; sys_read
    mov rdi, 0                                       ; stdin
    lea rsi, [rel ft_rmset]                          ; buffer
    mov rdx, 255                                     ; up to 255 bytes
    syscall
    ; strip trailing newline
    mov rcx, rax                                     ; rcx = bytes read
    test rcx, rcx                                    ; zero?
    jz .setrmlen                                     ; nothing
    dec rcx                                          ; last index
    jl .setrmlen                                     ; negative => zero
    mov dl, [ft_rmset + rcx]                         ; last byte
    cmp dl, 10                                       ; newline?
    jne .setrmlen2
    mov rax, rcx                                     ; exclude newline
    jmp .setrmlen
.setrmlen2:
    mov rax, rcx                                     ; include last byte
    inc rax
.setrmlen:
    mov [ft_rmlen], rax                              ; store removal set length
.after_remove_input:

    ; output header
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    mov rsi, ft_output_hdr                           ; header
    mov rdx, ft_len_output_hdr                       ; len
    syscall

    ; filter
    xor r12, r12                                     ; i = 0
    mov r13, [ft_len]                                ; n = input length
.floop:
    cmp r12, r13                                     ; i >= n ?
    jae .done
    mov dl, [ft_text + r12]                          ; dl = current byte
    ; digits
    cmp bl, 1                                        ; mode == 1 ?
    jne .chk_letters
    cmp dl, '0'                                      ; below '0'?
    jb .next
    cmp dl, '9'                                      ; above '9'?
    ja .next
    jmp .emit                                        ; emit digits only
.chk_letters:
    cmp bl, 2                                        ; mode == 2 ?
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
    cmp bl, 4                                        ; mode == 4 ? then go to removal set logic
    je .chk_remove
    cmp dl, 32                                       ; below space => non-printable
    jb .next
    cmp dl, 126                                      ; above '~' => non-printable
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
    cmp dl, ' '                                      ; exclude space
    je .next
    jmp .emit                                        ; remaining printable punctuation

.chk_remove:
    ; mode 4: remove any character present in removal set
    mov rcx, [ft_rmlen]                              ; set length
    cmp rcx, 0
    je .emit            ; nothing to remove => pass-through
    lea rsi, [rel ft_rmset]                          ; ptr to set
.rm_loop:
    cmp rcx, 0
    je .emit                                         ; not found in set => keep
    mov al, [rsi]                                    ; al = set byte
    cmp al, dl
    je .next            ; skip emitting this char
    inc rsi
    dec rcx
    jmp .rm_loop

.emit:
    mov rax, 1                                       ; sys_write
    mov rdi, 1                                       ; stdout
    lea rsi, [rel ft_text]                           ; reuse ft_text[0] as single-byte temp
    mov [ft_text], dl   ; reuse buffer to hold single byte ; store byte
    mov rsi, ft_text                                ; pointer to temp byte
    mov rdx, 1                                       ; len=1
    syscall
.next:
    inc r12                                          ; i++
    jmp .floop

.done:
    pop r13                                          ; Restore regs
    pop r12
    pop rbx
    pop rbp                                          ; Epilogue
    ret                                              ; Return to caller
