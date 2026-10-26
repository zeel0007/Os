#include "idt.h"

IDTEntry idt[256];
IDTPointer idtp;

// Assembly function jo hum baad mein likhenge
extern "C" void idt_load(uint32_t);

void set_idt_gate(uint8_t num, uint32_t base, uint16_t sel, uint8_t flags) {
    idt[num].base_low = base & 0xFFFF;
    idt[num].base_high = (base >> 16) & 0xFFFF;
    idt[num].sel = sel;
    idt[num].always0 = 0;
    idt[num].flags = flags;
}

void init_idt() {
    idtp.limit = (sizeof(IDTEntry) * 256) - 1;
    idtp.base = (uint32_t)&idt;

    // Abhi ke liye hum sirf IDT initialize kar rahe hain
    // Baad mein har hardware ke liye 'set_idt_gate' call karenge
    
    idt_load((uint32_t)&idtp);
}