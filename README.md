# Custom OS - Line by Line Explanation (Hinglish)

Namaste! 🙏 Is guide mein hum apne custom Operating System ke code ko line-by-line samjhenge. Hum jaanenge ki PC kaise start hota hai, bootloader kya karta hai aur finally hamara kernel (shell) run kaise hota hai.

## 1. Boot Process - Kaam Kaise Karta Hai?

Jab system on hota hai, BIOS sabse pehle hardware check karta hai aur fir bootable disk dhundhta hai. Disk ka sabse pehla sector (chhota sa 512 bytes ka hissa) BIOS automatically memory address `0x7C00` par la k copy kar deta hai aur usko run karna start deta hai. 
Isi pehle sector ko **"Bootloader"** kehte hain. 

Bootloader ka bas ek ahem kaam hota hai: disk ke agle sectors (baki ka bada data) se apne main OS (Kernel) ko memory me read karke laana aur CPU control wahan transfer kar dena.

---

## 2. Bootloader (`boot.asm`) Line-by-Line

```nasm
[org 0x7C00]      ; Ye compiler (NASM) ko batata hai ki BIOS is code ko fixed memory address 0x7C00 par laake load karega, toh saare variables us hisaab se align kro.
[bits 16]         ; CPU start hote hi purane 16-bit "Real Mode" mein hota hai, isiliye humein 16-bit mode ka support set karna pada.

start:
    cli           ; (Clear Interrupts): CPU interrupts (rukawateh) disable kar do jab tak hum memory aur stack properly setup na kar lein.
    xor ax, ax    ; ax register ko 0 kar diya (xor ax, ax = mathmeatically ax to 0, jo CPU me fast hota hai).
    mov ds, ax    ; Data Segment (DS) register ko 0 par set kiya taaki data shi set ho.
    mov es, ax    ; Extra Segment (ES) register ko 0 par set kiya.
    mov ss, ax    ; Stack Segment (SS) register ko 0 par set kiya.
    mov sp, 0x7C00 ; Stack Pointer ko 0x7C00 de diya. (Stack upar se niche grow karta hai memory mein, toh ye safe space hai memory conflict nai hoga).
    sti           ; (Set Interrupts): Setup complete. Ab wapas system interrupts enable kar diye.

    mov [BOOT_DRIVE], dl ; BIOS hamesha bootable disk ka drive number 'dl' register mein dedeta hai automatically. Usay hum apne safe variable mein save kar lete hain future uses ke liye.

    mov si, msg_loading  ; msg_loading wali string text ko SI pointer mein daala.
    call print_string    ; print_string function ko bulaake screen par "Loading kernel..." print karvaya.

    call load_kernel     ; Ab disk se Kernel ko padhne (read krne ka) function call karo.

    jmp 0x0000:0x7E00    ; Jaise hi kernel load ho jae memory me, CPU memory address 0x7E00 par far-jump kar jaye jaha kernel present hai aur chalne lage.

; --- DISK SE KERNEL LOAD KARNA ---
load_kernel:
    mov bx, 0x7E00 ; BX register batata hai ki disk ka data load karte time RAM/memory mein kis address(destination) par data paste karna hai (0x7E00 address).

    mov ah, 0x02   ; ye code batata hai BIOS ko ki hame disk 'READ' function call krna hai (int 0x13, ah=02)
    mov al, 4      ; Humein 4 sectors (total 2KB data) kernel read karne hain disk se. (Kyunki shell ka code size thoda bada hoga bas isileh 4).
    mov ch, 0      ; Disk ka Cylinder 0
    mov dh, 0      ; Disk ka Head 0
    mov cl, 2      ; Disk Sector 2 se shurwat karo. (Kyunki Sector 1 toh humara bootloader khud 512 bytes hai, vo already memory me h aur disk space pehli khake betha h).
    mov dl, [BOOT_DRIVE] ; Wahi drive id use karo jaha se bootloader aaya tha.

    int 0x13       ; BIOS ka storage system interrupt bhej kar real hardware read shuru karo.
    jc disk_error  ; ('Jump if Carry'). Agar disk read time error aayi ho toh Carry flag on ho jata h tab sidha Disk_Error p feko.
    ret            ; Agar successfully padha, toh wapas return jao (jisne ye function start kra tha vha wapas).

disk_error:
    mov si, msg_error
    call print_string
    jmp $          ; Infinite loop. '$' ka matlab hai "Mera khud ka address". CPU yahin ghoomta aapas me loop krta rahega. Screen hang hojyegi.

; --- STRING PRINT FUNCTION ---
print_string:
    pusha          ; PUSHA: Saare general CPU registers ke values memory ke andar (stack mein) bacha/save kar lo ki kisi operation me overwrite na hojayein.
.loop:
    lodsb          ; Memory mein DS:SI ke paas jo character data hai, us ek byte ko AL me copy karo aur SI counter loop check k lye automatically ek letter aage badhaiye.
    test al, al    ; Check karo ki character 0 (null-terminator matlab string end) toh nahi hai?
    jz .done       ; Agar 0 hai toh khatam (.done par jump).
    mov ah, 0x0E   ; BIOS ka Teletype (screen me typing aana) wala signal/function chuno.
    int 0x10       ; BIOS interrupt bhejo hardware screen me char likhne p.
    jmp .loop      ; Loop back to next word.
.done:
    popa           ; Saare pichle general registers ka wo hi bachae hue data stack se wapas vaise ka vaise le aaiye CPU pe restore kar lo jaisa print karne ke pehle tha.
    ret

; --- VARIABES AND MESSAGES ---
BOOT_DRIVE db 0
msg_loading db "Loading kernel...", 0x0D, 0x0A, 0  ; \r\n jaisa kaam: 0x0D(Carriage Return idhar aao), 0x0A(Nayi line / Line Feed) Enter hit karne pe aana. Aakhri "0" ka mrthlb text yaha khatam . Null terminater.
msg_error db "Disk read error!", 0x0D, 0x0A, 0

; --- MAGIC BOOT SECTOR SIGNATURE ---
times 510-($-$$) db 0 ; BIOS rule number 1: Bootable block fixed 512 byte ka hona chhaiye, no kam no zyada. 'times' loop function hai compile k tym, ye 510th byte tak baaki us bache blank khokle space mein automatically '0' bhar deta (padding).
dw 0xAA55             ; Boot sector block ke aakhri 2 byte reserved (magic value signature byte) hote hain '0xAA55'. Ise dekhte hi BIOS confirm maan leta hai "AHA, yahi original start-up Disk hai".
```

---

## 3. Kernel (`kernel.asm`) Line-by-Line

Bootloader apna hard work finish krke jump command marke pointer idhar de dta hai aur free ho jata h humesha k liye memory me so jata h.

```nasm
[org 0x7E00]      ; NASM ko samjhao ki bhai Kernel ab physical memory mein 0x7E00 se baitha hai. Varaiable aur memory usi flow list ke offsets me count hongye.
[bits 16]         ; Hum abhi bhi 16-bit basic mode mein hain.

start:
    mov si, msg_welcome  ; Welcome message display marwaya.
    call print_string    

shell_loop:            ; Ye infinite shell loop banaya hai jo Cmd / Terminal interface ki tarah output -> Input manghe -> Result -> repeat karta rhe gha.
    mov si, prompt       ; Prompt string (Jaise '> ' wala design) print ho jayega interface p.
    call print_string    

    call read_input      ; User jb tk keybaord se input/type pura na kre process intezzar karta rukka rahega yaha pe ander jake function ke flow se. 
    call process_command ; Jo string Input buffer mei full store hogya 'enter' mrte he, ab program function read krega user ne kya command bola, konsi spellng likhi us hisab result action dedega .

    jmp shell_loop       ; Sab done hone per wapas loop repeat command likhne ko pucho fresh.

; --- INPUT LENA (KEYBOARD SE) Likhai Padhai ---
read_input:
    mov di, input_buffer ; 'input_buffer' wo reserved variable / memory khali dabba jaha hum record karenge keyboard data . Pointr ko set kraya Destination Index(DI) register me..
    mov cx, 0            ; Chars kitne user type kiya counter usay CX m track kar rhen '0' .
.loop:
    mov ah, 0x00    ; Bios function code: keyboard ka signal uthao read user stroke awaitingly
    int 0x16        ; CPU wait till 1 button key click happens . The pressed keys char comes right out via the register 'AL'.

    cmp al, 0x0D    ; CPU se compare kara - User ne kya 'Enter/Return' button toh nahi dabadiya keybaord p ? 
    je .done        ; HAAN toh '.done' line section p Jump Equal(JE) ka rule laghao kykki text enter khatam .

    cmp al, 0x08    ; Agar dabaaya button 'Backspace' hua?
    je .backspace   ; Toh bhai '.backspace' ka operation block start crow.

    cmp cx, 63      ; Limit control: "Maine reserve hi bas 64 bytes memory text buffer limit li thy " Kya CX length > 63 ho gye ? (64th byte string close 0 terminator ka hoga fixed isi liye)
    jge .loop       ; Agar greater / equal hui limit toh faltu mein store mt karwa baaki badhka ke aage ka dbaana type ignore karlo bina loop todo.

    ; Jab normal A-Z key type huyy...
    stosb           ; DI address (jahan buffer memory box bne hue store karna start k liye wait kar a tha) pe 'AL' yani letter save kro aur pointer+ DI register automatically update forward  (khiske) next ek byte jagah mein ghus jayen ga!
    inc cx          ; character count length 1 upar hui  (increment).
    mov ah, 0x0E    ; user ka press gya hua letter screen ke uper display paint kardo taaki typing thek se user ko nazar me aae . Type writer method h
    int 0x10        
    jmp .loop       ; waaps se dusra word input await ..

; .. BACKSPACE HANDLER JADOO ..
.backspace:
    cmp cx, 0       ; User itna crazy to nai ki line me abhi ekdm blank kuch ni he fir v delete maare ja a ra ? check ki length kya 0 se start h? 
    je .loop        ; bhai bakwaas entry delete ko ignor kro loop start m jump mro dubara user ke nayi chz likhne ko .

    dec di          ; DI Pointer ko waps text buffer array ki memory box me -1 minus aage se piche kro position (jaha old character betha hua tha vo position ko aagey wala data overe-write ho).  
    dec cx          ; character Count lenth bi -1 decrement down krlo element khatam.
    
    ; Ab Terminal Display Screen p Purane pichle Likhi huyi Text screen ko mitanye kasie ? (Kyunki display buffer v ek system h ) -- Jugad hai => 
    mov ah, 0x0E
    mov al, 0x08    ; Cursor point ek space peeche krlo left shift.
    int 0x10
    mov al, ' '     ; Khali  Dikhne wala "Space" Blank Text Pring karao purane word uper , to piche wo mit gya / dikhai nai dhangh gayb black screen hogya h ab.
    int 0x10
    mov al, 0x08    ; Ab waps Cursor point piche lo, qki space bharne se vo ek bar aa gya toh pichle sthan me waps sahi krdo space pe... Ready ! 
    int 0x10
    jmp .loop       ; Go ..

.done:
    mov al, 0
    stosb           ; Strings rules array data  "hamesah Zero p close ho". isliye text lenth khatm hue waha '0' write krdo destination Buffer index m ki yaha word khtm.
    
    mov si, newline
    call print_string ; "Enter" maarne ka screen action pura , agle display newline de dhakk lo 
    ret

; --- COMMAND (Text Buffer) ko Match/Process karna ---
process_command:
    cmp byte [input_buffer], 0  ; Dekho ki user ne empty buffer submit kiya kya bin type kiey bas direct enter mardiya ho ?
    je .done                    ; Agar haan bhaago done m bina kuch print kre

    ; command "help" verify match
    mov si, input_buffer ; Text buffer location jo data tha wo string ki source SI index bna ! 
    mov di, cmd_help     ; cmd_help jaha memory code text tha fixed (Destination Index)..
    call strcmp          ; Function bulao checking function line by line jo match krta 
    jc .do_help          ; (jc = Jump if Carry Flag On). strcmp mei mene sikhaya tha agar match equal rha dono toh status me CPU 'Carry flag' check turn on dedeta. Ussey trigger match pe '.do_help' side chli  line jump branch chlegi ab. 

    mov si, input_buffer
    mov di, cmd_clear
    call strcmp
    jc .do_clear

    mov si, input_buffer
    mov di, cmd_about
    call strcmp
    jc .do_about

    ;  Prefix Comparison , "echo " keyword wali setting prefix matching .. 
    mov si, input_buffer
    mov di, cmd_echo_prefix
    call strncmp         ; String Prefix matched Function checking call
    jc .do_echo

    ; Agar command kisi me flag jump na kraya matlab error match unknwn input , kisi m na fas rha.. Fail .
    mov si, msg_unknown  ; "Unknown Command: " vala rrror display Text laao pehla 
    call print_string
    mov si, input_buffer ; buffer text ka glti waala chhap do display
    call print_string
    mov si, newline      
    call print_string
    jmp .done           ; Bahar

.do_help:
    mov si, msg_help
    call print_string
    jmp .done

.do_clear:
    call clear_screen
    jmp .done

.do_about:
    mov si, msg_about
    call print_string
    jmp .done

.do_echo:
    mov si, input_buffer + 5  ; "echo " ki length 5 byte space hoti hai usko skip+ krwa di direct message memory pointer p point kra start , bacha hua aage ka sab word waisa ka waisa read hoke chhap jyga as  Text Parameter !
    call print_string
    mov si, newline
    call print_string
    jmp .done

.done:
    ret

; ------ String Comparison (Compare karna / Match Test functions) ---------
; -- Function `strcmp`: Pura compare karo dono parameter SI / DI ek dm same equal hain ! . 
strcmp:
    pusha
.loop:
    mov al, [si]   ; Pehladta byte ka AL me liya string 1 
    mov bl, [di]   ; strig 2 byte BL me
    cmp al, bl     ; match the both values 
    jne .not_equal ; barabar ni h toh sidha bahar fenko ".not_equal " (Jump if not equal)
    cmp al, 0      ; Dono ko end Null terminitor milgya  ?
    je .equal      ; match successful rhaa
    inc si         ; dono current memrory byte pointer ko aage badaao
    inc di
    jmp .loop
.not_equal:
    popa
    clc ; (Clear Carry Flag) (Mtb CPU ne clear bata diya Not Equal/Match Fail signal 0 di a  ).
    ret
.equal:
    popa
    stc ; (Set Carry C-Flag) CPU 1 bit Status Set. Match TRUE hai ! Passed ..
    ret

; -- Function `strncmp`: prefix compare. Piche k baaki shabd text parameter ko ignore maaro aur bas prefix jaha the wahi '0' text khtm test tak shuruh ki gye chiz ke format length limit point check kro ! 
strncmp:
    pusha
.loop:
    mov bl, [di]   
    cmp bl, 0      ; Kya prefiix jo string match di ("echo ") vo uske hi khtm null terminator zero length tak pe pahuche bas?
    je .equal      ; Matlab  prefix successful shurvti point pe  Passed match. Baki user gya tel laghane hum pas krdnege. 
    mov al, [si]   
    cmp al, bl
    jne .not_equal
    inc si
    inc di
    jmp .loop
.not_equal:
    popa
    clc          
    ret
.equal:
    popa
    stc           
    ret

; -- Clear Screen !!
clear_screen:
    pusha
    mov ah, 0x00   ; Display Video Mode change / apply  refresh karne wala Hardware option
    mov al, 0x03   ; Mode id (80x25 characters - Real BIOS colored vga text mode ). Ye set hote hi automatically screen pura saaf / refresh kar deta hai !!
    int 0x10       ; BIOS interup dispalay active mar do !
    popa
    ret

; --------------------------------------
; Data memory Variable Store , String messages..
; --------------------------------------
msg_welcome db "Kernel loaded successfully!", 0x0D, 0x0A, "Type 'help' for commands.", 0x0D, 0x0A, 0
prompt db "> ", 0
; ... [aur baaki messages normal string list hain]

; Keyboard Text memory uninitizlied raw memory dabba  
input_buffer times 64 db 0   ;  64 zero (null) byte block ki blank string khokhla empty store banna diya memory ko .. 
```

---

## 4. Build Script kaise Run karta hai sab kchh?

Yeh `build.sh` script basically poore raw-code ko build krke machine binary me bundle karta hai:

```bash
#!/bin/bash
set -e

# Ye 'nasm' compiler hamare likhe hue assembly '.asm' me files ko original hardware Machine level '.bin' format (Binary 0-1) me bundle transalate kregha. (File generate hotii binary mei bin). !
nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

# 'dd' tool -  Ye Linux/Mac pe data disk byte level block copy-paste utility h...
# /dev/zero ka matlb hamesha infinite count space bytes wale zeors(0) dega waha file read karne waala special virtual node pointer source h... !!
# idhr 1.44 MB standard size "floppy disk image" create karta h  empty (1024 Bytes ka  1 block esi 1440 count kardo total bytes ki format ek black "os.img" create file ban jaye blank).
dd if=/dev/zero of=os.img bs=1024 count=1440 2>/dev/null

# Pehle dd se - Boot image 'boot.bin' (size: 512b) ko is "os.img" block ke ekdam 1st disk 'sector 1st' m copy chhipka deto ho, conv=notrunc - islyie baaki file corrupt/delete cut nahi hota purana !
dd if=boot.bin of=os.img conv=notrunc 2>/dev/null

# Kernel code ab kitna bi mota bada space size le !!  isley next function se kernel block disk ke seedha 'Sector 2' or upar position se aaram se baithke store hojat ahi. ('seek=1' yani - copy k time ek sector -512 space  kudwa de/skip kara do direct 2nd sector location write paste pointer)
dd if=kernel.bin of=os.img seek=1 conv=notrunc 2>/dev/null

# Virtual Macahine "qemu" aapki OS iso raw file start boot test kardyge full PC Simulator window ki tarhaaa!!! 🎉 
```

Doston, is README section ko dhyan se follow karne ke baad, mujhe poori ummeed hai ki operating system load kaise hota, BIOS memory blocks, interrupt handlers kaise BIOS interface ke sath hardware functions call operate krwata h sab basics concepts aapko crystal clear hinglish aur easy way logic par poora samajh aa gaya hoga!
