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
    call putnibble
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
    mov AH, 09h
    mov AL, AL ; character
    mov BL, 07h 
    mov BH, 0 ; page number
    mov CX, 1 ; count
    int 10h
    
    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    int 10h
    inc DL ; column
    mov AH, 02h ; set cursor position
    int 10h
    ret
