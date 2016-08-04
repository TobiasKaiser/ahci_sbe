; main.asm -- ahci_sbe main file generating PCI option ROM header structures, 
; performing basic initialization, %includes all other asm source files
; Copyright (C) 2014, 2016 Tobias Kaiser <mail@tb-kaiser.de>


org 0
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
    mov [sp_orig], SP
    call cls

    call pmm_detect_and_alloc

loop_over_multiple_ahci_controllers:
    mov AX, [cur_ahci_index]
    call find_ahci

    cmp AX, 0
    jnz loop_over_multiple_ahci_controllers_end

    call ahci_main

    mov AX, [cur_ahci_index]
    inc AX
    mov [cur_ahci_index], AX

    jmp loop_over_multiple_ahci_controllers
loop_over_multiple_ahci_controllers_end:


    mov AL, [needs_reboot]
    cmp AL, 0
    jz no_reboot 
    call clear_last_password
    call cls_blank
    jmp 0xFFFF:0x0000 ; <-- reboot (so many possibilities)

fatal_error:
    push AX
    mov AX, fatal_error_msg
    call puts
    pop AX
    call puts
    call pause

    mov SP, [sp_orig]
no_reboot:
    call clear_last_password
    call cls_blank
    retf ; <-- continue boot

    ; ----

%include "pmm.asm"
%include "ahci.asm"
%include "io.asm"
    
    ; memclear function
    ; -----------------
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

    ; Strings
    ; -------

version_str db `ahci_sbe v. 0.9\0`
fatal_error_msg db `Fatal error: \0`
pause_msg db `Press any key to continue...\n\0`
pw_dialog_msg db `Enter password to unlock device:\0`
pw_dialog_prompt db `Password: \0`
pw_dialog_usage_msg db `ENTER=Unlock  Shift+ENTER=Unlock multiple  ESC=Skip\0`
wrong_password_msg db `Wrong password. Press return to try again.\0`

    ; Error messages
    ; --------------

err_no_pci db `PCI not present\n\0`
err_no_ahci db `AHCI not present\n\0`
err_abar db `Failed to read ABAR\n\0`
err_no_pmm db `PMM not present\n\0`
err_pmm_alloc db `PMM alloc failed\n\0`
err_pmm_chksum db `PMM checksum mismatch\n\0`

    ; Global Variables
    ; ----------------

abar dd 0x00000000 ; save ABAR here
sp_orig dw 0x0000 ; original stack pointer for returning in case of an error
pmm_entry_point dw 0x0000, 0x0000 ; save PMM entry point here
needs_reboot db 0 ; set to 1 if we need reboot
cur_style db 0x07 ; grey on black = default
cur_ahci_index dw 0x0000 ; start with achi controll #0, then try #1, ...
unlock_multiple db 0x00 ; 0=unlock single, else=unlock multiple
last_password_length dd 0x00000000
last_password dd 0, 0, 0, 0, 0, 0, 0, 0

horiz_line_left db 0
horiz_line_middle db 0
horiz_line_right db 0


    ; ROM padding, checksum needs to be added separately
    ; --------------------------------------------------

    db 0 ; reserve at least one byte for checksum
rom_end equ $-$$
rom_size equ (((rom_end-1)/rom_size_multiple_of)+1)*rom_size_multiple_of
    times rom_size - rom_end db 0 ; padding
