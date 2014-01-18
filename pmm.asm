    ; Detect POST memory manager
    ; --------------------------

    mov AX, 0xE000
    mov ES, AX
pmm_detection_loop:
    mov EBX, [ES:0]
    cmp EBX, 0x4d4d5024
    jz pmm_detected
    inc AX
    mov ES, AX
    jnz pmm_detection_loop

    mov AX, err_no_pmm
    call puts
    call pause
    retf

pmm_detected:

    ; calculate checksum
    mov BX, 0 ; offset
    mov CL, 0 ; checksum comes here
    mov AL, [ES:05h] ; length

pmm_sum:
    add CL, [ES:BX]
    inc BL
    cmp BL, AL
    jl pmm_sum

    cmp CL, 0
    jz pmm_sum_success

    mov AX, err_pmm_chksum
    call puts
    call pause
    retf

pmm_sum_success:

    ; save entry point - our PMM interfe far function pointer
    mov AX, [ES:07h]    
    mov [pmm_entry_point], AX
    mov AX, [ES:07h+2]    
    mov [pmm_entry_point+2], AX

    mov AX, 0
    mov ES, AX ; now we can use ES for 32 bit physical adressing

    ; Allocate memory
    ; ---------------
    mov EAX, 1024/16
    call pmm_alloc_paragraphs
    mov [cmd_list], EAX

    mov EAX, 256/16
    call pmm_alloc_paragraphs
    mov [cmd_table], EAX

    mov EAX, 4096/16
    call pmm_alloc_paragraphs
    mov [fis_recv], EAX

    mov EAX, 512/16
    call pmm_alloc_paragraphs
    mov [ahci_data_buf], EAX

