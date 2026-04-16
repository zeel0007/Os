#!/bin/bash
# Exit on error
set -e

echo "Building bootloader..."
nasm -f bin boot.asm -o boot.bin

echo "Building kernel..."
nasm -f bin kernel.asm -o kernel.bin

echo "Creating floppy image (os.img)..."
# Create a 1.4MB empty image
dd if=/dev/zero of=os.img bs=1024 count=1440 2>/dev/null

# Insert boot.bin at the first sector (Sector 1)
dd if=boot.bin of=os.img conv=notrunc 2>/dev/null

# Insert kernel.bin right after the bootloader (Sector 2 onward)
dd if=kernel.bin of=os.img seek=1 conv=notrunc 2>/dev/null

echo "Build successful! Run the following command to start QEMU:"
echo "qemu-system-i386 -drive format=raw,file=os.img"
