#!/bin/bash

set -e

# Purani build files ko delete karein taaki fresh start ho
rm -f *.bin *.o os.img

echo "--- Building HINDI-OS v1.2 with IDT & Memory Manager ---"

# 1. Bootloader aur Kernel Entry ko assemble karein
nasm -f bin boot.asm -o boot.bin
nasm -f elf32 kernel_entry.asm -o kernel_entry.o

# 2. Saari C++ files ko compile karein (.o files banayein)
# -ffreestanding: Matlab koi standard library (C-lib) nahi hai
# -Os: Size optimize karein taaki floppy sectors mein aasaani se fit ho sake
# -fno-exceptions: OS kernel mein exceptions allow nahi hote
i686-elf-g++ -c kernel.cpp -o kernel.o -ffreestanding -Os -fno-exceptions -fno-rtti
i686-elf-g++ -c memory.cpp -o memory.o -ffreestanding -Os -fno-exceptions -fno-rtti
i686-elf-g++ -c idt.cpp -o idt.o -ffreestanding -Os -fno-exceptions -fno-rtti

# 3. Sabko Link karke kernel.bin banayein
# Order bohot zaroori hai: kernel_entry.o sabse pehle hona chahiye
i686-elf-ld -o kernel.bin -T linker.ld kernel_entry.o kernel.o memory.o idt.o --oformat binary

# 4. OS Image (.img) banayein
# Bootloader (512 bytes) + Kernel ko jodein
cat boot.bin kernel.bin > temp.img

# Ek standard Floppy Disk size (1.44MB) ki khali file banayein
dd if=/dev/zero of=os.img bs=1024 count=1440
# Us khali file mein apna OS data bhar dein
dd if=temp.img of=os.img conv=notrunc

# Faltu files delete karein
rm temp.img

echo "--- Build Success! Starting QEMU ---"

# 5. QEMU mein run karein (Full Screen with Zoom to Fit)
qemu-system-i386 -drive format=raw,file=os.img,if=floppy -display cocoa,zoom-to-fit=on,full-screen=on