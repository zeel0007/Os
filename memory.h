#ifndef MEMORY_H
#define MEMORY_H

// Memory functions
void init_memory();
void* kmalloc(unsigned int size);
void kfree(void* ptr);

#endif