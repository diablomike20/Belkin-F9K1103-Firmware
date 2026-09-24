# Belkin F9K1103 v1 — LEDE 17.01.5 port

This branch builds a **separate F9K1103 v1 target from LEDE 17.01.5**.
It is not an RT-N56U binary rename.

Board evidence used:
- SoC/platform: Ralink RT3883.
- 8 MiB SPI-NOR layout from the later OpenWrt F9K110x support:
  - U-Boot 0x000000..0x02ffff
  - environment 0x030000..0x03ffff
  - factory 0x040000..0x04ffff
  - firmware 0x050000..0x7effff (0x7a0000 bytes)
  - user-cfg 0x7f0000..0x7fffff
- Realtek RTL8367R-VB family, SMI GPIO 1/2.
- Ethernet: LAN ports 0..3, WAN port 4, CPU link on switch port 5.
- Padavan BN750DB board definition identifies BOARD_PID=F9K1103 and provides:
  - Reset GPIO 25
  - WPS GPIO 26
  - Power GPIO 0
  - LAN GPIO 13
  - WAN GPIO 12
  - USB GPIO 9
  - two USB ports
- Radio calibration:
  - SoC WMAC: factory + 0x0000
  - PCI RT3091/RT3092: factory + 0x8000
- Stock-family uImage name: N750F9K1103VB.
- F9K1103 stock firmware emulation evidence explicitly requires HW_WAN_MAC and HW_LAN_MAC.

Because LEDE 17.01.5 uses the old ramips board framework, the build backports:
- DTS board definition
- rt3883 image recipe
- /lib/ramips.sh board detection
- swconfig network topology
- U-Boot environment MAC extraction
- sysupgrade magic acceptance
- LED defaults

Status: **PORT-WIP / build-verified only / not yet boot-verified on physical F9K1103 v1 hardware.**
