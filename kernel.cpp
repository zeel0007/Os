#include "memory.h" // Memory manager ke functions use karne ke liye

/* --- HARDWARE I/O --- */
unsigned char inb(unsigned short port) {
    unsigned char result;
    __asm__ volatile("inb %1, %0" : "=a" (result) : "Nd" (port));
    return result;
}

void outb(unsigned short port, unsigned char val) {
    __asm__ volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

void outw(unsigned short port, unsigned short val) {
    __asm__ volatile("outw %0, %1" : : "a"(val), "Nd"(port));
}

/* --- STRING UTILITIES --- */
bool str_equal(const char* s1, const char* s2) {
    int i = 0;
    while (s1[i] && s2[i]) {
        if (s1[i] != s2[i]) return false;
        i++;
    }
    return s1[i] == s2[i];
}

bool str_starts_with(const char* str, const char* prefix) {
    int i = 0;
    while (prefix[i] != '\0') {
        if (str[i] != prefix[i]) return false;
        i++;
    }
    return true;
}

int atoi(const char* s) {
    int res = 0, i = 0;
    while (s[i] == ' ') i++; 
    while (s[i] >= '0' && s[i] <= '9') {
        res = res * 10 + (s[i] - '0');
        i++;
    }
    return res;
}

void itoa(int n, char* str) {
    int i = 0;
    if (n == 0) { str[i++] = '0'; str[i] = '\0'; return; }
    bool neg = false;
    if (n < 0) {
        neg = true;
        n = -n;
    }
    char temp[12]; int j = 0;
    while (n > 0) { temp[j++] = (n % 10) + '0'; n /= 10; }
    if (neg) str[i++] = '-';
    while (j > 0) str[i++] = temp[--j];
    str[i] = '\0';
}

/* --- SCREEN DRIVER --- */
class Screen {
public:
    unsigned short* buffer = (unsigned short*)0xB8000;
    int cursor = 0;
    char current_color = 0x1F; 

    void clear() {
        for(int i = 0; i < 80 * 25; i++) buffer[i] = (unsigned short)' ' | (current_color << 8);
        cursor = 0;
    }

    void set_full_color(char color_byte) {
        current_color = color_byte;
        clear();
    }

    void scroll() {
        for (int i = 0; i < 80 * 24; i++) {
            buffer[i] = buffer[i + 80];
        }
        for (int i = 80 * 24; i < 80 * 25; i++) {
            buffer[i] = (unsigned short)' ' | (current_color << 8);
        }
        cursor = 80 * 24;
    }

    void print_char(char c) {
        if (c == '\n') {
            cursor = (cursor / 80 + 1) * 80;
        } else if (c == 0x08 && cursor > 0) {
            cursor--;
            buffer[cursor] = (unsigned short)' ' | (current_color << 8);
        } else if (c >= ' ') {
            buffer[cursor++] = (unsigned short)c | (current_color << 8);
        }

        if (cursor >= 80 * 25) {
            scroll();
        }
    }

    void print(const char* str) {
        for(int i = 0; str[i] != '\0'; i++) print_char(str[i]);
    }
};

/* --- KEYBOARD MAP --- */
char get_ascii(unsigned char sc) {
    switch(sc) {
        case 0x1E: return 'a'; case 0x30: return 'b'; case 0x2E: return 'c';
        case 0x20: return 'd'; case 0x12: return 'e'; case 0x21: return 'f';
        case 0x22: return 'g'; case 0x23: return 'h'; case 0x17: return 'i';
        case 0x24: return 'j'; case 0x25: return 'k'; case 0x26: return 'l';
        case 0x32: return 'm'; case 0x31: return 'n'; case 0x18: return 'o';
        case 0x19: return 'p'; case 0x10: return 'q'; case 0x13: return 'r';
        case 0x1F: return 's'; case 0x14: return 't'; case 0x16: return 'u';
        case 0x2F: return 'v'; case 0x11: return 'w'; case 0x2D: return 'x';
        case 0x15: return 'y'; case 0x2C: return 'z';
        case 0x02: return '1'; case 0x03: return '2'; case 0x04: return '3';
        case 0x05: return '4'; case 0x06: return '5'; case 0x07: return '6';
        case 0x08: return '7'; case 0x09: return '8'; case 0x0A: return '9';
        case 0x0B: return '0';
        case 0x39: return ' '; case 0x1C: return '\n'; case 0x0E: return 0x08;
        default: return 0;
    }
}

/* --- MATH HANDLER --- */
void handle_math(Screen& term, char* cmd, char op) {
    int val1 = atoi(cmd + 4);
    int i = 4;
    while (cmd[i] != ' ' && cmd[i] != '\0') i++;
    int val2 = atoi(cmd + i);
    int res = 0;
    if (op == '+') res = val1 + val2;
    if (op == '-') res = val1 - val2;
    if (op == '*') res = val1 * val2;
    if (op == '/' && val2 != 0) res = val1 / val2;
    char out[16]; itoa(res, out);
    term.print("Result: "); term.print(out); term.print("\n");
}

/* --- HELP DISPLAY --- */
void show_help(Screen& term) {
    term.print("Commands available:\n");
    term.print("  help        - Displays the command list\n");
    term.print("  echo <msg>  - Prints back text\n");
    term.print("  admin       - Toggles Matrix green text mode\n");
    term.print("  add <X> <Y> - Computes sum\n");
    term.print("  clear       - Clears screen\n");
    term.print("  testmem     - Exercises dynamic memory allocation (kmalloc / kfree)\n");
    term.print("  shutdown    - Power off system (or 'exit')\n");
    term.print("  reboot      - Restart system\n");
}

/* --- KERNEL MAIN --- */
extern "C" void kmain() {
    init_memory(); // RAM management start karo
    
    Screen term;
    term.clear();
    term.print("zeel-OS v1.2 | MEMORY & ADMIN READY\n\n");
    show_help(term);
    term.print("\n");

    char cmd[64];
    int cmd_i = 0;

    while(1) {
        term.print("> ");
        cmd_i = 0;
        while(1) {
            if(inb(0x64) & 1) {
                unsigned char sc = inb(0x60);
                if (sc & 0x80) continue;
                char c = get_ascii(sc);
                if (c == '\n') {
                    cmd[cmd_i] = '\0';
                    term.print_char('\n');
                    break;
                } else if (c == 0x08 && cmd_i > 0) {
                    cmd_i--;
                    term.print_char(0x08);
                } else if (c != 0 && cmd_i < 63) {
                    cmd[cmd_i++] = c;
                    term.print_char(c);
                }
            }
        }

        // --- COMMANDS ---
        if (str_equal(cmd, "help")) {
            show_help(term);
        } 
        else if (str_equal(cmd, "clear")) {
            term.clear();
        } 
        else if (str_equal(cmd, "admin")) {
            term.set_full_color(0x0A); // Matrix Green
            term.print("ADMIN MODE ENABLED\n");
        } 
        else if (str_starts_with(cmd, "echo ")) {
            term.print(cmd + 5); term.print("\n");
        } 
        else if (str_starts_with(cmd, "add ")) {
            handle_math(term, cmd, '+');
        } 
        else if (str_equal(cmd, "testmem")) {
            term.print("Allocating memory test...\n");
            char* test_ptr = (char*)kmalloc(32);
            if(test_ptr) {
                test_ptr[0] = 'M'; test_ptr[1] = 'E'; test_ptr[2] = 'M';
                test_ptr[3] = ' '; test_ptr[4] = 'O'; test_ptr[5] = 'K';
                test_ptr[6] = '\0';
                term.print("Data in heap: "); term.print(test_ptr); term.print("\n");
                kfree(test_ptr);
                term.print("Memory freed successfully.\n");
            } else {
                term.print("Memory Allocation Failed!\n");
            }
        }
        else if (str_equal(cmd, "exit") || str_equal(cmd, "shutdown")) {
            term.print("Shutting down...\n");
            outw(0x604, 0x2000);
            outw(0xB004, 0x2000);
            __asm__ volatile("cli; hlt");
        }
        else if (str_equal(cmd, "reboot")) {
            term.print("Rebooting...\n");
            outb(0x64, 0xFE);
            __asm__ volatile("cli; hlt");
        }
        else if (cmd_i > 0) {
            term.print("Command unknown. Type 'help' for options.\n");
        }
    }
}