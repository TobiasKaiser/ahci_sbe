/* addchecksum.c -- Calculate byte-wise checksum and overwrite last byte for PCI 
 * option ROM files
 *
 * This file is part of ahci_sbe.
 *
 * Copyright (C) 2014, Tobias Kaiser <mail@tb-kaiser.de>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 
 * 2. Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */ 

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    if(argc!=2) {
        fprintf(stderr, "Usage: %s FILE\n\n", argv[0]);
        exit(1);
    }
    FILE *f=fopen(argv[1], "r+");
    if(!f) {
        perror("fopen failed");
        exit(1);
    }
    fseek(f, 0, SEEK_END);
    int f_size=ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char sum=0;
    int i;
    for(i=0;i<f_size-1;i++) {
        sum+=fgetc(f);
    }
    fputc((0x100-sum)&0xff, f);
    fclose(f);
    return 0; 
}
