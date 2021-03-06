; io.asm -- User interface functions via BIOS
; Copyright (C) 2014, 2016 Tobias Kaiser <mail@tb-kaiser.de>

    ; Password dialog
    ; ---------------

window_width equ 56

; pw_dialog provides the interface for the user to enter a password by
; keyboard.
; Returns 0 on success, 1 on Escape

pw_dialog:
    pusha

    call restore_last_password

    mov [cur_style], byte 0x1F ; white on blue

    mov [horiz_line_left], byte 0xB3 ; vertical line
    mov [horiz_line_middle], byte 0x20 ; space
    mov [horiz_line_right], byte 0xB3 ; vertical line
    mov DH, 7 ; line number
    call horiz_line
    mov DH, 8 ; line number
    call horiz_line
    mov DH, 9 ; line number
    call horiz_line
    mov DH, 10 ; line number
    call horiz_line
    mov DH, 11 ; line number
    call horiz_line
    mov DH, 13 ; line number
    call horiz_line
    mov DH, 14 ; line number
    call horiz_line
    mov DH, 15 ; line number
    call horiz_line
    mov DH, 16 ; line number
    call horiz_line
    mov DH, 17 ; line number
    call horiz_line

    mov [horiz_line_middle], byte 0xC4 ; horizontal lines following

    mov [horiz_line_left], byte 0xDA ; top left corner
    mov [horiz_line_right], byte 0xBF ; top right corner
    mov DH, 6 ; line number
    call horiz_line


    mov [horiz_line_left], byte 0xC3 ; |-
    mov [horiz_line_right], byte 0xB4 ; -|
    mov DH, 12 ; line number
    call horiz_line

    mov [horiz_line_left], byte 0xC0 ; bottom left corner
    mov [horiz_line_right], byte 0xD9 ; bottom right corner
    mov DH, 18 ; line number
    call horiz_line

    mov DL, (80-window_width)/2+2

    mov DH, 8
    mov AH, 02h ; set cursor position
    int 10h
    mov AX, pw_dialog_msg
    call puts
    
    mov [cur_style], byte 0x70 ; black on gray
    mov DH, 16
    mov AH, 02h ; set cursor position
    int 10h
    mov AX, pw_dialog_usage_msg
    call puts
    mov [cur_style], byte 0x1F

    ; Neatly fill the space between the usage hints
    mov DH, 16
    mov DL, (80-window_width)/2+2+12
    mov AH, 02h ; set cursor position
    int 10h
    mov AL, ` `
    call putc
    call putc
    mov DL, (80-window_width)/2+2+12+29
    mov AH, 02h ; set cursor position
    int 10h
    mov AL, ` `
    call putc
    call putc
    mov DL, (80-window_width)/2+2

    mov DH, 10
    mov AH, 02h ; set cursor position
    int 10h
    mov AX, identify_strbuf
    call puts

    mov DH, 14
    mov AH, 02h ; set cursor position
    int 10h
    mov AX, pw_dialog_prompt
    call puts

    mov EDI, 0

    ; restore last password to dialog
    mov ECX, [last_password_length]
restore_asterisks:
    cmp ECX, 0
    jz restore_asterisks_end

    mov AL, '*'
    call putc

    inc EDI
    dec ECX
    jmp restore_asterisks
restore_asterisks_end:

   
    mov ECX, [ahci_data_buf]
    add ECX, 2 ; the password field for SECURITY UNLOCK is now at ES:ECX

pw_dialog_loop:
    call getc 
    
    cmp AL, `\r`
    jz pw_dialog_end_loop

    cmp AL, 0x1b ; escape key cancels password dialog and continues boot with locked hdd
    jz pw_dialog_escape

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

pw_dialog_escape:
    mov [cur_style], byte 0x07 ; grey on black
    popa
    mov AX, 1 ; dialog cancelled
    ret

    
pw_delchar_ok:
    mov [ES:ECX+EDI], byte 0
    call backspace
    dec EDI

    jmp pw_dialog_loop
pw_dialog_end_loop:
    call clear_last_password


    ; check if shift is pressed. If so, set [unlock_multiple], else clear it.
    mov AH, 0x02
    int 16h
    and AL, 3 ; first two bits are shift left and right
    cmp AL, 0
    jz pw_dialog_no_multiple

    mov [unlock_multiple], byte 1

    mov [last_password_length], EDI

    call store_last_password

pw_dialog_no_multiple:

    mov [cur_style], byte 0x07 ; grey on black
    popa
    mov AX, 0 ; success
    ret

    ; Error box: Wrong password
    ; -------------------------

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

cls_blank:
    ; Clear screen
    mov AH, 06h
    mov AL, 0
    mov BH, 07h
    mov CH, 0
    mov CL, 0
    mov DH, 24
    mov DL, 79
    int 10h

    ; Move cursor to 0, 0
    mov DL, 0
    mov DH, 0
    mov BH, 0 ; page number
    mov AH, 02h ; set cursor position
    int 10h

    ret

cls:
    pusha
    call cls_blank

    ; Print version info at bottom
    mov DL, 0
    mov DH, 24
    mov BH, 0 ; page number
    mov AH, 02h ; set cursor position
    int 10h

    mov AX, version_str
    call puts

    ; Move cursor to 0, 0
    mov DL, 0
    mov DH, 0
    mov BH, 0 ; page number
    mov AH, 02h ; set cursor position
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
