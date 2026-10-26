#include "memory.h"

// Memory block ka header
struct MemoryBlock {
    unsigned int size;
    bool is_free;
    struct MemoryBlock* next;
};

// Heap start address (1MB mark)
MemoryBlock* free_list = (MemoryBlock*)0x100000;

void init_memory() {
    // Shuruat mein humare paas 1MB ki ek badi khali memory hai
    free_list->size = 1024 * 1024; 
    free_list->is_free = true;
    free_list->next = 0; // Null
}

void* kmalloc(unsigned int size) {
    MemoryBlock* current = free_list;

    while (current) {
        // Agar block khali hai aur zaroorat ke hisab se bada hai
        if (current->is_free && current->size >= size) {
            
            // Kya is block ko do hisson mein todna chahiye?
            // (Sirf tabhi todenge jab bacha hua hissa header se bada ho)
            if (current->size > (size + sizeof(MemoryBlock) + 4)) {
                MemoryBlock* new_block = (MemoryBlock*)((char*)current + sizeof(MemoryBlock) + size);
                
                new_block->size = current->size - size - sizeof(MemoryBlock);
                new_block->is_free = true;
                new_block->next = current->next;

                current->size = size;
                current->next = new_block;
            }

            current->is_free = false;
            // Header ke thoda aage ka address return karein jahan data store hoga
            return (void*)((char*)current + sizeof(MemoryBlock));
        }
        current = current->next;
    }
    return 0; // RAM full!
}

void kfree(void* ptr) {
    if (!ptr) return;

    // Pointer se thoda peeche jaakar header nikaalein
    MemoryBlock* block = (MemoryBlock*)((char*)ptr - sizeof(MemoryBlock));
    block->is_free = true;

    // --- COALESCING (Memory Optimization) ---
    // Agar agla block bhi khali hai, toh dono ko ek bada block bana do
    MemoryBlock* current = free_list;
    while (current && current->next) {
        if (current->is_free && current->next->is_free) {
            current->size += current->next->size + sizeof(MemoryBlock);
            current->next = current->next->next;
        }
        current = current->next;
    }
}