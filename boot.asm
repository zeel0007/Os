[org 0x7c00]
KERNEL_OFFSET equ 0x1000

; Zero out segments
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

; Save boot drive
mov [BOOT_DRIVE], dl

; Reset Disk
xor ax, ax
mov dl, [BOOT_DRIVE]
int 0x13

call load_kernel
call switch_to_pm
jmp $

%include "gdt.asm"

[bits 16]
load_kernel:
    mov ah, 0x02
    mov al, 16        ; Load 16 sectors (8KB) so the entire kernel is loaded
    mov ch, 0x00        ; Cylinder 0
    mov dh, 0x00        ; Head 0
    mov cl, 0x02        ; Sector 2 (Kernel starts here)
    mov dl, [BOOT_DRIVE]
    mov bx, KERNEL_OFFSET
    int 0x13
    jc disk_error       ; If carry flag is set, something went wrong
    ret

disk_error:
    jmp $

[bits 32]
BEGIN_PM:
    call KERNEL_OFFSET
    jmp $

BOOT_DRIVE db 0
times 510-($-$$) db 0
dw 0xaa55