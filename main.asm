org 0
;rom_size_multiple_of equ 4096
rom_size_multiple_of equ 512
bits 16
    ; PCI Expansion Rom Header
    ; ------------------------
    db 0x55, 0xAA ; signature
    db rom_size/512; initialization size in 512 byte blocks
entry_point: jmp start
    times 21 - ($ - entry_point) db 0
    dw pci_data_structure 

    ; PCI Data Structure
    ; ------------------
pci_data_structure:
    db 'P', 'C', 'I', 'R'
    dw PCI_VENDOR_ID
    dw PCI_DEVICE_ID
    dw 0 ; reserved
    dw pci_data_structure_end - pci_data_structure
    db 0 ; revision
    db 0x02, 0x00, 0x00 ; class code: ethernet
    dw rom_size/512
    dw 0 ; revision level of code / data
    db 0 ; code type => Intel x86 PC-AT compatible
    db (1<<7) ; this is the last image
    dw 0 ; reserved
pci_data_structure_end:


start:
    push CS
    pop DS

    ; Detect POST memory manager
    ; --------------------------

    mov AX, 0xE000
    mov ES, AX
pmm_detection_loop:
    mov EBX, [ES:0]
    cmp EBX, 0x4d4d5024
    jz pmm_detected
    inc AX
    mov ES, AX
    jnz pmm_detection_loop

    mov AX, err_no_pmm
    call puts
    call pause
    retf

pmm_detected:

    ; calculate checksum
    mov BX, 0 ; offset
    mov CL, 0 ; checksum comes here
    mov AL, [ES:05h] ; length

pmm_sum:
    add CL, [ES:BX]
    inc BL
    cmp BL, AL
    jl pmm_sum

    cmp CL, 0
    jz pmm_sum_success

    mov AX, err_pmm_chksum
    call puts
    call pause
    retf

pmm_sum_success:

    ; save entry point - our PMM interfe far function pointer
    mov AX, [ES:07h]    
    mov [pmm_entry_point], AX
    mov AX, [ES:07h+2]    
    mov [pmm_entry_point+2], AX

    mov AX, 0
    mov ES, AX ; now we can use ES for 32 bit physical adressing

    ; Allocate memory
    ; ---------------
    mov EAX, 1024/16
    call pmm_alloc_paragraphs
    mov [cmd_list], EAX

    mov EAX, 256/16
    call pmm_alloc_paragraphs
    mov [cmd_table], EAX

    mov EAX, 4096/16
    call pmm_alloc_paragraphs
    mov [fis_recv], EAX

    mov EAX, 512/16
    call pmm_alloc_paragraphs
    mov [ahci_data_buf], EAX
    
%include "abar.asm"

    mov AX, hello_msg
    call puts

%include "ahci.asm"

    ; End of program
    ; --------------
    mov AX, end_msg
    call puts
    retf
    mov AX, [needs_reboot]
    cmp AX, 0
    jz no_reboot 
    mov AX, end_msg_rb
    call puts
    call pause

    ; Reboot
    ; ------

    jmp 0xFFFF:0x0000

;    cli
;reboot_loop:
;    in AL, 0x64
;    test AL, (1<<0)
;    jz no_read_io
;    mov AL, 0x60
;no_read_io:
;    in AL, 0x64
;    test AL, (1<<1)
;    jnz reboot_loop
;    
;    mov AL, 0xFE
;    out 0x64, AL
;halt:
;    hlt
;    jmp halt
;    
;void reboot()
;{
;    uint8_t temp;
; 
;    asm volatile ("cli"); /* disable all interrupts */
; 
;    /* Clear all keyboard buffers (output and command buffers) */
;    do
;    {
;        temp = inb(KBRD_INTRFC); /* empty user data */
;        if (check_flag(temp, KBRD_BIT_KDATA) != 0)
;            inb(KBRD_IO); /* empty keyboard data */
;    } while (check_flag(temp, KBRD_BIT_UDATA) != 0);
; 
;    outb(KBRD_INTRFC, KBRD_RESET); /* pulse CPU reset line */
;    loop:
;    asm volatile ("hlt"); /* if that didn't work, halt the CPU */
;    goto loop; /* But if a non maskable interrupt is received, halt again */
;}



no_reboot:
    call pause
    retf


pmm_alloc_paragraphs:
    push word 0b111 ; Flags: Aligned, conventional or extended
    push dword 0xFFFFFFFF ; anonymous allocation

    push EAX; size in paragraphs
    push 0x0000 ; function: allocate
    call far [pmm_entry_point]
    add sp, 12 ; clean up after C style function call
    
    xchg DX, AX
    shl EAX, 16
    mov AX, DX
    cmp EAX, 0
    je pmm_alloc_fail
    ret

pmm_alloc_fail:
    mov AX, err_pmm_alloc
    call puts
    call nl
    jmp $ ; we cant retf here, since we would need a stack frame for that.


memclear: ; set AX bytes starting at ES:ECX to 0x00
    push AX
    push ECX
    
memclear_loop:
    mov [ES:ECX], byte 0
    inc ECX
    dec AX
    jnz memclear_loop

    pop ECX
    pop AX
    ret

%include "io.asm"
    
    ; Strings
hello_msg db `ahci_sbe v. 0.2\n\0`
end_msg db `==== END ====\n\0`
end_msg_rb db `Will reboot now!\n\0`
pause_msg db `Press any key to continue...\n\0`

err_no_pci db `PCI not present\n\0`
err_no_ahci db `AHCI not present\n\0`
err_abar db `Failed to read ABAR\n\0`
err_no_pmm db `PMM not present\n\0`
err_pmm_alloc db `PMM alloc failed\n\0`
err_pmm_chksum db `PMM checksum mismatch\n\0`

abar dd 0x00000000 ; save ABAR here
pmm_entry_point dw 0x0000, 0x0000 ; save PMM entry point here
needs_reboot db 0 ; set to 1 if we need reboot


    db 0 ; reserve at least one byte for checksum
rom_end equ $-$$
rom_size equ (((rom_end-1)/rom_size_multiple_of)+1)*rom_size_multiple_of
    times rom_size - rom_end db 0 ; padding
