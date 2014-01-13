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
    mov EAX, 0xABCD
    call putword 

;while:
;    mov AH, 0
;    int 0x16 
;    call putc
;    jmp while


    jmp $


%include "io.asm"

    db 0 ; reserve at least one byte for checksum
rom_end equ $-$$
rom_size equ (((rom_end-1)/rom_size_multiple_of)+1)*rom_size_multiple_of
    times rom_size - rom_end db 0 ; padding
