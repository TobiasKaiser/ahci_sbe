[ahci_sbe website](http://www.tb-kaiser.de/ahci_sbe/)

AHCI BIOS Security Extension
============================

This software is useful if

* you have a (probably self-encrypting) hard disk / solid state drive that supports the (S)ATA SECURITY command set 
* you want to boot from this drive.
* your motherboard's BIOS does <u>not</u> support asking the user for a hard disk password at startup
* you don't want to buy a new motherboard.
* the hard disk controller of your motherboard supports AHCI.

<b>This is a BIOS extension that runs before the operating system is started and allows you to enter passwords to unlock SATA drives.</b>

**New features in version 0.9:**

* Support for multiple AHCI controllers (e. g. additional PCIe SATA cards)
* Press Shift+Enter for *Unlock multiple*: Enter password once and use it for multiple disks without having to type it again.


Screenshot
----------
![Screenshot](http://www.tb-kaiser.de/ahci_sbe/screenshot.png)

*This screenshot is from an old version of ahci_sbe, but the latest version looks similar.*

Build / Installation
--------------------

The easiest way to use this software is to flash it to a PCI / PCIe network adapter's option ROM.

&rarr; [My blog post about how I recommend installing ahci_sbe.](http://www.tb-kaiser.de/blog/2017/04/28/installing_ahci_sbe/)

More information on flashing PCI option ROMs:

* <http://www.richud.com/wiki/Network_gPXE_and_iPXE_Flashrom_Intel_Pro_100>

Troubleshooting: Erorr message "Port not idle"
----------------------------------------------

If this error appears, you can try to change line 225 in ahci.asm from the conditional jump <code>jz check\_port\_cmd\_ok</code> to the unconditional jump <code>jmp check\_port\_cmd\_ok</code>. This will work in some cases. Thanks to Chain for reporting the problem and fix. Instead of fixing it yourself in the source code, you can also download a fixed version of ahci_sbe 0.9 [here](https://github.com/TobiasKaiser/ahci_sbe/archive/port_not_idle_fix.zip).

More links
----------

This project inspired me to write ahci_sbe. It has more features, but only supports IDE, not AHCI controllers:

* <http://www.fitzenreiter.de/ata/ata_eng.htm>

----

Copyright &copy; 2014 &ndash; 2017 Tobias Kaiser <mail@tb-kaiser.de>