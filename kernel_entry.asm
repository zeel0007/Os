[bits 32]
[extern kmain]
[extern __bss_start]
[extern __bss_end]
global _start
global idt_load    ; Isse hum C++ mein use kar payenge

_start:
    ; Zero out .bss section
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, edi
    xor eax, eax
    cld
    rep stosb

    call kmain     ; Kernel start karo
    jmp $          ; Agar kmain exit ho jaye toh loop mein raho

; --- IDT LOAD FUNCTION ---
; Ye function C++ se (uint32_t idp_address) leta hai
idt_load:
    mov eax, [esp + 4]  ; Stack se IDTPointer ka address uthao
    lidt [eax]          ; CPU ko batao IDT kahan hai
    ret                 ; Wapas C++ mein jao