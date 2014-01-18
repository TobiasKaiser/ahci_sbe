SRC=main.asm io.asm ahci.asm ahci_defs.asm

#do: flash

all: ahci_sbe.qemu.rom ahci_sbe.vbox.rom ahci_sbe.realtek.rom

flash: ahci_sbe.realtek.rom
	usbcprog -t -p 2864 -w $<

ahci_sbe.qemu.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x8086 -dPCI_DEVICE_ID=0x100E
	./addchecksum $@ || rm $@

ahci_sbe.vbox.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x1022 -dPCI_DEVICE_ID=0x2000
	./addchecksum $@ || rm $@

ahci_sbe.realtek.rom: $(SRC) addchecksum
	nasm main.asm -fbin -o $@ -dPCI_VENDOR_ID=0x10EC -dPCI_DEVICE_ID=0x8139
	./addchecksum $@ || rm $@

addchecksum: addchecksum.c
	gcc -o $@ $< -Wall

.PHONY: clean
clean:
	rm -rf addchecksum ahci_sbe.qemu.rom ahci_sbe.vbox.rom ahci_sbe.realtek.rom
