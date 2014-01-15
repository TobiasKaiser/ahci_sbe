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
