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
    call nl

    
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
    

    call pause
ahci_end_port:
    inc CL
    cmp CL, 32
    jl ahci_port_loop


    jmp skip_data

    ; Check port function
    ; -------------------

check_port:
    
    ; Is a device attached and PHY ready?
    mov EAX, [ES:EBX+HBA_PORT.ssts]
    and EAX, 0xF
    cmp EAX, 3
    je check_port_det_ok

    mov AX, msg_no_device_attached
    call puts
    ret
check_port_det_ok:

    ; Is it an ATA device?
    mov EAX, [ES:EBX+HBA_PORT.sig]
    cmp EAX, 0x101
    je check_port_sig_ok 

    mov AX, msg_no_ata_device
    call puts
    ret
check_port_sig_ok:

    ;2. Ensure that PxCMD.ST = ‘0’, PxCMD.CR = ‘0’, PxCMD.FRE = ‘0’, PxCMD.FR = ‘0’
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, (1<<0)|(1<<15)|(1<<14)|(1<<4)
    jz check_port_cmd_ok

    mov AX, err_port_not_idle
    call puts
    ret
check_port_cmd_ok:

    ; Reset all implemented interrupt bits
    mov [ES:EBX+HBA_PORT.serr], dword 0b00000111111111110000111100000011 

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
    call identify_info
    call identify
    call identify_info
    call is_locked
    cmp AX, 0
    jz not_locked
    call unlock
not_locked:



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
    call clearall

    mov ECX, [cmd_list]
    mov [ES:ECX+HBA_CMD_HEADER.flags], word 0|5 ; w=0, cfl=20/4
    mov [ES:ECX+HBA_CMD_HEADER.prdtl], word 1

    mov EAX, [cmd_table]
    mov [ES:ECX+HBA_CMD_HEADER.ctba], EAX

    mov ECX, [cmd_table]
    ; fis type = RegH2D => 0x27; c = 1 => 0xF0; command = IDENTIFY => 0xEC
    mov [ES:ECX], dword 0x00ECF027

    add ECX, 128 ; goto first prdt entry
    mov EAX, [ahci_data_buf]
    mov [ES:ECX], EAX ; address
    mov [ES:ECX+12], dword 512-1 ; count ?!?

    call issue_command
    ret

identify_info:
    mov ECX, [ahci_data_buf]
    add ECX, 27*2 ; model number offset
    mov DX, 20 ; 20 words = 40 ascii chars
    call fill_identify_strbuf
    mov AX, identify_strbuf
    call puts
    call nl


    mov ECX, [ahci_data_buf]
    mov AX, [ES:ECX+82*2]
    and AX, (1<<1)
    jnz security_supported ; Bit "Security mode feature set supported?". Maybe "Security mode feature set enabled" is also relevant?
    mov AX, msg_no_security
    call puts
    ret

security_supported:

    ; Debug: print security status
    ; ----------------------------

    mov AX, [ES:ECX+128*2]
    test AX, (1<<4)
    jz skip_count_expired
    push AX
    mov AX, info_count_expired
    call puts
    pop AX
skip_count_expired:
    test AX, (1<<3)
    jz skip_frozen
    push AX
    mov AX, info_frozen
    call puts
    pop AX
skip_frozen:
    test AX, (1<<2)
    jz skip_locked
    push AX
    mov AX, info_locked
    call puts
    pop AX
skip_locked:
    test AX, (1<<1)
    jz skip_enabled
    push AX
    mov AX, info_enabled
    call puts
    pop AX
skip_enabled:
    test AX, (1<<0)
    jz skip_supported
    push AX
    mov AX, info_supported
    call puts
    pop AX
skip_supported:
    ret
    
    ; Should we ask for a password?
    ; -----------------------------
is_locked:
    test AX, (1<<3)|(1<<4)
    jz not_frozen_or_count_expired
    mov AX, 0
    ret
not_frozen_or_count_expired:
    and AX, (1<<0)|(1<<1)|(1<<2)
    cmp AX, (1<<0)|(1<<1)|(1<<2)
    jz supported_enabled_and_locked
    mov AX, 0
    ret
supported_enabled_and_locked:
    mov AX, 1
    ret

    ; We need to issue SECURITY UNLOCK
    ; --------------------------------
unlock:
    call clearall

    mov ECX, [ahci_data_buf]
    
    ; Control word is 0 (already cleared) => only user password support

    ; Copy password
    add ECX, 2 ; password offset
    push EBX
    mov DX, 16 ; # words left to copy
    mov BX, pw_test

copy_password:
    mov AX, [BX]
    ;xchg AL, AH
    mov [ES:ECX], AX

    add ECX, 2
    add BX, 2
    
    dec DX
    jnz copy_password
     
    pop EBX


    mov ECX, [cmd_list]
    mov [ES:ECX+HBA_CMD_HEADER.flags], word (1<<6)|5 ; w=1, cfl=20/4 (RegH2D)
    mov [ES:ECX+HBA_CMD_HEADER.prdtl], word 1

    mov EAX, [cmd_table]
    mov [ES:ECX+HBA_CMD_HEADER.ctba], EAX

    mov ECX, [cmd_table]
    ; fis type = RegH2D => 0x27; c = 1 => 0xF0; command = IDENTIFY => 0xF2
    mov [ES:ECX], dword 0x00F2F027

    add ECX, 128 ; goto first prdt entry
    mov EAX, [ahci_data_buf]
    mov [ES:ECX], EAX ; address
    mov [ES:ECX+12], dword 512-1 ; count ?!?

    mov AX, msg_issuing
    call puts

    mov [ES:EBX+HBA_PORT.is], dword (1<<30) ; reset TFES

    ; Set CI bit 0
    mov [ES:EBX+HBA_PORT.ci], dword 1
    
wait_unlock:
    mov EAX, [ES:EBX+HBA_PORT.is]
    test EAX, (1<<30) ; TFES
    jnz abort

    mov EAX, [ES:EBX+HBA_PORT.ci]
    test EAX, 1
    jnz wait_unlock
    ; command completed

    mov AX, msg_unlock_completed
    call puts 

    mov [needs_reboot], byte 1

    ret
abort:
    mov AX, msg_abort

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

issue_command:
    mov AX, msg_issuing
    call puts
    ; Set CI bit 0
    mov [ES:EBX+HBA_PORT.ci], dword 1
    
wait_ci:
    mov EAX, [ES:EBX+HBA_PORT.ci]
    test EAX, 1
    jnz wait_ci
    ; command completed
    mov AX, msg_complete
    call puts
    ret

clearall:
    ; Clear command list
    mov ECX, [cmd_list]
    mov AX, 32
    call memclear
    
    ; Clear result buffer
    mov ECX, [ahci_data_buf]
    mov AX, 512
    call memclear

    ; Clear command tablo
    mov ECX, [cmd_table]
    mov AX, 256
    call memclear
    ret


cmd_list: dd 0x00000000 ; 32 bytes, 1K aligned
cmd_table: dd 0x00000000 ; 128 + 16 byte PRDT => 256 byte alloc, 128 byte aligned
fis_recv: dd 0x00000000 ; 256 bytes, 256 byte aligned --> wir nehmen lieber mal 4K, keine ahnung
ahci_data_buf: dd 0x00000000 ; 512 bytes, 2 byte aligned
identify_strbuf: times 40+1 db 0x00 ; null terminated string
; allocated in main.asm

msg_port db `AHCI Port \0`
msg_issuing db `Issuing...\0`
msg_complete db `complete!\n\0`
msg_ahci_check_now db `Will start AHCI check now.\n\0`
err_port_not_idle db `Port not idle.\n\0`
err_ahci_sncq db `AHCI: SNCQ not set.\n\0`
err_ahci_ae db `AHCI: GHC.AE not set.\n\0`
msg_no_device_attached db `No device attached\n\0`
msg_no_ata_device db `No ATA device\n\0`
msg_no_security db `Security mode feature set not supported\n\0`
msg_unlock_completed db `UNLOCK completed\n\0`
msg_abort db `aborted!\n\0`

pw_test: times 32 db 0 ; we can do this direct => test!

info_count_expired db `count expired \0`
info_frozen db `frozen \0`
info_locked db `locked \0`
info_enabled db `enabled \0`
info_supported db `supported \0`

skip_data:
