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

    mov AX, [ES:07h]    
    call putword
    call nl
    mov [pmm_entry_point], AX
    mov AX, [ES:07h+2]    
    call putword
    call nl
    mov [pmm_entry_point+2], AX


    call far [pmm_entry_point]

    call pause
    

    ; Find AHCI controller via BIOS
    ; -----------------------------

    ; Step 1: Does the BIOS support PCI?

    mov AX, 0b101h
    int 1ah
    ;cmp DX, 4350h ; "CP" from "PCI"
    cmp EDX, 20494350h ; " ICP"?!?
    jz pci_present

    mov AX, err_no_pci
    call puts
    call pause
    retf

pci_present:

    ; Step 2: Find the AHCI/SATA controller (class id 01h, subclass id 06h, prog-if 01h)

    mov AX, 0b103h ; find pci class code
    mov ECX, 010601h
    mov SI, 0 ; find only first device. must be repeated with SI=1,2... to support multiple ahcis
    int 1ah
    jnc ahci_present

    mov AX, err_no_ahci
    call puts
    call pause
    retf

ahci_present:

    ; BL/HL is now bus number, device/function number
    ; now we need the HBA (host bus adapter), referenced by ABAR (AHCI Base Memory Register), which is BAR[5]=PCI header offset 24h.
    ; we get that from the bios, by which BL/BH is already set accordingly
    mov AX, 0b10ah ; read configuration dword
    mov DI, 24h
    int 1ah
    jnc abar_success

    mov AX, err_abar
    call puts
    call pause
    retf

abar_success:

    mov [abar], ECX
    


    mov AX, hello_msg
    call puts

    mov EAX, [abar]
    call putdword
    call nl

    ;call pause
    ;jmp start
echo:
    call getc
    call putc
    jmp echo


    retf





%include "io.asm"
    
    ; Strings
hello_msg db `ahci_sbe v. 0.2\n\0`
pause_msg db `Press any key to continue...\n\0`

err_no_pci db `PCI not present\n\0`
err_no_ahci db `AHCI not present\n\0`
err_abar db `Failed to read ABAR\n\0`
err_no_pmm db `PMM not present\n\0`
err_pmm_chksum db `PMM checksum mismatch\n\0`

abar dd 0x00000000 ; save ABAR here
pmm_entry_point dw 0x0000, 0x0000 ; save PMM entry point here


    db 0 ; reserve at least one byte for checksum
rom_end equ $-$$
rom_size equ (((rom_end-1)/rom_size_multiple_of)+1)*rom_size_multiple_of
    times rom_size - rom_end db 0 ; padding
