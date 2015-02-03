
SRC=main.asm io.asm

all: ahci_sbe.qemu.rom ahci_sbe.vbox.rom ahci_sbe.realtek.rom

ahci_sbe.qemu.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x8086 -dPCI_DEVICE_ID=0x100E
	./addchecksum $@ || rm $@

ahci_sbe.vbox.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x8086 -dPCI_DEVICE_ID=0x100E
	./addchecksum $@ || rm $@

ahci_sbe.realtek.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x8086 -dPCI_DEVICE_ID=0x100E
	./addchecksum $@ || rm $@

addchecksum: addchecksum.c
	gcc -o $@ $< -Wall

.PHONY: clean
clean:
	rm -rf addchecksum ahci_sbe.qemu.rom ahci_sbe.vbox.rom ahci_sbe.realtek.rom
