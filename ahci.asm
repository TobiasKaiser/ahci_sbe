%include "ahci_defs.asm"

    ; Clear fis_recv
    mov ECX, [fis_recv]
    mov AX, 256
    call memclear


    ; Step 1: check AHCI
    ; ------------------

    mov EBX, [abar] ; EBX will be reserved for abar a while

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

    ;mov AX, msg_port 
    ;call puts
    ;mov AL, CL
    ;call putbyte
    ;call nl

    
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

    ;mov AX, msg_no_device_attached
    ;call puts
    ret
check_port_det_ok:

    ; Is it an ATA device?
    mov EAX, [ES:EBX+HBA_PORT.sig]
    cmp EAX, 0x101
    je check_port_sig_ok 

    ;mov AX, msg_no_ata_device
    ;call puts
    ret
check_port_sig_ok:

    ;2. Ensure that PxCMD.ST = ‘0’, PxCMD.CR = ‘0’, PxCMD.FRE = ‘0’, PxCMD.FR = ‘0’
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, (1<<0)|(1<<15)|(1<<14)|(1<<4)
    jz check_port_cmd_ok

    mov AX, err_port_not_idle
    call puts
    call pause
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
    call is_locked
    cmp AX, 0
    jz not_locked

unlock_loop:

    call unlock
    cmp AX, 0
    jz unlock_done

    call wrong_password_error_box
    call cls

    jmp unlock_loop

    
not_locked:

unlock_done:


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
    
    ; put hdd name in identify_strbuf
    mov ECX, [ahci_data_buf]
    add ECX, 27*2 ; model number offset
    mov DX, 20 ; 20 words = 40 ascii chars
    call fill_identify_strbuf

    ret


    ; Should we ask for a password?
    ; -----------------------------
is_locked:
    mov ECX, [ahci_data_buf]
    mov AX, [ES:ECX+128*2] ; Security word from IDENTIFY
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

    call pw_dialog
    call cls
    
    ; Control word is 0 (already cleared) => only user password support


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

    call clearall ; clears password in memory

    mov AX, 0 ; successful!
    mov [needs_reboot], byte 1
    ret
abort:
    ; Recover from error by clearing ST and setting ST
    mov EAX, [ES:EBX+HBA_PORT.cmd]
    and EAX, ~(1<<0) ; set ST = Start
    mov [ES:EBX+HBA_PORT.cmd], EAX
    or EAX, (1<<0) ; set ST = Start
    mov [ES:EBX+HBA_PORT.cmd], EAX

    call clearall ; clears password in memory


    mov AX, 1 ; wrong password!
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
    ; Set CI bit 0
    mov [ES:EBX+HBA_PORT.ci], dword 1
    
wait_ci:
    mov EAX, [ES:EBX+HBA_PORT.ci]
    test EAX, 1
    jnz wait_ci
    ; command completed
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
msg_notlocked db `not locked\n\0`
msg_locked db `locked\n\0`
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
