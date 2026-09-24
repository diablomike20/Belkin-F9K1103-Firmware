# Belkin F9K1103 v1 — OpenWrt 23.05.5 custom build

This branch builds a separate `belkin,f9k1103v1` target from OpenWrt v23.05.5.
It does **not** rename the ASUS RT-N56U image.

Evidence used:
- OpenWrt shared `rt3883_belkin_f9k110x.dtsi` flash/switch/radio layout.
- OpenWrt F9K1109 v1 uses stock-required uImage name `N750F9K1103VB`.
- Padavan `BN750DB` board identifies itself as `F9K1103`, 64 MiB RAM, RTL8367R-VB, reset GPIO 25, WPS GPIO 26, two USB ports.
- Padavan kernel config: RTL8367R-VB, SMI GPIO 1/2, WAN port 4, LAN ports 3/2/1/0, 5 GHz EEPROM at flash 0x40000 and 2.4 GHz PCI EEPROM at 0x48000 (equivalent to factory partition +0x0/+0x8000).

The first image must be treated as **PORT-WIP / NOT hardware-runtime-verified** until it boots on an actual F9K1103 v1.

For UART-less first installation, the closest upstream F9K1109 recovery method uses the bootloader web recovery at 10.10.10.123 and accepts the squashfs sysupgrade image; this remains a device-specific experiment for F9K1103 until physically verified.
