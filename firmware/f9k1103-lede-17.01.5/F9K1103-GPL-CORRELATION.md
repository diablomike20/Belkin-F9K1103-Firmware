# Belkin F9K1103 v1 — official GPL correlation for native LEDE 17.01.5 port

## Evidence sources

Primary source:
- Belkin official F9K1103 v1.10.23 GPL archive
- exact archive: F9K1103_v1.10.23.tar.gz
- SHA-256: 8e65bf160929df49fe6b88544709666d0071e7fed56cca3fff933bc7ce60799d
- official source URL: https://s3.belkin.com/support/assets/belkin/gpl/F9K1103_v1.10.23.tar.gz

Hardware-reference source:
- OpenWrt 19.07.0 Belkin F9K1109 v1 image/source family
- this is also the OpenWrt board family currently known to run on the user's physical F9K1103 v1

Target candidate:
- native F9K1103 LEDE 17.01.5 branch
- known successful baseline commit: ee79c687cffee78d274a3da63a3bec53a34ed19b
- GPL-corrected branch: lede-17.01.5-gpl-corrected

## Official F9K1103 hardware truth

The official project hardware_revision.list identifies N750_V1_VB as:
- RT3883 5 GHz
- RT3092 2.4 GHz
- RTL8367R-VB switch

The official product tag is:
- N750F9K1103VB

Official U-Boot configuration proves:
- RT3883 platform
- SPI flash
- 512 Mbit / 64 MiB DRAM class
- RTL8367R-VB
- GE1 RGMII forced 1000 Mbit
- U-Boot HTTPD enabled
- U-Boot HTTPD RSA option not enabled

Official board header proves:
- WAN switch port = 4
- CPU switch port = 5
- RESET GPIO = 25
- BIG_GREEN LED GPIO = 12
- BIG_AMBER LED GPIO = 13
- SMALL_GREEN LED GPIO = 10
- SMALL_AMBER LED GPIO = 0
- USB1 LED GPIO = 9
- USB2 LED GPIO = 14
- LEDs and reset button are active-low

Official GPL wps_monitor MIPS disassembly proves:
- wps_gpio_btn_init() loads immediate value 26
- that value is stored into wps_btn_gpio
- therefore WPS button GPIO = 26

## LEDE port correlations

### MATCH / source-supported
- SoC family: RT3883
- RTL8367B driver family for RTL8367R-VB
- RGMII 1000 Mbit fixed link
- switch mapping: LAN 0..3, WAN 4, CPU 5
- image name: N750F9K1103VB
- reset GPIO25
- WPS GPIO26
- SPI NOR
- U-Boot environment MAC variable names HW_WAN_MAC / HW_LAN_MAC
- two USB host controllers enabled
- Wi-Fi family/dual-band role
- OpenWrt family calibration convention factory+0 / factory+0x8000

### GPL correction applied
The former DTS represented only four LEDs and assigned generic power/LAN/WAN names.
The GPL-corrected DTS now defines all six exact source-proven LED GPIOs:
- f9k1103:green:big -> GPIO12
- f9k1103:amber:big -> GPIO13
- f9k1103:green:small -> GPIO10
- f9k1103:amber:small -> GPIO0
- f9k1103:usb1 -> GPIO9
- f9k1103:usb2 -> GPIO14

No boot-critical switch/radio/kernel image behavior was changed by this correction.

## Flash-layout nuance

There are two evidence layers and they must not be conflated.

Official old Belkin router Makefiles contain:
- U-Boot = 0x30000
- config = 0x10000
- RF/factory = 0x10000
- system = 0x7B0000
- total = 0x800000

This mathematically represents the complete remainder after offset 0x50000 as the legacy stock system area.

The later OpenWrt F9K110x layout used by the known-working F9K1109 reference is:
- U-Boot: 0x000000 + 0x030000
- uboot-env: 0x030000 + 0x010000
- factory: 0x040000 + 0x010000
- firmware: 0x050000 + 0x7A0000
- user-cfg: 0x7F0000 + 0x010000

The native LEDE port currently deliberately follows this later OpenWrt/F9K110x compatibility layout.

Classification:
- physical flash size 8 MiB: SOURCE_VERIFIED
- 0x30000 + 0x10000 + 0x10000 legacy prefix: SOURCE_VERIFIED
- legacy stock system size 0x7B0000: SOURCE_VERIFIED
- OpenWrt firmware 0x7A0000 + user-cfg 0x10000: CROSS_GENERATION_F9K110x + KNOWN_RUNNING_REFERENCE
- exact need for separate user-cfg on physical F9K1103: TARGET_UNKNOWN

Decision:
Do not change this partition split solely to make the DTS look more like the old stock Makefile.
The user's currently working F9K1109/OpenWrt 19 reference already demonstrates that the conservative 0x7A0000 firmware layout can operate on the physical F9K1103.
A physical read-only MTD/recovery check should precede any attempt to consume the last 64 KiB.

## Recovery

Official F9K1103 U-Boot board config proves:
- UBOOT_HTTPD=y
- UBOOT_HTTPD_RSA is not set
- RESET button GPIO25 is active-low
- SPI upgrade checking is built into the U-Boot family

This proves presence of a bootloader HTTP recovery capability.
It does NOT by itself prove a specific user-facing recovery-entry timing sequence or IP address.
Those remain separately source/target verified before relying on recovery.

## Current decision

The GPL-corrected native LEDE branch is the preferred F9K1103 base.

Required gates:
1. clean BUILD_VERIFIED
2. independent built-byte DTB/rootfs audit
3. recovery/preflight verification on the currently running router
4. only then explicit-user-approved physical boot test

Until gate 4:
PHYSICAL_BOOT=UNKNOWN
