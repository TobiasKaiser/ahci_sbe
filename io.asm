    ; Password dialog
    ; ---------------

window_width equ 46

pw_dialog:
    pusha
    mov [cur_style], byte 0x1F ; white on blue

    mov [horiz_line_left], byte 0xB3 ; vertical line
    mov [horiz_line_middle], byte 0x20 ; space
    mov [horiz_line_right], byte 0xB3 ; vertical line
    mov DH, 8 ; line number
    call horiz_line
    mov DH, 9 ; line number
    call horiz_line
    mov DH, 10 ; line number
    call horiz_line
    mov DH, 11 ; line number
    call horiz_line
    mov DH, 12 ; line number
    call horiz_line
    mov DH, 14 ; line number
    call horiz_line
    mov DH, 15 ; line number
    call horiz_line
    mov DH, 16 ; line number
    call horiz_line

    mov [horiz_line_middle], byte 0xC4 ; horizontal lines following

    mov [horiz_line_left], byte 0xDA ; top left corner
    mov [horiz_line_right], byte 0xBF ; top right corner
    mov DH, 7 ; line number
    call horiz_line


    mov [horiz_line_left], byte 0xC3 ; |-
    mov [horiz_line_right], byte 0xB4 ; -|
    mov DH, 13 ; line number
    call horiz_line

    mov [horiz_line_left], byte 0xC0 ; bottom left corner
    mov [horiz_line_right], byte 0xD9 ; bottom right corner
    mov DH, 17 ; line number
    call horiz_line

    mov DL, (80-window_width)/2+2

    mov DH, 9
    mov AH, 02h ; set cursor position
    int 10h

    mov AX, pw_dialog_msg
    call puts
    
    mov DH, 11
    mov AH, 02h ; set cursor position
    int 10h

    mov AX, identify_strbuf
    call puts

    mov DH, 15
    mov AH, 02h ; set cursor position
    int 10h
    
    mov AX, pw_dialog_prompt
    call puts

    mov DI, 0
    mov ECX, [ahci_data_buf]
    add ECX, 2 ; the password field for SECURITY UNLOCK is now at ES:ECX
pw_dialog_loop:
    call getc 
    
    cmp AL, `\r`
    jz pw_dialog_end_loop

    cmp AL, `\b`
    jz pw_dialog_backspace

    cmp EDI, 32
    jnz pw_addchar_ok
    jmp pw_dialog_loop ; too long

pw_addchar_ok:
    mov [ES:ECX+EDI], AL

    mov AL, '*'
    call putc

    inc EDI

    jmp pw_dialog_loop
pw_dialog_backspace:
    cmp EDI, 0
    jnz pw_delchar_ok
    jmp pw_dialog_loop ; already empty buffer
    
pw_delchar_ok:
    mov [ES:ECX+EDI], byte 0
    call backspace
    dec EDI

    jmp pw_dialog_loop
pw_dialog_end_loop: 

    mov [cur_style], byte 0x07 ; grey on black

    popa
    ret    

wrong_password_error_box:
    pusha
    mov [cur_style], byte 0x4F ; white on red

    mov [horiz_line_left], byte 0xB3 ; vertical line
    mov [horiz_line_middle], byte 0x20 ; space
    mov [horiz_line_right], byte 0xB3 ; vertical line
    mov DH, 11 ; line number
    call horiz_line
    mov DH, 12 ; line number
    call horiz_line
    mov DH, 13 ; line number
    call horiz_line

    mov [horiz_line_middle], byte 0xC4 ; horizontal lines following

    mov [horiz_line_left], byte 0xDA ; top left corner
    mov [horiz_line_right], byte 0xBF ; top right corner
    mov DH, 10 ; line number
    call horiz_line

    mov [horiz_line_left], byte 0xC0 ; bottom left corner
    mov [horiz_line_right], byte 0xD9 ; bottom right corner
    mov DH, 14 ; line number
    call horiz_line

    mov DL, (80-window_width)/2+2

    mov DH, 12
    mov AH, 02h ; set cursor position
    int 10h

    mov AX, wrong_password_msg
    call puts

wait_return:
    call getc
    cmp AL, `\r`
    jnz wait_return

    
    mov [cur_style], byte 0x07 ; grey on black
    popa
    ret

cls:
    pusha
    mov AH, 06h
    mov AL, 0
    mov BH, 07h
    mov CH, 0
    mov CL, 0
    mov DH, 24
    mov DL, 79
    int 10h
    popa
    ret
    

horiz_line: ; DH is line number, chars are [horiz_line_(left|middle|right)]
    mov AH, 09h
    mov BL, [cur_style]
    mov BH, 0 ; page number
    mov CX, 1 ; count

    mov DL, (80-window_width)/2

    mov AH, 02h ; set cursor position
    int 10h

    mov AH, 09h ; print char
    mov AL, [horiz_line_left]
    int 10h

pw_top_line_loop:
    inc DL
    cmp DL, 80 - (80-window_width)/2 - 1
    mov AH, 02h ; set cursor position
    int 10h
    jz pw_end_top_line

    mov AH, 09h ; print char
    mov AL, [horiz_line_middle]
    int 10h
    jmp pw_top_line_loop
pw_end_top_line:
    mov AH, 09h ; print char
    mov AL, [horiz_line_right]
    int 10h
    ret

    ; Basic user interaction procedures
    ; ---------------------------------
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

backspace:
    pusha

    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    int 10h
    sub DL, 1
    mov AH, 02h ; set cursor position
    int 10h

    mov AH, 09h
    mov AL, ' '
    mov BL, [cur_style]
    mov BH, 0 ; page number
    mov CX, 1 ; count
    int 10h

    popa
    ret
    

putc: 
    pusha

    cmp AL, `\n`
    jz putc_nl

    cmp AL, `\r`
    jz putc_nl


    jmp putc_print_char

putc_nl:
    mov AH, 03h ; get cursor position
    mov BH, 0 ; page number
    int 10h
    mov DL, 79
    jmp nl_jump

putc_print_char:
    mov AH, 09h
    mov AL, AL ; character
    mov BL, [cur_style]
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

    popa
    ret
