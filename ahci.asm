%include "ahci_defs.asm"

    mov AX, msg_ahci_check_now
    call puts
    call pause



    ; Step 1: check AHCI
    ; ------------------

    mov EBX, [abar]
    mov EAX, EBX
    call putdword


    mov EAX, [ES:EBX+HBA.cap]
    test EAX, (1<<30) ; SNCQ = supports native command queuing?
    jnz sncq_passed

    mov AX, err_ahci_sncq
    call puts
    jmp $

sncq_passed:



    ; AHCI: test every port loop
    ; --------------------------
    mov CL, 0 ; port number
ahci_port_loop:

    mov EAX, 1
    shl EAX, CL

    test EAX, [ES:EBX+HBA.pi]
    jz ahci_end_port ; port not implemented

    mov AX, msg_port 
    call puts
    mov AL, CL
    call putbyte

    
    push CX
    push EBX
    mov EAX, 0
    mov AL, CL
    shl AX, 7 ; *128 => port offset
    add AX, HBA.ports
    add EBX, EAX
    call check_port

    pop EBX
    pop CX
    

ahci_end_port:
    call nl
    call pause
    inc CL
    cmp CL, 32
    jl ahci_port_loop


    jmp skip_data

check_port:
    mov EAX, EBX
    call putdword
    
    mov EAX, [ES:EBX+HBA_PORT.ssts]
    and EAX, 0xF
    cmp EAX, 3
    je check_port_det_ok

    mov AX, msg_no_device_attached
    call puts
    ret
check_port_det_ok:

    mov EAX, [ES:EBX+HBA_PORT.sig]
    cmp EAX, 0x101
    je check_port_sig_ok 

    mov AX, msg_no_ata_device
    call puts
    ret
check_port_sig_ok:

    ret


cmd_list: dd 0x00000000 ; 32 bytes, 1K aligned
cmd_table: dd 0x00000000 ; 128 + 16 byte PRDT => 256 byte alloc, 128 byte aligned
fis_recv: dd 0x00000000 ; 256 bytes, 256 byte aligned
result_buf: dd 0x00000000 ; 512 bytes, 2 byte aligned
; allocated in main.asm

msg_port db `AHCI Port \0`
msg_ahci_check_now db `Will start AHCI check now.\n\0`
err_ahci_sncq db `AHCI: SNCQ not set.\n\0`
msg_no_device_attached db `No device attached\n\0`
msg_no_ata_device db `No ATA device\n\0`

skip_data:
