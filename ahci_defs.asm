struc HBA
    .cap: resd 1
    .ghc: resd 1
    .is: resd 1
    .pi: resd 1
    .vs: resd 1
    .ccc_ctl: resd 1
    .ccc_pts resd 1
    .em_loc: resd 1
    .em_ctl: resd 1
    .cap2: resd 1
    .bohc: resd 1
    resb 0xA0 - 0x2C ; reserved
    resb 0x100 - 0xA0 ; vendor specific
    .ports: 
endstruc

struc HBA_PORT
    .clb: resd 1
    .clbu: resd 1
    .fb: resd 1
    .fbu: resd 1
    .is: resd 1
    .ie: resd 1
    .cmd: resd 1
    resd 1 ; reserved
    .tfd: resd 1
    .sig: resd 1
    .ssts: resd 1
    .sctl: resd 1
    .serr: resd 1
    .sact: resd 1
    .ci: resd 1
    .sntf: resd 1
    .fbs: resd 1
    resd 11 ; reserved
    resd 4 ; vendor
endstruc

struc HBA_CMD_HEADER
    .flags: resw 1
    .prdtl: resw 1
    .prdbc: resd 1
    .ctba: resd 1
    .ctbau: resd 1
endstruc
