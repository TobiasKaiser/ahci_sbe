%include "ahci_defs.asm"

    mov AX, msg_ahci_check_now
    call puts
    call pause

    ; Clear fis_recv
    mov ECX, [fis_recv]
    mov AX, 256
    call memclear


    ; Step 1: check AHCI
    ; ------------------

    mov EBX, [abar]
    mov EAX, EBX
    call putdword

    mov EAX, [ES:EBX+HBA.ghc]
    test EAX, (1<<31) ; AE = AHCI enabled
    jnz ae_passed

    ; disable interrupts - probably not necessary
    mov EAX, [ES:EBX+HBA.ghc]
    and EAX, ~(1<<1) ; clear IE flag
    mov [ES:EBX+HBA.ghc], EAX
    

    mov AX, err_ahci_ae
    call puts
    jmp $
ae_passed:

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

    ; Check port function
    ; -------------------

check_port:
    mov EAX, EBX
    call putdword

    ;2. Ensure that PxCMD.ST = ‘0’, PxCMD.CR = ‘0’, PxCMD.FRE = ‘0’, PxCMD.FR = ‘0’
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, (1<<0)|(1<<15)|(1<<14)|(1<<4)
    jz check_port_cmd_ok

    mov AX, err_port_not_idle
    call puts
    ret
check_port_cmd_ok:

    mov [ES:EBX+HBA_PORT.serr], dword 0b00000111111111110000111100000011 ; reset all implemented interrupt bits
    
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


    ; Link command list (consists of one command header) to port

    mov [ES:EBX+HBA_PORT.clbu], dword 0 
    mov EAX, [cmd_list]
    mov [ES:EBX+HBA_PORT.clb], EAX
    mov EAX, [fis_recv]
    mov [ES:EBX+HBA_PORT.fb], EAX
    

    ; Start port
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    or EAX, (1<<4) ; set FRE = FIS receive enable
    mov [ES:EBX+HBA_PORT.cmd], EAX

wait_fr:
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    test EAX, (1<<14) ; wait for FR = FIS receiver running
    jz wait_fr

    mov EAX, [ES:EBX+HBA_PORT.cmd]
    or EAX, (1<<0) ; set ST = Start
    mov [ES:EBX+HBA_PORT.cmd], EAX

    call identify

    ; Stop port
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, ~(1<<0) ; clear ST = Start
    mov [ES:EBX+HBA_PORT.cmd], EAX

    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, ~(1<<4) ; clear FRE = FIS receive enable
    mov [ES:EBX+HBA_PORT.cmd], EAX

    ; Unlink our structures
    mov [ES:EBX+HBA_PORT.clb], dword 0
    mov [ES:EBX+HBA_PORT.fb], dword 0
    ret

    ; Issue ATA IDENTIFY
    ; ------------------
identify:
    ; Clear command list
    mov ECX, [cmd_list]
    mov AX, 32
    call memclear
    
    ; Clear result buffer
    mov ECX, [result_buf]
    mov AX, 512
    call memclear

    ; Clear command tablo
    mov ECX, [cmd_table]
    mov AX, 256
    call memclear

    mov ECX, [cmd_list]
    mov [ES:ECX+HBA_CMD_HEADER.flags], word 0|5 ; w=0, cfl=20/4
    mov [ES:ECX+HBA_CMD_HEADER.prdtl], word 1

    mov EAX, [cmd_table]
    mov [ES:ECX+HBA_CMD_HEADER.ctba], EAX

    mov ECX, [cmd_table]
    ;mov [ES:ECX+0], byte 0x27 ; fis->fis_type = FIS_TYPE_REG_H2D
    ;mov [ES:ECX+1], byte (1<<7) ; fis->c = 1
    ;mov [ES:ECX+2], byte 0xEC ; fis->command = ATA_CMD_IDENTIFY; 
    ; fis->device = 0
    mov [ES:ECX], dword 0x00ECF027

    add ECX, 128 ; goto first prdt entry
    mov EAX, [result_buf]
    mov [ES:ECX], EAX ; address
    mov [ES:ECX+12], dword 512-1 ; count ?!?

    mov AX, msg_issuing
    call puts
    call pause

    ;mov DX, 256
    ;mov ECX, [cmd_table]
    ;call hexdump 

    ; Set CI bit 0
    mov [ES:EBX+HBA_PORT.ci], dword 1
    
wait_ci:
    mov EAX, [ES:EBX+HBA_PORT.ci]
    test EAX, 1
    jnz wait_ci
    call pause

    ; Output IDENTIFY result
    mov DX, 512
    mov ECX, [result_buf]
    call hexdump 

    add ECX, 27*2 ; model number offset
    mov DX, 20 ; 20 words = 40 ascii chars
    call fill_identify_strbuf

    mov AX, identify_strbuf
    call puts


    ret


fill_identify_strbuf:
    push EBX
    mov BX, identify_strbuf 
fill_identify_strbuf_loop:
    mov AX, [ES:ECX]
    xchg AL, AH
    mov [BX], AX
    inc BX
    inc BX
    inc ECX
    inc ECX
    dec DX
    jnz fill_identify_strbuf_loop

    pop EBX
    ret

hexdump:
    push AX
    push ECX
    push DX
hexdump_loop:
    mov AL, [ES:ECX]
    call putbyte
    inc ECX
    dec DX
    jnz hexdump_loop
    pop DX
    pop ECX
    pop AX
    ret


cmd_list: dd 0x00000000 ; 32 bytes, 1K aligned
cmd_table: dd 0x00000000 ; 128 + 16 byte PRDT => 256 byte alloc, 128 byte aligned
fis_recv: dd 0x00000000 ; 256 bytes, 256 byte aligned --> wir nehmen lieber mal 4K, keine ahnung
result_buf: dd 0x00000000 ; 512 bytes, 2 byte aligned
identify_strbuf: times 40+1 db 0x00 ; null terminated string
; allocated in main.asm

msg_port db `AHCI Port \0`
msg_issuing db `Issuing...\n\0`
msg_ahci_check_now db `Will start AHCI check now.\n\0`
err_port_not_idle db `Port not idle.\n\0`
err_ahci_sncq db `AHCI: SNCQ not set.\n\0`
err_ahci_ae db `AHCI: GHC.AE not set.\n\0`
msg_no_device_attached db `No device attached\n\0`
msg_no_ata_device db `No ATA device\n\0`

skip_data:
