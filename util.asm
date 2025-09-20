; Entry shim for multi-module program
; Build:
;   nasm -f elf64 util.asm -o util.o
;   nasm -f elf64 password_checker.asm -o password_checker.o
;   ld -o pwcheck util.o password_checker.o

BITS 64

SECTION .data
; Menu strings
menu_banner_top:    db 0x1B,'[36m','┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓',10
len_menu_banner_top equ $-menu_banner_top
menu_banner_mid:    db 0x1B,'[1m',0x1B,'[36m','┃   ASM String Utilities   ┃',10
len_menu_banner_mid equ $-menu_banner_mid
menu_banner_bot:    db 0x1B,'[36m','┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛',10,0x1B,'[0m'
len_menu_banner_bot equ $-menu_banner_bot
menu_items:         db 0x1B,'[35m','[1] ',0x1B,'[0m','Password Checker',10
                    db 0x1B,'[35m','[0] ',0x1B,'[0m','Exit',10
len_menu_items      equ $-menu_items
menu_prompt:        db 0x1B,'[1m','Choose an option: ',0x1B,'[0m'
len_menu_prompt     equ $-menu_prompt
invalid_choice:     db 0x1B,'[31m','Invalid choice.',0x1B,'[0m',10
len_invalid_choice  equ $-invalid_choice
return_menu:        db 10,0x1B,'[90m','Press Enter to return to menu...',0x1B,'[0m'
len_return_menu     equ $-return_menu

SECTION .bss
inbuf:  resb 4

SECTION .text
global _start
%include "password_checker.asm"

_start:
    ; main loop
.menu:
    ; print banner
    mov rax, 1
    mov rdi, 1
    mov rsi, menu_banner_top
    mov rdx, len_menu_banner_top
    syscall
    mov rsi, menu_banner_mid
    mov rdx, len_menu_banner_mid
    mov rax, 1
    syscall
    mov rsi, menu_banner_bot
    mov rdx, len_menu_banner_bot
    mov rax, 1
    syscall

    ; print items
    mov rsi, menu_items
    mov rdx, len_menu_items
    mov rax, 1
    mov rdi, 1
    syscall

    ; prompt
    mov rsi, menu_prompt
    mov rdx, len_menu_prompt
    mov rax, 1
    mov rdi, 1
    syscall

    ; read up to 3 bytes + newline
    mov rax, 0
    mov rdi, 0
    mov rsi, inbuf
    mov rdx, 3
    syscall
    ; interpret first byte
    mov al, [inbuf]
    cmp al, '1'
    je .run_pw
    cmp al, '0'
    je .exit
    ; invalid
    mov rax, 1
    mov rdi, 1
    mov rsi, invalid_choice
    mov rdx, len_invalid_choice
    syscall
    jmp .menu

.run_pw:
    call password_checker_main
    ; wait for Enter to return
    mov rax, 1
    mov rdi, 1
    mov rsi, return_menu
    mov rdx, len_return_menu
    syscall
    ; read and discard line
    mov rax, 0
    mov rdi, 0
    mov rsi, inbuf
    mov rdx, 3
    syscall
    jmp .menu

.exit:
    mov rax, 60
    xor rdi, rdi
    syscall
