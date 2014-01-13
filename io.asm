nl:
    push AX
    mov AL, `\n`
    call putc
    pop AX
    ret


getc: ; changes AH...
    mov AH, 0
    int 0x16 
    ret

pause:
    push AX
    mov AX, pause_msg
    call puts
    call getc
    pop AX
    ret

puts:
    push AX
    push BX
    mov BX, AX
puts_loop:
    mov AL, [BX]
    cmp AL, 0
    jz end_puts
    call putc 
    inc BX
    jmp puts_loop
end_puts:
    pop BX
    pop AX
    ret

putdword:
    push EAX
    shr EAX, 16
    call putword
    pop EAX
    call putword
    ret

putword:
    push AX
    xchg AL, AH
    call putbyte
    pop AX
    call putbyte
    ret

putbyte:
    push AX
    shr AL, 4
    call putnibble
    pop AX
    push AX
    call putnibble
    pop AX
    ret

putnibble:
    and AL, 0fh
    cmp AL, 0ah
    jge putnibble_alpha
putnibble_numeric:
    add AL, '0'
    jmp putnibble_endfork
putnibble_alpha:
    add AL, 'A'-0ah
putnibble_endfork:
    ;mov AL, 'Z'
    call putc
    ret

putc: 
    push AX
    push BX
    push CX
    push DX

    cmp AL, `\n`
    jz putc_nl

    cmp AL, `\r`
    jz putc_nl

    jmp putc_print_char

putc_nl: ; print char
    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    int 10h
    mov DL, 79
    jmp nl_jump

putc_print_char:
    mov AH, 09h
    mov AL, AL ; character
    mov BL, 07h 
    mov BH, 0 ; page number
    mov CX, 1 ; count
    int 10h
    
    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    int 10h
nl_jump:
    inc DL ; column
    cmp DL, 79
    jle putc_set_cursor
    mov DL, 0
    inc DH

    cmp DH, 24
    jle putc_set_cursor

    ; Scroll one line up
    mov AH, 06h
    mov AL, 1
    mov BH, 07h
    mov CH, 0
    mov CL, 0
    mov DH, 24
    mov DL, 79
    int 10h

    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    mov DL, 0

putc_set_cursor:
    mov AH, 02h ; set cursor position
    int 10h

    pop DX
    pop CX
    pop BX
    pop AX
    ret
