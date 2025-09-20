; Entry shim for multi-module program
; Build:
;   nasm -f elf64 util.asm -o util.o
;   nasm -f elf64 password_checker.asm -o password_checker.o
;   ld -o pwcheck util.o password_checker.o

BITS 64

SECTION .text
global _start
%include "password_checker.asm"

_start:
    ; run the checker
    call password_checker_main
    ; exit(0)
    mov rax, 60
    xor rdi, rdi
    syscall
