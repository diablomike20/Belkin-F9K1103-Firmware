# F9K1103 LEDE 17.01.5 Cudy Firmware

Target: Belkin F9K1103 v1 / N750 DB.

Goal: keep the native F9K1103 LEDE 17.01.5 hardware/kernel/driver base and port the compatible Cudy router userspace/UI on top.

Primary Cudy router donor (FU8 evidence):
- WR1200V2 R26 2.4.23
- fallback/corroboration: WR1200V2 R26 2.4.12
- LT500D R25 2.4.16 is framework/UI corroboration only for router-common pieces.

Explicitly excluded from the Belkin port:
- 3G/4G/5G
- SIM/SMS
- gcom / modem control
- LT500D cellular WAN
- device-specific Cudy kernel modules and Wi-Fi drivers
- opaque mipsel_24kc ELF binaries unless separately proven ABI-safe on rt3883/mipsel_74kc

Port architecture:
1. F9K1103 native LEDE 17.01.5 kernel, DTS, switch, Wi-Fi, USB, flash layout.
2. Cudy router UI/Lua/shell semantics from WR1200V2.
3. F9K1103 adapter layer for network/wireless/system operations.
4. Rebuild into a normal F9K1103 sysupgrade image.
