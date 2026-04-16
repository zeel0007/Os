; =========================================================================
; THE KERNEL (kernel.asm)
; =========================================================================
; This is the actual Operating System. The bootloader loaded us into memory 
; and gave us control. Our job is to provide an interface (a shell) so the 
; user can type commands, just like the Windows Command Prompt or Linux Terminal.

[org 0x7E00]      ; The bootloader loaded us at memory address 0x7E00. 
                  ; Telling the compiler this ensures all our string variables 
                  ; calculate their memory positions correctly.

[bits 16]         ; We are still in 16-bit real mode. 

start:
    ; When the bootloader does 'jmp 0x7E00', the CPU starts executing right here!
    mov si, msg_welcome  ; 'si' points to our "Welcome" text.
    call print_string    ; Call our print function to display it.

; =========================================================================
; MAIN SHELL LOOP
; Think of this like: while(true) { print(">"); input = get_input(); handle(input); }
; =========================================================================
shell_loop:
    ; 1. Print the prompt symbol (e.g., "> ")
    mov si, prompt       
    call print_string    

    ; 2. Wait for the user to type something and press Enter
    call read_input      

    ; 3. Look at what they typed and figure out what to do
    call process_command 

    ; 4. Jump back to the top of the loop and do it again forever
    jmp shell_loop       

; =========================================================================
; FUNCTION: read_input
; Purpose: Captures keystrokes, prints them to the screen, handles Backspace,
;          and saves the final text into the 'input_buffer' memory.
; =========================================================================
read_input:
    mov di, input_buffer ; 'di' (Destination Index). We point DI to our empty variable 
                         ; 'input_buffer' where we will store the user's text.
    mov cx, 0            ; 'cx' (Count Register). We'll use this to keep track of how 
                         ; many characters the user has typed. We start at 0.
.loop:
    mov ah, 0x00    ; 'ah' = 0x00 tells BIOS: "I want to read a single key press."
    int 0x16        ; Call BIOS Keyboard Services. The CPU will freeze here and wait a 
                    ; millisecond or hours until the user physically presses a key on the keyboard.
                    ; When a key is pressed, its ASCII code (like 'a' = 97) is put into 'AL'.

    ; Let's check what key they pressed:
    cmp al, 0x0D    ; 'cmp' (Compare). Compare 'al' to 0x0D. (0x0D is the "Enter" key).
    je .done        ; 'je' (Jump if Equal). If they pressed Enter, we are done typing! Jump to .done.

    cmp al, 0x08    ; Compare 'al' to 0x08. (0x08 is the "Backspace" key).
    je .backspace   ; If they pressed Backspace, jump to the backspace handling code.

    cmp cx, 63      ; Did they type 63 characters already? (Our buffer can only hold 64 bytes).
    jge .loop       ; 'jge' (Jump if Greater or Equal). If yes, the buffer is full. Ignore the 
                    ; key press and go back to .loop waiting for them to press Enter or Backspace.

    ; If it wasn't Enter, and wasn't Backspace, it's a normal letter.
    stosb           ; 'stosb' takes the character in 'AL' and writes it to memory at [DI] 
                    ; (our buffer). Then, it automatically moves DI forward by 1 byte.
                    
    inc cx          ; 'inc' (Increment). Add 1 to our character count (cx = cx + 1).
    
    mov ah, 0x0E    ; Tell Video BIOS: "Teletype print"
    int 0x10        ; Print the character they just typed so they can see it on screen.
    jmp .loop       ; Go back to waiting for the next key press.

; --- Backspace Logic ---
.backspace:
    cmp cx, 0       ; Is character count 0? (Meaning, did they hit backspace on an empty line?)
    je .loop        ; If yes, there's nothing to delete. Ignore it and go back to waiting.

    dec di          ; 'dec' (Decrement). Move our destination buffer pointer back 1 space, 
                    ; effectively overwriting the last letter they typed.
    dec cx          ; Subtract 1 from our character count.
    
    ; Now we must visually erase the character from the screen.
    ; This is a classic trick: Move Cursor Left, Print a Blank Space, Move Cursor Left again.
    mov ah, 0x0E    ; Text output mode
    mov al, 0x08    ; Character 0x08 moves the cursor to the left by 1.
    int 0x10        ; Cursor moves left.
    mov al, ' '     ; Space character.
    int 0x10        ; Print space (this overwrites the letter with a blank, erasing it visually).
    mov al, 0x08    ; Character 0x08 moves the cursor left again.
    int 0x10        ; Cursor moves left over the space, ready for new typing.
    
    jmp .loop       ; Go back to waiting.

.done:
    mov al, 0       ; Put '0' in AL.
    stosb           ; Store the '0' at the end of the text in the buffer.
                    ; Strings in C/C++/Assembly expect a 0 byte to signify the "end of text",
                    ; also known as a null-terminator.
    
    mov si, newline ; Point SI to a carriage-return/newline string.
    call print_string ; Print it, so the terminal drops down a line after they hit enter.
    ret             ; Go back to 'shell_loop'.

; =========================================================================
; FUNCTION: process_command
; Purpose: Looks at the 'input_buffer' and determines if it matches 
;          "help", "clear", "about", or "echo".
; =========================================================================
process_command:
    cmp byte [input_buffer], 0  ; Check the very first byte of the buffer. Is it 0?
    je .done                    ; If it is, the user just pressed "Enter" without typing anything. 
                                ; Jump to .done and ignore it.

    ; --- CHECK FOR "help" ---
    mov si, input_buffer ; Set 'si' to user's typed text.
    mov di, cmd_help     ; Set 'di' to our internal string "help".
    call strcmp          ; Call string comparison. It will set Carry Flag if they match exactly.
    jc .do_help          ; 'jc' (Jump if Carry). If it matched, jump to .do_help.

    ; --- CHECK FOR "clear" ---
    mov si, input_buffer
    mov di, cmd_clear
    call strcmp
    jc .do_clear

    ; --- CHECK FOR "about" ---
    mov si, input_buffer
    mov di, cmd_about
    call strcmp
    jc .do_about

    ; --- CHECK FOR "echo " ---
    mov si, input_buffer
    mov di, cmd_echo_prefix ; Look for the prefix "echo "
    call strncmp            ; Notice we call 'strncmp', which only checks the beginning.
                            ; If they typed "echo hello", the prefix "echo " matches!
    jc .do_echo

    ; --- IF WE GET HERE, NO COMMAND MATCHED! ---
    mov si, msg_unknown  ; "Unknown command: "
    call print_string
    mov si, input_buffer ; Print the garbage they typed
    call print_string
    mov si, newline      ; Print an Enter space
    call print_string
    jmp .done            ; All done processing.

; --- COMMAND EXECUTORS ---
; These are just blocks of code that print the relevant texts based on the command.

.do_help:
    mov si, msg_help
    call print_string
    jmp .done

.do_clear:
    call clear_screen
    jmp .done

.do_about:
    mov si, msg_about
    call print_string
    jmp .done

.do_echo:
    ; To echo, we want to print whatever came AFTER "echo ". 
    ; "echo " is exactly 5 characters long. 
    ; So if we take the start of their text (input_buffer) and add 5, 
    ; we skip the word "echo " and print directly what follows!
    mov si, input_buffer + 5 
    call print_string
    mov si, newline
    call print_string
    jmp .done

.done:
    ret ; Return back to shell_loop

; =========================================================================
; UTILITY: strcmp (String Compare Full)
; Checks if two strings are exactly identical.
; Returns: Carry Flag (CF) = 1 if match, 0 if no match.
; =========================================================================
strcmp:
    pusha           ; Save registers
.loop:
    mov al, [si]    ; Grab a letter from String 1
    mov bl, [di]    ; Grab a letter from String 2
    cmp al, bl      ; Compare them
    jne .not_equal  ; 'jne' (Jump if Not Equal). If they differ, string match fails.
    cmp al, 0       ; If they are equal, check if it was a '0' (end of string).
    je .equal       ; If we reached the end together, they are a perfect match!
    inc si          ; Move String 1 pointer forward by 1 letter
    inc di          ; Move String 2 pointer forward by 1 letter
    jmp .loop       ; Go to next letter
.not_equal:
    popa            ; Restore registers
    clc             ; 'clc' (Clear Carry). Sets Carry Flag to 0 (Failure)
    ret
.equal:
    popa            ; Restore registers
    stc             ; 'stc' (Set Carry). Sets Carry Flag to 1 (Success)
    ret

; =========================================================================
; UTILITY: strncmp (String Compare Prefix)
; Checks if String 2 (DI) is the starting prefix of String 1 (SI).
; =========================================================================
strncmp:
    pusha
.loop:
    mov bl, [di]    ; Grab letter from Prefix.
    cmp bl, 0       ; Did we reach the end of the prefix?
    je .equal       ; If yes, the prefix fully matched the start of the string! Success!
    mov al, [si]    ; Grab letter from User's String.
    cmp al, bl      ; Compare
    jne .not_equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc             ; Failure
    ret
.equal:
    popa
    stc             ; Success
    ret

; =========================================================================
; UTILITY: clear_screen
; Clears the entire text console display.
; =========================================================================
clear_screen:
    pusha
    ; Video mode 0x03 is the standard 80 columns by 25 rows color text mode.
    ; Calling BIOS to set the video mode automatically clears the screen as a side effect!
    mov ah, 0x00    ; 'ah' = 0x00 (Set Video Mode function)
    mov al, 0x03    ; 'al' = 0x03 (Text mode 80x25)
    int 0x10        ; Trigger video BIOS
    popa
    ret

; =========================================================================
; UTILITY: print_string
; =========================================================================
print_string:
    pusha
.loop:
    lodsb          ; Load byte at DS:SI into AL and increment SI
    test al, al    ; Check if AL is 0
    jz .done
    mov ah, 0x0E   ; Teletype output
    int 0x10
    jmp .loop
.done:
    popa
    ret

; =========================================================================
; DATA SECTION
; All our fixed strings that we want to print to the screen.
; memory locations are basically assigned based on the order here.
; =========================================================================
msg_welcome db "Kernel loaded successfully!", 0x0D, 0x0A, "Type 'help' for commands.", 0x0D, 0x0A, 0
prompt db "> ", 0
newline db 0x0D, 0x0A, 0
msg_unknown db "Unknown command: ", 0

cmd_help db "help", 0
cmd_clear db "clear", 0
cmd_about db "about", 0
cmd_echo_prefix db "echo ", 0

msg_help db "Available commands:", 0x0D, 0x0A
         db "  help  - Show this message", 0x0D, 0x0A
         db "  clear - Clear the screen", 0x0D, 0x0A
         db "  echo  - Print text to screen", 0x0D, 0x0A
         db "  about - Show OS info", 0x0D, 0x0A, 0

msg_about db "Custom OS Kernel - v1.0", 0x0D, 0x0A, "Running in 16-bit real mode.", 0x0D, 0x0A, 0

; =========================================================================
; BSS SECTION / EMPTY MEMORY
; =========================================================================
; 'times 64 db 0' creates 64 empty bytes of memory initialized to 0.
; This acts as the physical space to store characters the user types in read_input.
input_buffer times 64 db 0
