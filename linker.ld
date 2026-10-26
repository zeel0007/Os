ENTRY(_start)
SECTIONS
{
    . = 0x1000;
    .text : { 
        kernel_entry.o(.text) 
        *(.text .text.*) 
    }
    .rodata : { 
        *(.rodata .rodata.*) 
    }
    .data : { 
        *(.data) 
    }
    .bss : { 
        __bss_start = .;
        *(.bss) 
        __bss_end = .;
    }
}