#ifndef IDT_H
#define IDT_H

#include <stdint.h>

// Har interrupt entry 8 bytes ki hoti hai
struct IDTEntry {
    uint16_t base_low;  // Handler address ka niche wala hissa
    uint16_t sel;       // Kernel segment selector
    uint8_t  always0;   // Hamesha 0 rehta hai
    uint8_t  flags;     // Access flags (P, DPL, Type)
    uint16_t base_high; // Handler address ka upar wala hissa
} __attribute__((packed));

// Ye CPU ko IDT ki location batane ke liye hota hai
struct IDTPointer {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

void init_idt();

#endif