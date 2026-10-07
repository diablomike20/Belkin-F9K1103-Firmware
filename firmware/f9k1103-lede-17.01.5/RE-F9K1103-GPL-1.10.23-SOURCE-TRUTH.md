# RE — Belkin F9K1103 v1.10.23 GPL source truth

Status: TARGET_SOURCE_VERIFIED  
Target: Belkin F9K1103 v1 / N750 DB  
Purpose: preserve exact physical target truth for the CUDY-FIRST WR1200E port.

## Exact source archive

The user-supplied split archive reconstructs to the official Belkin GPL payload:

- archive: `F9K1103_v1.10.23.tar.gz`
- bytes: `417775619`
- SHA-256: `8e65bf160929df49fe6b88544709666d0071e7fed56cca3fff933bc7ce60799d`

This matches the source hash previously recorded in `F9K1103-GPL-CORRELATION.md`.

## Product / boot identity

Exact F9K1103 project configuration proves:

- `PROJ_HW_MODEL_STR=F9K1103 v1`
- `PROJ_BOOT_VER_STR=1.7.4`
- `PROJ_GUI_VER_STR=1.10.23`
- `PROJ_PDTAG=N750F9K1103VB`
- `CONFIG_RALINK_SDK=y`
- `CONFIG_RT3090=y`
- `CONFIG_RT3883_PHASE2_DRIVER=y`
- `CONFIG_ETH_SWITCH_RTL8367R_VB=y`
- dual-band Wi-Fi enabled

The physical recovery screenshot from the real target independently reports boot code
`1.7.4 (Jul 11 2011 - 15:54:00)`, consistent with this source tree.

## Exact Ethernet / switch truth

Project config:

- base stock Ethernet interface: `eth2`
- router LAN interface: `eth2.1`
- WAN interface: `eth2.2`
- LAN VLAN: `1`
- WAN VLAN: `2`
- WAN switch port: `4`

U-Boot project header:

- `WAN_SWITCH_PORT_NO=4`
- `SWITCH_CPU_PORT_NO=5`

Stock VLAN setup (`rc.vlan.conf.sh`) proves:

- LAN physical ports: `0 1 2 3`
- WAN physical port: `4`
- CPU port: `5`
- LAN VID: `1`
- WAN VID: `2`

Stock router VLAN flow:

- initialize RTL8367 VLAN table
- remove physical ports and CPU port from default VLAN
- add ports 0..3 to LAN VID 1
- add CPU port 5 to LAN VID 1
- add WAN port 4 to WAN VID 2
- add CPU port 5 to WAN VID 2

The stock LAN-up script explicitly executes PHY-up for ports `0 1 2 3`.

### Correlation with boot-proven WIP03

The native LEDE 17.01.5 F9K1103 build uses:

```
ucidef_add_switch "switch0" \
    "0:lan" "1:lan" "2:lan" "3:lan" "4:wan" "5@eth0"
```

Therefore the WIP03/OpenWrt switch topology is TARGET_SOURCE_VERIFIED and matches the
exact OEM topology. The difference `eth2` vs `eth0` is kernel/userspace naming across
the old Ralink SDK and LEDE driver stack; WIP03 physical boot already verifies the LEDE
side.

Do not replace the boot-proven LEDE RTL8367B/swconfig stack with the old OEM
`rtl8367cmd` binary. The OEM utility is uClibc/Ralink-SDK-specific and talks to the
old `/dev/rtl8367` driver ABI.

## Exact Wi-Fi truth

Hardware revision / project source proves:

- integrated RT3883 radio = 5 GHz
- PCIe RT3092 radio = 2.4 GHz
- stock names: `ra0` (RT3883 / 5 GHz), `rai0` (RT3092 / 2.4 GHz)

Stock wireless start:

1. load RT3883 AP driver
2. load RT3090/RT3092 PCIe AP driver
3. install region-specific EEPROM/profile data
4. bring wireless interface up
5. attach it to LAN bridge
6. set `RadioOn=1`

This independently corroborates the physical WIP03 mapping used by the Cudy adapter:

- target `radio0` / PCI RT3091/3092 = 2.4 GHz
- target `radio1` / RT3883 WMAC = 5 GHz
- Cudy logical `wlan00` = 2.4 GHz
- Cudy logical `wlan10` = 5 GHz

## U-Boot / recovery truth

Exact U-Boot configuration proves:

- `UBOOT_HTTPD=y`
- `UBOOT_HTTPD_RSA` is not enabled
- `DUAL_IMAGE_SUPPORT` is not enabled
- `RT3883_USE_GE1=y`
- `GE_RGMII_FORCE_1000=y`
- `ETH_SWITCH_RTL8367R_VB=y`
- SPI flash target
- `TEXT_BASE=0x80200000`

Physical target evidence independently verifies recovery at `10.10.10.123`.

The GPL package does not include the complete U-Boot HTTPD implementation, so exact
upload validation logic must not be invented from config flags alone.

## OEM image header extension

Belkin's bundled `mkimage` modifies the normal 64-byte uImage header:

- `IH_NMLEN = 28`
- the final 4 bytes are `ih_ksz` = kernel-part size
- `mkimage -k <kernel-size>` writes this field

Exact images:

| Image | `ih_ksz` | RootFS offset |
|---|---:|---:|
| OEM F9K1103 WW 1.10.17 | 1364964 | 1364964 (`shsq`) |
| GPL-built 1.10.23 `linux.bin` | 1364909 | 1364909 (`shsq`) |
| boot-proven WIP03 RADIOFIX | 0 | 1380799 (`hsqs`) |
| CUDY-FIRST Candidate-13 | 0 | 1380799 (`hsqs`) |

Thus the OEM `ih_ksz` field points exactly at the stock SquashFS boundary.

WIP03 physically boots with `ih_ksz=0`; therefore nonzero OEM `ih_ksz` is not
required for the proven LEDE boot path. Do not change the boot-proven WIP03 envelope
merely for cosmetic OEM-header fidelity.

## OEM image build pipeline

For `CONFIG_ROOTFS_IN_FLASH_NO_PADDING=y`, stock build:

1. compresses kernel to LZMA
2. appends SquashFS directly
3. computes kernel/rootfs boundary
4. wraps the combined kernel+rootfs as one uImage
5. writes the boundary into `ih_ksz`
6. names the image `N750F9K1103VB`

The current LEDE/WIP03 layout differs intentionally:

```
[uImage(kernel only)] [SquashFS] [fwtool metadata]
```

This format remains authoritative for our target because WIP03 is physically boot
verified and the real recovery uploader accepts the derived candidates.

## Decision for CUDY-FIRST port

New GPL evidence does **not** justify a kernel/DTS/switch-topology rewrite.

Keep as target-owned and boot-proven:

- RT3883 kernel / DTS
- RTL8367B switch driver
- target board.d topology
- target kmodloader
- target swconfig
- target mac80211/rt2x00 radio stack
- target firmware/calibration handling

The strongest remaining failure domain after a no-link/no-Wi-Fi Cudy candidate is the
userspace boot/network-control boundary (procd/netifd/ubus/uci and their helper scripts),
not the physical switch port map.

Evidence hierarchy applied:

`TARGET physical > exact target GPL source > boot-proven target source/image > donor source > inference`.
