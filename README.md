# zeel-OS (HINDI-OS v1.2)

A custom 32-bit x86 Operating System written in Assembly and C++, featuring a two-stage bootloader, 32-bit protected mode kernel, dynamic memory management (Heap `kmalloc`/`kfree`), VGA text driver with scrolling, and an interactive shell.

---

## Architecture & Boot Flow

```
+-------------------------------------------------------------+
| 1. BIOS POST -> Loads boot.bin (Sector 1) to 0x7C00         |
| 2. boot.asm (Real Mode) -> Loads kernel (Sectors 2-17)      |
|    into RAM at 0x1000 using BIOS int 0x13 ah=0x02           |
| 3. gdt.asm -> Sets up GDT & switches CPU to 32-bit PM (CR0) |
| 4. kernel_entry.asm -> Zeros .bss and calls kmain()         |
| 5. kernel.cpp -> Starts Memory Manager & Shell Interface    |
+-------------------------------------------------------------+
```

---

## Memory Layout

| Address | Description |
| :--- | :--- |
| `0x00000 - 0x003FF` | BIOS Interrupt Vector Table (IVT) |
| `0x01000 - 0x02FFF` | Kernel Code & Data (`kernel.bin`) |
| `0x07C00 - 0x07DFF` | Bootloader Sector (`boot.bin`) |
| `0x90000` | 32-bit Protected Mode Stack (`ESP`) |
| `0xB8000 - 0xB8FA0` | VGA Text Video Memory (80x25 color text) |
| `0x100000` (1MB) | Dynamic Heap Memory (`kmalloc` / `kfree`) |

---

## Features

- **32-Bit Protected Mode**: Custom GDT configuration with flat 4GB addressing.
- **Dynamic Memory Manager**: Linked-list based heap allocator (`kmalloc` & `kfree`) starting at 1MB boundary with memory coalescing.
- **VGA Driver with Scrolling**: Direct memory-mapped I/O to `0xB8000` with color attribute support and automatic 25-line vertical scrolling.
- **PS/2 Keyboard Driver**: Port I/O (`inb`, `outb`, `outw`) with scancode decoding, backspace erasing, and buffer handling.
- **Built-in Shell Commands**:
  - `help` - Display available commands
  - `echo <msg>` - Print messages to console
  - `admin` - Toggle Matrix green text mode
  - `add <X> <Y>` - Arithmetic calculation
  - `clear` - Clear console screen
  - `testmem` - Exercise dynamic memory allocation on heap
  - `shutdown` / `exit` - Power off system via QEMU ACPI port
  - `reboot` - CPU reset via 8042 keyboard controller

---

## Prerequisites

- **NASM** (Netwide Assembler)
- **i686-elf-gcc / i686-elf-g++ & i686-elf-ld** (Cross-compiler toolchain)
- **QEMU** (`qemu-system-i386`)

Install on macOS via Homebrew:
```bash
brew install nasm qemu
brew tap nativeos/i686-elf-toolchain
brew install i686-elf-binutils i686-elf-gcc
```

---

## Build & Run

Run the build script:
```bash
./build.sh
```

Or assemble and launch manually:
```bash
# Assemble bootloader & kernel entry
nasm -f bin boot.asm -o boot.bin
nasm -f elf32 kernel_entry.asm -o kernel_entry.o

# Compile C++ files
i686-elf-g++ -c kernel.cpp -o kernel.o -ffreestanding -Os -fno-exceptions -fno-rtti
i686-elf-g++ -c memory.cpp -o memory.o -ffreestanding -Os -fno-exceptions -fno-rtti
i686-elf-g++ -c idt.cpp -o idt.o -ffreestanding -Os -fno-exceptions -fno-rtti

# Link kernel
i686-elf-ld -o kernel.bin -T linker.ld kernel_entry.o kernel.o memory.o idt.o --oformat binary

# Create Floppy disk image
cat boot.bin kernel.bin > temp.img
dd if=/dev/zero of=os.img bs=1024 count=1440
dd if=temp.img of=os.img conv=notrunc
rm temp.img

# Run in QEMU
qemu-system-i386 -drive format=raw,file=os.img,if=floppy -display cocoa,zoom-to-fit=on,full-screen=on
```
