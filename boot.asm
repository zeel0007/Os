; =========================================================================
; BOOTLOADER (boot.asm)
; Concept: When a PC turns on, it doesn't know how to run an OS like Windows or Linux.
; Instead, it loads a tiny 512-byte program called a "Bootloader" from the disk 
; into memory. This program's only job is to load the actual Operating System 
; (our Kernel) from the disk into memory, and then tell the CPU to start running it.
; =========================================================================

[org 0x7C00]      ; 'org' stands for Origin. 
                  ; When BIOS loads our bootloader, it ALWAYS places it exactly at 
                  ; memory address 0x7C00. This instruction tells the NASM compiler 
                  ; to calculate all labels and variable memory addresses based 
                  ; on this starting point.

[bits 16]         ; 'bits 16' tells the compiler that we want to generate 16-bit code.
                  ; Why? Because when an x86 processor starts up, it starts in an 
                  ; old compatibility mode called "Real Mode", which is 16-bit.

start:
    ; --- STEP 1: SETUP MEMORY AND STACK ---
    cli           ; 'cli' (Clear Interrupts). This disables hardware interrupts.
                  ; We do this because we are about to change crucial memory registers, 
                  ; and if an interrupt happens while we are changing them, it could crash.

    xor ax, ax    ; 'xor' is a math operation. XORing a register with itself (ax, ax) 
                  ; always results in 0. It is a faster way to say "mov ax, 0".
                  ; We use the AX register as a temporary spot to hold '0'.

    mov ds, ax    ; 'ds' (Data Segment). We set it to 0. 
                  ; Segments are used to access different parts of memory.
    mov es, ax    ; 'es' (Extra Segment). We set it to 0.
    mov ss, ax    ; 'ss' (Stack Segment). We set it to 0.
                  ; Setting them to 0 ensures we don't accidentally write to the wrong memory.

    mov sp, 0x7C00 ; 'sp' (Stack Pointer). The stack is memory used to save temporary variables
                   ; and function return addresses. The stack grows downwards in memory.
                   ; We set it to start right before our bootloader (0x7C00), which is safe.

    sti           ; 'sti' (Set Interrupts). Memory is safely set up, so we can 
                  ; re-enable interrupts.

    ; --- STEP 2: SAVE BOOT DRIVE ---
    ; When BIOS loads us, it stores the ID of the disk we booted from in the 'DL' register.
    ; (e.g., DL=0x00 for floppy, DL=0x80 for hard drive).
    mov [BOOT_DRIVE], dl ; We save this ID from 'dl' into our variable 'BOOT_DRIVE' so we 
                         ; can use it later when we want to load the kernel from the same disk.

    ; --- STEP 3: PRINT A MESSAGE ---
    mov si, msg_loading  ; 'si' (Source Index). We put the address of our text into SI.
                         ; Think of SI as a finger pointing to our text.
    call print_string    ; We jump to the 'print_string' function. When it's done, 
                         ; it will come back here.

    ; --- STEP 4: LOAD KERNEL FROM DISK ---
    call load_kernel     ; Jump to our function that reads the kernel from the disk.

    ; --- STEP 5: JUMP TO THE KERNEL ---
    jmp 0x0000:0x7E00    ; 'jmp' (Jump). We tell the CPU to stop executing here and jump 
                         ; to address 0x7E00. 
                         ; Why 0x7E00? Because our bootloader ends at 0x7DFF (512 bytes long). 
                         ; 0x7E00 is the memory immediately after our bootloader, which is 
                         ; exactly where our 'load_kernel' function put the kernel!

; =========================================================================
; FUNCTION: load_kernel
; Purpose: Reads sectors from the disk into memory using the BIOS
; =========================================================================
load_kernel:
    mov bx, 0x7E00 ; 'bx' (Base Register). We set it to 0x7E00. The BIOS will use BX 
                   ; as the destination address in memory to write the data from the disk.

    ; To talk to the BIOS to read a disk, we trigger "Interrupt 0x13".
    ; Before triggering it, we must put specific values in specific registers 
    ; to tell the BIOS exactly what we want.
    
    mov ah, 0x02   ; 'ah' (Accumulator High). Setting it to 0x02 tells BIOS: "I want to READ disk sectors."
    mov al, 4      ; 'al' (Accumulator Low). How many sectors to read? We want '4' sectors (2048 bytes).
    mov ch, 0      ; 'ch' (Count High). Which Cylinder? Cylinder 0.
    mov dh, 0      ; 'dh' (Data High). Which Head? Head 0.
    mov cl, 2      ; 'cl' (Count Low). Which Sector to start from? Sector 2!
                   ; (Remember: Sector 1 is the 512 bytes of this bootloader itself, 
                   ; so the kernel must start on Sector 2).
    mov dl, [BOOT_DRIVE] ; 'dl' (Data Low). Which drive to read from? Use the one we saved earlier.

    int 0x13       ; 'int' (Interrupt). This is a system call to the BIOS. It basically shouts:
                   ; "Hey BIOS, look at the registers I just set up, and do your disk read magic!"
                   
    jc disk_error  ; 'jc' (Jump if Carry). If the BIOS encounters an error reading the disk, 
                   ; it sets the "Carry Flag" in the CPU. 'jc' checks this flag. 
                   ; If there was an error, jump to 'disk_error'.
    ret            ; 'ret' (Return). If no error, go back to where 'call load_kernel' happened.

disk_error:
    mov si, msg_error    ; Point 'si' to the error message text.
    call print_string    ; Print it.
    jmp $                ; '$' means the current line. 'jmp $' means jump to this exact line.
                         ; This creates an infinite loop, effectively freezing the computer on failure.

; =========================================================================
; FUNCTION: print_string
; Purpose: Prints characters to the screen until it hits a 0.
; =========================================================================
print_string:
    pusha          ; 'pusha' pushes all general-purpose registers onto the stack to save their values.
                   ; We do this so our function doesn't accidentally mess up data being used elsewhere.
.loop:
    lodsb          ; 'lodsb' (Load String Byte). It grabs one byte from memory location [SI], 
                   ; puts it into the 'AL' register, and automatically increments 'SI' to point 
                   ; to the next character in the string.
                   
    test al, al    ; 'test' performs a logical AND operation. Specifically, checking if 'al' is 0.
                   ; In C/C++, strings end with a '\0' (null character, which is exactly 0 in math).
    jz .done       ; 'jz' (Jump if Zero). If the character was 0, our string is finished, so jump to .done.
    
    mov ah, 0x0E   ; 'ah' = 0x0E tells the BIOS "I want to print a character in teletype mode 
                   ; (which means normal typing screen text)".
    int 0x10       ; 'int 0x10' is the BIOS interrupt for Video Services. It prints the character in 'AL'.
    jmp .loop      ; Jump back up to get the next character.
    
.done:
    popa           ; 'popa' pops all registers back from the stack to restore their original values.
    ret            ; Return to the caller.

; =========================================================================
; DATA VARIABLES
; =========================================================================
BOOT_DRIVE db 0          ; 'db' means Define Byte. We reserve 1 byte of memory to store 0.

; Strings. In assembly, we define strings byte-by-byte. 
; '0x0D' is Carriage Return (\r), '0x0A' is Line Feed (\n). This acts like pressing "Enter".
; '0' at the end is the null-terminator so our print function knows when to stop.
msg_loading db "Loading kernel...", 0x0D, 0x0A, 0
msg_error   db "Disk read error!", 0x0D, 0x0A, 0

; =========================================================================
; BOOT SIGNATURE
; =========================================================================
times 510-($-$$) db 0    ; A bootloader MUST be exactly 512 bytes long.
                         ; 'times' is a compiler directive to repeat something.
                         ; '($-$$)' calculates how many bytes of code we've written so far.
                         ; So this says: "Fill the remaining space with '0' until we reach 510 bytes."

dw 0xAA55                ; 'dw' means Define Word (2 bytes). 
                         ; The last 2 bytes of the 512-byte sector MUST ALWAYS be 0xAA and 0x55. 
                         ; This is a "magic signature". If the BIOS doesn't see these two bytes 
                         ; at the end of the 512-byte block, it assumes the disk is NOT bootable 
                         ; and will throw an error instead of running our code.
