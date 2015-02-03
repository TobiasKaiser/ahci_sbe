AHCI BIOS Security Extension
============================

This software is useful if

* you have a (probably self-encrypting) hard disk / solid state drive that supports the (S)ATA SECURITY command set 
* you want to boot from this drive.
* your motherboard's BIOS does <u>not</u> support asking the user for a hard disk password at startup
* you don't want to buy a new motherboard.
* the hard disk controller of your motherboard supports AHCI.

<b>This is a BIOS extension that runs before the operating system is started and allows you to enter passwords to unlock SATA drives.</b>

<a href="http://www.tb-kaiser.de/ahci_sbe/ahci_sbe_0.4.zip">Download AHCI BIOS Security Extension ahci_sbe 0.4</a>

Screenshot
----------
![Screenshot](http://www.tb-kaiser.de/ahci_sbe/screenshot.png)

Build / Installation
--------------------

The easiest way to use this software is to flash it to a PCI / PCIe network adapter's option ROM.



## Links

More information on flashing PCI option ROMs:

* <http://www.richud.com/wiki/Network_gPXE_and_iPXE_Flashrom_Intel_Pro_100>

This project inspired me to write ahci_sbe. It has more features, but only supports IDE, not AHCI controllers:

* <http://www.fitzenreiter.de/ata/ata_eng.htm>

----

Copyright &copy; 2014 Tobias Kaiser <mail@tb-kaiser.de>

See also: http://www.tb-kaiser.de/ahci_sbe/
